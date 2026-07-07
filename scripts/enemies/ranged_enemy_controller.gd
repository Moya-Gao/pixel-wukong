## 远程敌人（法师型）
## 行为：发现玩家 → 保持理想距离 → 射击子弹
## 不近战，所以没有 Hitbox，只有 Hurtbox + DetectionArea

extends "res://scripts/enemies/enemy_base.gd"
class_name RangedEnemyController

# ========== 远程特有参数（@export 让场景编辑器可调）==========
@export var preferred_distance: float = 150.0  # 理想战斗距离
@export var retreat_distance: float = 80.0  # 玩家近于此则后退
@export var max_chase_distance: float = 350.0  # 玩家远于此则放弃追击
@export var shoot_range: float = 200.0  # 射击最大距离
@export var shoot_cooldown: float = 2.0  # 射击间隔
@export var bullet_speed: float = 250.0
@export var bullet_damage: int = 8
@export var bullet_lifetime: float = 3.0
@export var bullet_scene: PackedScene

# ========== 状态 ==========
var shoot_timer: float = 0.0


func _ready() -> void:
	super._ready()
	shoot_timer = shoot_cooldown  # 第一次不要立即射击，给玩家反应时间


func _process_behavior(delta: float) -> void:
	if not target:
		velocity = Vector2.ZERO
		return

	shoot_timer -= delta
	var dist_to_target: float = global_position.distance_to(target.global_position)

	# 玩家太远 → 不追，保持原地（远程法师不会满场跑）
	if dist_to_target > max_chase_distance:
		velocity = Vector2.ZERO
		return

	# 玩家太近 → 后退
	if dist_to_target < retreat_distance:
		_retreat_from_target()
		return

	# 在射击范围内 → 停下射击
	if dist_to_target <= shoot_range:
		velocity = Vector2.ZERO
		if shoot_timer <= 0:
			_shoot()
			shoot_timer = shoot_cooldown
		return

	# 在 preferred_distance 之外但还在 chase 距离 → 走近
	_approach_target()


func _approach_target() -> void:
	var direction := sign(target.global_position.x - global_position.x)
	if direction != 0:
		facing_right = direction > 0
	velocity.x = direction * stats.move_speed
	velocity.y = 0


func _retreat_from_target() -> void:
	var direction := sign(global_position.x - target.global_position.x)
	if direction != 0:
		facing_right = direction > 0
	velocity.x = direction * stats.move_speed * 0.8  # 后退比前进稍慢
	velocity.y = 0


func _shoot() -> void:
	if not bullet_scene or not target:
		return

	var bullet: Area2D = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)

	# 子弹从敌人朝向偏移一点位置发射（避免与 Hurtbox 重叠）
	var spawn_offset := Vector2(10.0 if facing_right else -10.0, -12.0)
	bullet.global_position = global_position + spawn_offset

	var direction := (target.global_position - global_position).normalized()
	bullet.setup(direction, bullet_speed, bullet_damage, bullet_lifetime, facing_right)


func _update_animation() -> void:
	if not animated_sprite:
		return

	var new_anim := ""
	if is_dead:
		new_anim = "death"
	elif is_hurt:
		new_anim = "hurt"
	elif velocity.length() > 10:
		new_anim = "run"
	else:
		new_anim = "idle"

	if new_anim != animated_sprite.animation:
		animated_sprite.play(new_anim)