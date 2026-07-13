## 敌人基类
## 提供所有敌人共享的功能：受伤、死亡、与玩家交互

class_name EnemyBase
extends CharacterBody2D

# ========== 信号 ==========
signal died(enemy: Node)
signal health_changed(current: int, max: int)
signal hurt(damage: int, knockback_dir: Vector2)

# ========== 状态标志 ==========
var is_hurt: bool = false
var is_attacking: bool = false
var is_dead: bool = false
var is_stunned: bool = false
var facing_right: bool = true
var _has_dealt_damage: bool = false  # 防止重复造成伤害

# ========== 计时器 ==========
var hurt_timer: float = 0.0
var attack_timer: float = 0.0
var stun_timer: float = 0.0
var attack_cooldown_timer: float = 0.0

# ========== 属性引用 ==========
@export var stats: EnemyStats

# ========== 节点引用 ==========
@onready var sprite_root: Node2D = $SpriteRoot
@onready var animated_sprite: AnimatedSprite2D = $SpriteRoot/AnimatedSprite2D
@onready var hitbox: Area2D = get_node_or_null("Hitbox")
@onready var hurtbox: Area2D = $Hurtbox
@onready var detection_area: Area2D = $DetectionArea

# ========== 当前目标 ==========
var target: Node2D = null


func _ready() -> void:
	# 确保 stats 存在且是独立副本（避免多个敌人共享同一个资源）
	if stats:
		stats = stats.duplicate(true)  # 深拷贝，每个敌人有独立的属性
	else:
		stats = EnemyStats.new()

	# 为 Hitbox 添加组名（用于玩家识别）
	if hitbox:
		hitbox.add_to_group("enemy_hitbox")

	# 为 Hurtbox 添加组名（用于攻击检测）
	if hurtbox:
		hurtbox.add_to_group("enemy_hurtbox")
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)

	# 连接检测区域信号
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)

	# 缓存原始 modulate 用于 telegraph 恢复
	_original_modulate = modulate


# 攻击前摇闪烁：attack 前 0.12s 变红，给玩家反应窗口
var _telegraph_active: bool = false

## 公共 getter：测试可读 telegraph 状态，不绕过 AI 路径
func is_telegraph_active() -> bool:
	return _telegraph_active
var _telegraph_timer: float = 0.0
var _original_modulate: Color = Color.WHITE
const TELEGRAPH_DURATION: float = 0.12
const TELEGRAPH_COLOR: Color = Color(1.0, 0.3, 0.3, 1.0)  # 红色


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_update_timers(delta)
	_update_telegraph(delta)

	if is_hurt:
		_process_hurt(delta)
	elif is_stunned:
		_process_stunned(delta)
	else:
		_process_behavior(delta)

	move_and_slide()
	_update_visual()
	_update_animation()


## 行为处理（子类实现）
func _process_behavior(_delta: float) -> void:
	pass


## 受伤处理
func take_damage(damage: int, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return

	stats.current_health = maxi(stats.current_health - damage, 0)
	health_changed.emit(stats.current_health, stats.max_health)

	if stats.current_health <= 0:
		_die()
	else:
		_start_hurt(knockback_dir)


## 开始受伤状态
func _start_hurt(knockback_dir: Vector2) -> void:
	is_hurt = true
	hurt_timer = stats.hurt_duration
	hurt.emit(stats.attack_damage, knockback_dir)

	velocity = knockback_dir * stats.knockback_force
	_deactivate_hitbox()


## 处理受伤状态
func _process_hurt(delta: float) -> void:
	hurt_timer -= delta
	velocity = velocity.move_toward(Vector2.ZERO, stats.knockback_friction * delta)

	if hurt_timer <= 0:
		is_hurt = false


## 死亡处理
func _die() -> void:
	is_dead = true
	died.emit(self)
	_deactivate_hitbox()
	_set_hurtbox_active(false)

	if animated_sprite:
		animated_sprite.play("death")
		await animated_sprite.animation_finished

	queue_free()


## 眩晕
func apply_stun(duration: float) -> void:
	is_stunned = true
	stun_timer = duration


## 处理眩晕状态
func _process_stunned(_delta: float) -> void:
	velocity = Vector2.ZERO


## 更新计时器
func _update_timers(delta: float) -> void:
	if stun_timer > 0:
		stun_timer -= delta
		if stun_timer <= 0:
			is_stunned = false

	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta


## 激活 Hitbox
func _activate_hitbox() -> void:
	_has_dealt_damage = false  # 重置伤害标记
	if hitbox:
		for child in hitbox.get_children():
			if child is CollisionShape2D:
				# 根据朝向更新 Hitbox 位置
				var offset_x = 8.0 if facing_right else -8.0
				child.position.x = offset_x
				child.disabled = false

## 检查 Hitbox 重叠的目标
func _check_hitbox_overlaps() -> void:
	if _has_dealt_damage:
		return  # 本次攻击已经造成过伤害

	if not hitbox:
		return

	var overlapping = hitbox.get_overlapping_areas()
	for area in overlapping:
		if area != hurtbox and area.is_in_group("player_hurtbox"):
			var target = area.get_parent()
			if target and target.has_method("take_damage"):
				var knockback_dir = target.global_position.direction_to(global_position) * -1
				target.take_damage(stats.attack_damage, knockback_dir)
				_on_hit_landed(target)
				_has_dealt_damage = true
				break  # 只对一个目标造成伤害


## 命中玩家后的回调（子类 override 自定义顿帧/特效）
## 默认行为：按伤害值触发 Hit Stop（Phase 2 行为，普通敌人继承）
## Boss override 此函数可改为按 attack_type 分级 + 触发专属特效
func _on_hit_landed(_target: Node) -> void:
	HitStop.trigger_by_damage(get_tree(), stats.attack_damage)


## 禁用 Hitbox
func _deactivate_hitbox() -> void:
	if hitbox:
		for child in hitbox.get_children():
			if child is CollisionShape2D:
				child.disabled = true


## 设置 Hurtbox 激活状态
func _set_hurtbox_active(active: bool) -> void:
	if hurtbox:
		for child in hurtbox.get_children():
			if child is CollisionShape2D:
				child.disabled = not active


## 更新视觉
func _update_visual() -> void:
	if sprite_root:
		sprite_root.scale.x = 1 if facing_right else -1


## 更新动画（子类可重写）
func _update_animation() -> void:
	pass


## Hurtbox 接收攻击
func _on_hurtbox_area_entered(area: Area2D) -> void:
	if is_dead:
		return

	if area.is_in_group("player_hitbox"):
		var attacker = area.get_parent()
		var knockback_dir = global_position.direction_to(attacker.global_position) * -1
		var damage = _get_attack_damage(attacker)

		# 检查玩家完美格挡
		if attacker.has_method("is_perfect_blocking") and attacker.is_perfect_blocking():
			apply_stun(0.5)
			return

		take_damage(damage, knockback_dir)


## 获取攻击伤害
func _get_attack_damage(attacker: Node) -> int:
	if attacker.has_method("get_current_attack_damage"):
		return attacker.get_current_attack_damage()
	return 10


## 检测到玩家
func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		target = body


## 玩家离开检测范围
func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == target:
		target = null


# ========== 攻击前摇（Telegraph）==========
## 攻击前 0.12s 闪烁红色，给玩家反应窗口
## 子类在 _start_attack 前调用
func _show_attack_telegraph() -> void:
	_telegraph_active = true
	_telegraph_timer = TELEGRAPH_DURATION
	modulate = TELEGRAPH_COLOR


func _update_telegraph(delta: float) -> void:
	if not _telegraph_active:
		return
	_telegraph_timer -= delta
	if _telegraph_timer <= 0:
		_telegraph_active = false
		modulate = _original_modulate
