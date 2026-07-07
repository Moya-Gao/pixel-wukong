## 远程敌人子弹
## Area2D 直线匀速飞行，命中玩家或超时自毁
## 通过 emit hit_player signal 让 DamageFeedback 监听触发飘字震动

extends Area2D
class_name Projectile

signal hit_player(damage: int)

var direction: Vector2 = Vector2.RIGHT
var speed: float = 250.0
var damage: int = 10
var lifetime: float = 3.0

var _lifetime_timer: float = 0.0
var _has_hit: bool = false


func _ready() -> void:
	# 加入 enemy_hitbox group 以保持跟近战敌人的 group 约定一致
	add_to_group("enemy_hitbox")
	add_to_group("projectile")
	_lifetime_timer = lifetime


## 配置子弹参数
func setup(dir: Vector2, spd: float, dmg: int, life: float, facing_right: bool) -> void:
	direction = dir.normalized()
	speed = spd
	damage = dmg
	lifetime = life
	_lifetime_timer = life

	# 视觉朝向
	scale.x = 1.0 if facing_right else -1.0


func _process(delta: float) -> void:
	if _has_hit:
		return

	position += direction * speed * delta
	_lifetime_timer -= delta

	if _lifetime_timer <= 0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _has_hit:
		return
	# 只命中玩家，忽略场景里的其他 body（墙壁 / 其他敌人）
	if not body.is_in_group("player"):
		return

	if body.has_method("take_damage"):
		body.take_damage(damage, -direction)

	hit_player.emit(damage)
	_has_hit = true
	queue_free()