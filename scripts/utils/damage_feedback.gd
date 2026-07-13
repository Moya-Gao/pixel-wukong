## 伤害反馈系统综合管理器
## 监听玩家命中/被命中事件，触发屏幕震动 + 飘字 + 受击闪白
## 不修改 player_controller / enemy_base 现有代码，通过监听已有 signal 实现

extends Node
class_name DamageFeedback

# ========== 屏幕震动配置 ==========
const SHAKE_HEAVY_THRESHOLD := 15
const SHAKE_HEAVY_INTENSITY := 6.0
const SHAKE_HEAVY_DURATION := 0.25
const SHAKE_LIGHT_INTENSITY := 3.0
const SHAKE_LIGHT_DURATION := 0.12

# ========== 受击闪白配置 ==========
const FLASH_DURATION := 0.12
const FLASH_COLOR := Color(2.5, 2.5, 2.5)  # HDR-style 白色闪

# ========== Boss 霸体反馈配置 ==========
## poise_resistance > 0 的敌人受击用更短 + 偏蓝的闪白，附带护盾涟漪
const POISE_FLASH_DURATION := 0.05
const POISE_FLASH_COLOR := Color(1.5, 1.5, 2.5)  # 偏蓝白色调（"抗性"质感）
const POISE_RIPPLE_DURATION := 0.3
const POISE_RIPPLE_RADIUS_START := 28.0
const POISE_RIPPLE_RADIUS_END := 40.0
const POISE_RIPPLE_COLOR := Color(0.4, 0.7, 1.0, 0.8)
const POISE_RIPPLE_WIDTH_START := 3.0
const POISE_RIPPLE_WIDTH_END := 0.0
const POISE_RIPPLE_SEGMENTS := 30  # 圆周采样点数

# ========== 飘字配置 ==========
const DAMAGE_NUMBER_SCENE := preload("res://scenes/utils/damage_number.tscn")

# ========== 缓存引用 ==========
var _camera_shake: Camera2D = null
var _player: Node = null
var _tracked_projectiles: Array = []


func _ready() -> void:
	# 延迟一帧，确保所有节点都已 _ready
	await get_tree().process_frame

	_find_camera()
	_find_player()
	_connect_signals()


func _find_camera() -> void:
	# 优先找已经在 camera_shake group 的 Camera2D
	var candidates := get_tree().get_nodes_in_group("camera_shake")
	if candidates.size() > 0 and candidates[0] is Camera2D:
		_camera_shake = candidates[0]
		return

	# Fallback: 递归找任意 Camera2D，动态附加 ScreenShake 能力
	# 这样 Player.tscn 自带的 Camera2D 不需要修改也能用
	var first_camera := _find_first_camera(get_tree().root)
	if first_camera:
		_camera_shake = first_camera
		if not _camera_shake.has_method("shake"):
			_camera_shake.set_script(load("res://scripts/utils/screen_shake.gd"))
			_camera_shake.add_to_group("camera_shake")


func _find_first_camera(node: Node) -> Camera2D:
	if node is Camera2D:
		return node
	for child in node.get_children():
		var found := _find_first_camera(child)
		if found:
			return found
	return null


func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]


func _connect_signals() -> void:
	if not _player:
		return

	# 监听玩家 Hitbox → 玩家命中敌人
	if _player.has_node("Hitbox"):
		var hitbox: Area2D = _player.get_node("Hitbox")
		if not hitbox.area_entered.is_connected(_on_player_hitbox_hit):
			hitbox.area_entered.connect(_on_player_hitbox_hit)

	# 监听玩家 Hurtbox → 玩家被敌人命中（并联第二个 listener，不影响现有逻辑）
	if _player.has_node("Hurtbox"):
		var hurtbox: Area2D = _player.get_node("Hurtbox")
		if not hurtbox.area_entered.is_connected(_on_player_hurtbox_hit):
			hurtbox.area_entered.connect(_on_player_hurtbox_hit)


# ========== 玩家命中敌人 ==========
func _on_player_hitbox_hit(area: Area2D) -> void:
	if not area.is_in_group("enemy_hurtbox"):
		return

	var enemy := area.get_parent()
	if not enemy:
		return

	var damage := _get_player_damage()
	if damage <= 0:
		return

	# Boss 走霸体分支（短闪白 + 护盾涟漪），普通敌人走普通闪白
	if _is_boss(enemy):
		_flash_boss_poise(enemy)
		_show_poise_ripple(enemy)
	else:
		_flash_white(enemy)

	_spawn_damage_number(enemy.global_position + Vector2(0, -16), damage, true)
	_trigger_shake(damage)

	# Hit Stop 由 player_controller._check_hitbox_damage 单一触发（不在此处重复）


# ========== 玩家被敌人命中 ==========
func _on_player_hurtbox_hit(area: Area2D) -> void:
	if not area.is_in_group("enemy_hitbox"):
		return

	var enemy := area.get_parent()
	var damage := 10
	if enemy and "stats" in enemy and enemy.stats:
		damage = enemy.stats.attack_damage

	_trigger_shake(damage)
	if _player:
		_spawn_damage_number(_player.global_position + Vector2(0, -16), damage, false)


# ========== 工具方法 ==========
func _get_player_damage() -> int:
	if _player and _player.has_method("get_current_attack_damage"):
		return _player.get_current_attack_damage()
	return 10


func _trigger_shake(damage: int) -> void:
	if not _camera_shake or not _camera_shake.has_method("shake"):
		return

	if damage >= SHAKE_HEAVY_THRESHOLD:
		_camera_shake.shake(SHAKE_HEAVY_INTENSITY, SHAKE_HEAVY_DURATION)
	else:
		_camera_shake.shake(SHAKE_LIGHT_INTENSITY, SHAKE_LIGHT_DURATION)


func _flash_white(enemy: Node) -> void:
	if not enemy or not enemy.has_node("SpriteRoot"):
		return

	var sprite_root: Node2D = enemy.get_node("SpriteRoot")
	sprite_root.modulate = FLASH_COLOR
	var tween := create_tween()
	tween.tween_property(sprite_root, "modulate", Color.WHITE, FLASH_DURATION)


func _is_boss(enemy: Node) -> bool:
	# 检测 BossBase 子类（poise_resistance > 0 是更强的标识，但 BossBase class_name 注册更准）
	return enemy is BossBase


func _flash_boss_poise(enemy: Node) -> void:
	# Boss 短促偏蓝闪白（"打不动"质感，比普通闪白短 + 颜色不同）
	if not enemy or not enemy.has_node("SpriteRoot"):
		return

	var sprite_root: Node2D = enemy.get_node("SpriteRoot")
	sprite_root.modulate = POISE_FLASH_COLOR
	var tween := create_tween()
	tween.tween_property(sprite_root, "modulate", Color.WHITE, POISE_FLASH_DURATION)


func _show_poise_ripple(enemy: Node) -> void:
	# Boss 受击时在 SpriteRoot 下动态建 Line2D 圆环，tween 扩散 + 宽度衰减 + 淡出
	if not enemy or not enemy.has_node("SpriteRoot"):
		return

	var sprite_root: Node2D = enemy.get_node("SpriteRoot")
	var ripple := Line2D.new()
	ripple.name = "PoiseRipple"
	ripple.closed = true
	ripple.width = POISE_RIPPLE_WIDTH_START
	ripple.default_color = POISE_RIPPLE_COLOR

	# POISE_RIPPLE_SEGMENTS 个点的圆，半径 POISE_RIPPLE_RADIUS_START
	var points := PackedVector2Array()
	for i in range(POISE_RIPPLE_SEGMENTS):
		var angle: float = TAU * float(i) / float(POISE_RIPPLE_SEGMENTS)
		points.append(Vector2(cos(angle), sin(angle)) * POISE_RIPPLE_RADIUS_START)
	ripple.points = points
	ripple.scale = Vector2.ONE
	sprite_root.add_child(ripple)

	# tween: scale 扩大 + 宽度衰减 + alpha 淡出 + 完成后 free
	# bind_node(ripple) 让 tween 跟 ripple 一起死 — Boss queue_free 时不引用悬空对象
	var scale_factor := POISE_RIPPLE_RADIUS_END / POISE_RIPPLE_RADIUS_START
	var tween := create_tween().bind_node(ripple)
	tween.set_parallel(true)
	tween.tween_property(ripple, "scale", Vector2(scale_factor, scale_factor), POISE_RIPPLE_DURATION)
	tween.tween_property(ripple, "width", POISE_RIPPLE_WIDTH_END, POISE_RIPPLE_DURATION)
	tween.tween_property(ripple, "modulate:a", 0.0, POISE_RIPPLE_DURATION)
	tween.set_parallel(false)
	tween.tween_callback(ripple.queue_free)


func _spawn_damage_number(pos: Vector2, damage: int, _is_enemy_hit: bool) -> void:
	var node: DamageNumber = DAMAGE_NUMBER_SCENE.instantiate()
	get_tree().current_scene.add_child(node)
	node.global_position = pos
	node.setup(damage, _is_enemy_hit)


# ========== 子弹命中监听 ==========
# 子弹在 RangedEnemy._shoot() 里运行时创建，_ready 时还不存在
# 用 _process 持续扫描 projectile group，动态 connect 新子弹的 hit_player signal
func _process(_delta: float) -> void:
	for proj in get_tree().get_nodes_in_group("projectile"):
		if proj in _tracked_projectiles:
			continue
		if proj.has_signal("hit_player"):
			proj.hit_player.connect(_on_projectile_hit_player)
			_tracked_projectiles.append(proj)


func _on_projectile_hit_player(damage: int) -> void:
	_trigger_shake(damage)
	if _player:
		_spawn_damage_number(_player.global_position + Vector2(0, -16), damage, false)