## 小怪控制器
## 行为：巡逻 -> 发现玩家 -> 追击 -> 攻击

class_name GruntController extends "res://scripts/enemies/enemy_base.gd"

# ========== AI 状态标志 ==========
var is_patrolling: bool = true
var is_chasing: bool = false
var is_waiting: bool = false

# ========== 巡逻参数 ==========
var patrol_start_pos: Vector2
var patrol_target_pos: Vector2
var patrol_wait_timer: float = 0.0


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


# ========== 重写受伤处理 ==========
func _process_hurt(delta: float) -> void:
	super._process_hurt(delta)

	# 受伤时取消当前行为
	is_chasing = false
	is_attacking = false


# ========== 动画更新 ==========
func _update_animation() -> void:
	if not animated_sprite:
		return

	var new_anim = ""

	if is_dead:
		new_anim = "death"
	elif is_hurt:
		new_anim = "hurt"
	elif is_attacking:
		new_anim = "attack"
	elif is_chasing or velocity.length() > 10:
		new_anim = "run"
	else:
		new_anim = "idle"

	if new_anim != animated_sprite.animation:
		animated_sprite.play(new_anim)
