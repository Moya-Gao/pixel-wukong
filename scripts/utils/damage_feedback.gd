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

# ========== 飘字配置 ==========
const DAMAGE_NUMBER_SCENE := preload("res://scenes/utils/damage_number.tscn")

# ========== 缓存引用 ==========
var _camera_shake: Camera2D = null
var _player: Node = null


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

	_flash_white(enemy)
	_spawn_damage_number(enemy.global_position + Vector2(0, -16), damage, true)
	_trigger_shake(damage)


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


func _spawn_damage_number(pos: Vector2, damage: int, _is_enemy_hit: bool) -> void:
	var node: DamageNumber = DAMAGE_NUMBER_SCENE.instantiate()
	get_tree().current_scene.add_child(node)
	node.global_position = pos
	node.setup(damage, _is_enemy_hit)