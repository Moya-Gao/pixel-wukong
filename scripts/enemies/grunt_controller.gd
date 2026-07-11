## 小怪控制器
## 行为：巡逻 -> 发现玩家 -> 追击 -> 攻击（含突进攻击）
## 突进攻击：30% 概率蓄力后高速冲撞，造成额外伤害

class_name GruntController extends "res://scripts/enemies/enemy_base.gd"

# ========== AI 状态标志 ==========
var is_patrolling: bool = true
var is_chasing: bool = false
var is_waiting: bool = false
var is_rushing: bool = false  # 突进攻击状态

# ========== 巡逻参数 ==========
var patrol_start_pos: Vector2
var patrol_target_pos: Vector2
var patrol_wait_timer: float = 0.0

# ========== 突进参数 ==========
const RUSH_CHARGE_TIME: float = 0.3   # 蓄力时间
const RUSH_SPEED: float = 500.0       # 突进速度
const RUSH_DAMAGE_BONUS: int = 5      # 额外伤害
var rush_charge_timer: float = 0.0
var rush_direction: Vector2 = Vector2.ZERO
var rush_has_dealt_damage: bool = false


func _ready() -> void:
	super._ready()
	patrol_start_pos = global_position
	_choose_patrol_target()


func _process_behavior(delta: float) -> void:
	# 更新攻击冷却
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta

	# 处理攻击中状态
	if is_attacking:
		_process_attack(delta)
		return

	# 处理突进攻击
	if is_rushing:
		_process_rush(delta)
		return

	# 丢失目标 → 回到巡逻（不再永远站桩）
	if is_chasing and not target:
		is_chasing = false
		is_patrolling = true
		patrol_start_pos = global_position
		_choose_patrol_target()

	# 决策树
	if target and _is_target_in_attack_range():
		_start_attack()
	elif target and _can_see_target():
		_process_chase(delta)
	elif is_patrolling:
		_process_patrol(delta)
	else:
		_process_idle(delta)


# ========== 巡逻行为 ==========
func _process_patrol(delta: float) -> void:
	if is_waiting:
		_process_patrol_wait(delta)
		return

	var direction = sign(patrol_target_pos.x - global_position.x)
	if direction != 0:
		facing_right = direction > 0

	velocity.x = direction * stats.move_speed
	velocity.y = 0

	# 到达巡逻点
	if abs(global_position.x - patrol_target_pos.x) < 5:
		is_waiting = true
		patrol_wait_timer = stats.patrol_wait_time


func _process_patrol_wait(delta: float) -> void:
	velocity = Vector2.ZERO
	patrol_wait_timer -= delta

	if patrol_wait_timer <= 0:
		is_waiting = false
		_choose_patrol_target()


func _choose_patrol_target() -> void:
	var offset = randf_range(-stats.patrol_range, stats.patrol_range)
	patrol_target_pos = patrol_start_pos + Vector2(offset, 0)


# ========== 追击行为 ==========
func _can_see_target() -> bool:
	if not target:
		return false

	var distance = global_position.distance_to(target.global_position)
	return distance <= stats.detection_range


func _is_target_in_attack_range() -> bool:
	if not target:
		return false

	# 计算敌人面向目标时的 Hitbox 位置
	var hitbox_offset = 8.0  # Hitbox 相对于敌人的偏移
	var direction = sign(target.global_position.x - global_position.x)
	var hitbox_pos = global_position + Vector2(hitbox_offset * direction, -12)

	# 计算 Hitbox 到目标 Hurtbox 的距离
	var distance = hitbox_pos.distance_to(target.global_position)
	return distance <= stats.attack_range


func _process_chase(_delta: float) -> void:
	if not target:
		return

	is_chasing = true
	is_patrolling = false

	var direction_x = sign(target.global_position.x - global_position.x)
	var direction_y = sign(target.global_position.y - global_position.y)

	if direction_x != 0:
		facing_right = direction_x > 0

	velocity.x = direction_x * stats.chase_speed
	velocity.y = direction_y * stats.chase_speed


func _process_idle(_delta: float) -> void:
	velocity = Vector2.ZERO


# ========== 攻击行为 ==========
func _start_attack() -> void:
	# 30% 概率触发突进攻击（冷却可用 + 非巡逻态）
	if attack_cooldown_timer <= 0 and not is_patrolling and randf() < 0.3:
		_start_rush_attack()
		return

	# 攻击前摇：红色闪烁给玩家反应窗口
	_show_attack_telegraph()
	is_attacking = true
	attack_timer = stats.attack_duration
	velocity = Vector2.ZERO
	_activate_hitbox()


func _process_attack(_delta: float) -> void:
	attack_timer -= _delta

	# 持续检测攻击碰撞
	_check_hitbox_overlaps()

	if attack_timer <= 0:
		_end_attack()


func _end_attack() -> void:
	is_attacking = false
	attack_cooldown_timer = stats.attack_cooldown
	_deactivate_hitbox()


# ========== 突进攻击 ==========
## 蓄力→高速冲撞→冷却。攻击范围比普通攻击大 1.5 倍
func _start_rush_attack() -> void:
	# 突进前摇更长（蓄力阶段本身就是 telegraph）
	_show_attack_telegraph()
	is_rushing = true
	rush_charge_timer = RUSH_CHARGE_TIME
	rush_has_dealt_damage = false
	velocity = Vector2.ZERO

	# 蓄力方向朝向玩家
	if target:
		rush_direction = (target.global_position - global_position).normalized()
		facing_right = rush_direction.x > 0
	else:
		rush_direction = Vector2(1 if facing_right else -1, 0)


func _process_rush(delta: float) -> void:
	if rush_charge_timer > 0:
		# 蓄力阶段：原地不动，有视觉提示（动画用 attack 帧）
		rush_charge_timer -= delta
		velocity = Vector2.ZERO
		return

	# 冲刺阶段：高速移动
	velocity = rush_direction * RUSH_SPEED

	# 碰撞检测：用 enlarged hitbox 判定
	if not rush_has_dealt_damage and _check_rush_hit():
		rush_has_dealt_damage = true

	# 冲刺结束条件：撞到玩家 or 飞行超 0.3s
	if rush_has_dealt_damage:
		_end_rush()


## 检测突进是否命中玩家（扩大判定范围）
func _check_rush_hit() -> bool:
	if not target or not target.has_method("take_damage"):
		return false
	var dist := global_position.distance_to(target.global_position)
	# 突进判定范围 = 敌人 size + 玩家 size + 余量
	var rush_range := 40.0
	if dist <= rush_range:
		var knockback := rush_direction
		var total_damage := stats.attack_damage + RUSH_DAMAGE_BONUS
		target.take_damage(total_damage, knockback)
		return true
	return false


func _end_rush() -> void:
	is_rushing = false
	attack_cooldown_timer = stats.attack_cooldown * 1.5  # 突进后冷却更长
	_deactivate_hitbox()


# ========== 重写受伤处理 ==========
func _process_hurt(delta: float) -> void:
	super._process_hurt(delta)

	# 受伤时取消当前行为
	is_chasing = false
	is_attacking = false
	is_rushing = false
	_deactivate_hitbox()


# ========== 动画更新 ==========
func _update_animation() -> void:
	if not animated_sprite:
		return

	var new_anim = ""

	if is_dead:
		new_anim = "death"
	elif is_hurt:
		new_anim = "hurt"
	elif is_attacking or is_rushing:
		new_anim = "attack"
	elif is_chasing or velocity.length() > 10:
		new_anim = "run"
	else:
		new_anim = "idle"

	if new_anim != animated_sprite.animation:
		animated_sprite.play(new_anim)
