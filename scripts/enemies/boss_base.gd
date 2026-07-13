## Boss 基类
## 继承 EnemyBase，整合行为树 + 阶段切换 + Boss HP 条信号
## 子类重写 _build_behavior_tree() 定义具体 Boss 行为
class_name BossBase
extends EnemyBase

# ========== 信号 ==========
signal boss_phase_changed(new_phase: int, phase_name: String)
signal boss_health_changed(current: int, max_health: int)

# ========== BT ==========
var bt_root: BTNode
var _bt_context: Dictionary = {}

# ========== 阶段状态 ==========
var current_phase: int = 0  # 0=P1, 1=P2, 2=P3
var _phase_transitioning: bool = false
var _phase_transition_timer: float = 0.0
var _phase_transition_duration: float = 1.5

# ========== 仪式性无敌状态 ==========
## Boss 登场演出中：BT 不 tick + 无敌
## 由 BossIntroController 控制，跟 _phase_transitioning 同类早退模式
var is_intro_active: bool = false

# ========== 类型化 stats ==========
var boss_stats: BossStats:
	get: return stats as BossStats

# ========== 攻击冷却管理 ==========
## 命名的冷却计时器（BT condition 检查）
var _cooldowns: Dictionary = {}


func _ready() -> void:
	super._ready()
	# 确保 stats 是 BossStats 类型
	if not stats is BossStats:
		push_error("BossBase requires BossStats resource!")
		# 尝试转换
		var bs := BossStats.new()
		bs.max_health = stats.max_health
		bs.current_health = stats.current_health
		bs.move_speed = stats.move_speed
		bs.chase_speed = stats.chase_speed
		bs.attack_damage = stats.attack_damage
		bs.attack_range = stats.attack_range
		bs.attack_duration = stats.attack_duration
		bs.attack_cooldown = stats.attack_cooldown
		bs.hurt_duration = stats.hurt_duration
		bs.knockback_force = stats.knockback_force
		bs.detection_range = stats.detection_range
		bs.patrol_range = stats.patrol_range
		stats = bs

	_phase_transition_duration = boss_stats.phase_transition_invincible
	bt_root = _build_behavior_tree()
	boss_health_changed.emit(stats.current_health, stats.max_health)


# ========== 主循环 ==========
func _process_behavior(delta: float) -> void:
	if not bt_root:
		return

	# 登场演出中：BT 不 tick（视觉照常播，因为 _physics_process 还在跑）
	if is_intro_active:
		return

	# 阶段切换中：无敌 + 视觉效果
	if _phase_transitioning:
		_process_phase_transition(delta)
		return

	# 攻击中：只更新攻击状态，不让 BT 打断
	if is_attacking:
		_process_attack_state(delta)
		return

	# 检查血量触发阶段切换
	_check_phase_switch()

	# 更新冷却
	_update_cooldowns(delta)

	# 构建上下文并 tick 行为树
	_bt_context = _build_bt_context()
	bt_root.tick(delta, _bt_context)


# ========== BT Context ==========
func _build_bt_context() -> Dictionary:
	return {
		"boss": self,
		"target": target,
		"delta": 0.0,  # 由 tick 注入
		"health_ratio": float(stats.current_health) / float(stats.max_health),
		"current_phase": current_phase,
		"is_attacking": is_attacking,
		"is_hurt": is_hurt,
		"is_stunned": is_stunned,
	}


# ========== 行为树（子类重写）==========
func _build_behavior_tree() -> BTNode:
	return BTNode.new()


# ========== 阶段切换 ==========
func _check_phase_switch() -> void:
	var health_ratio := float(stats.current_health) / float(stats.max_health)
	# 阈值按降序排列 [0.66, 0.33]：遍历找第一个满足的，即最高阶段
	var new_phase := 0
	for i in range(boss_stats.phase_thresholds.size()):
		if health_ratio <= boss_stats.phase_thresholds[i]:
			new_phase = i + 1

	if new_phase > current_phase:
		_start_phase_transition(new_phase)


func _start_phase_transition(new_phase: int) -> void:
	current_phase = new_phase
	_phase_transitioning = true
	_phase_transition_timer = _phase_transition_duration

	# 取消当前攻击
	_deactivate_hitbox()
	is_attacking = false
	velocity = Vector2.ZERO

	# 阶段名称（安全访问）
	var phase_name := ""
	if new_phase < boss_stats.phase_names.size():
		phase_name = boss_stats.phase_names[new_phase]
	else:
		phase_name = "Phase " + str(new_phase + 1)

	boss_phase_changed.emit(new_phase, phase_name)


func _process_phase_transition(delta: float) -> void:
	_phase_transition_timer -= delta
	# 闪烁效果
	modulate = Color.WHITE if fmod(_phase_transition_timer, 0.15) < 0.075 else Color.RED
	velocity = Vector2.ZERO

	if _phase_transition_timer <= 0:
		_phase_transitioning = false
		modulate = _original_modulate
		bt_root.reset()


# ========== 冷却管理 ==========
func _update_cooldowns(delta: float) -> void:
	var expired: Array[String] = []
	for key in _cooldowns:
		_cooldowns[key] -= delta
		if _cooldowns[key] <= 0:
			expired.append(key)
	for key in expired:
		_cooldowns.erase(key)


## 检查指定冷却是否可用
func is_cooldown_ready(ability_name: String) -> bool:
	return not _cooldowns.has(ability_name)


## 开始冷却
func start_cooldown(ability_name: String) -> void:
	var base_cd := boss_stats.get_phase_cooldown(current_phase)
	_cooldowns[ability_name] = base_cd


## 开始自定义冷却
func start_custom_cooldown(ability_name: String, duration: float) -> void:
	_cooldowns[ability_name] = duration


# ========== 重写伤害处理 ==========
func take_damage(damage: int, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	# 登场演出中无敌（跟 _phase_transitioning 同类早退，避免 process_mode 大锤）
	if is_intro_active:
		return

	# 阶段切换中无敌
	if _phase_transitioning:
		return

	var was_health := stats.current_health
	super.take_damage(damage, knockback_dir)

	# 减伤：Boss 有霸体，减少硬直
	if is_hurt and boss_stats.poise_resistance < 1.0:
		hurt_timer *= boss_stats.poise_resistance

	boss_health_changed.emit(stats.current_health, stats.max_health)


# ========== 重写受伤处理（支持霸体）==========
func _start_hurt(knockback_dir: Vector2) -> void:
	# 霸体：击退减弱
	var kb := knockback_dir * stats.knockback_force * (1.0 - boss_stats.poise_resistance)
	super._start_hurt(kb)


# ========== 重写眩晕处理 ==========
func apply_stun(duration: float) -> void:
	# Boss 对眩晕有抗性
	var reduced := duration * (1.0 - boss_stats.poise_resistance)
	if reduced > 0.1:  # 至少保留一点效果
		super.apply_stun(reduced)


# ========== Boss 攻击辅助 ==========
## 执行一个攻击动作（telegraph → 激活 hitbox → 持续 duration → 关闭）
func _execute_attack(attack_name: String, duration_override: float = 0.0) -> void:
	if is_attacking:
		return

	_show_attack_telegraph()
	is_attacking = true
	var dur := duration_override if duration_override > 0 else stats.attack_duration
	attack_timer = dur
	velocity = Vector2.ZERO
	_activate_hitbox()
	start_cooldown(attack_name)


## 处理攻击中状态（在 _process_behavior 中调用，当 is_attacking=true 时）
func _process_attack_state(delta: float) -> void:
	attack_timer -= delta
	_check_hitbox_overlaps()
	if attack_timer <= 0:
		_end_attack()


func _end_attack() -> void:
	is_attacking = false
	_deactivate_hitbox()
