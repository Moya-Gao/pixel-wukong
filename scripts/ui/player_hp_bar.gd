## 玩家血条 UI
## CanvasLayer 独立 UI，挂在关卡场景中，自动 find player group 连接
## 显示：名称、血条（绿→黄→红）、血量数字
class_name PlayerHPBar
extends CanvasLayer

# ========== 常量 ==========
const BAR_WIDTH: float = 130.0
const BAR_HEIGHT: float = 10.0
const PANEL_W: float = BAR_WIDTH + 24
const PANEL_H: float = 42.0

# 血条颜色（按血量比例：绿 → 黄 → 红）
const HP_COLOR_FULL := Color(0.2, 0.8, 0.2, 0.9)
const HP_COLOR_MID := Color(0.9, 0.8, 0.1, 0.9)
const HP_COLOR_LOW := Color(0.9, 0.2, 0.2, 0.9)
const LOW_THRESHOLD := 0.3
const MID_THRESHOLD := 0.6

# ========== 节点 ==========
var _panel: Panel
var _name_label: Label
var _hp_bg: ColorRect
var _hp_fill: ColorRect
var _hp_label: Label

# ========== 状态 ==========
var _player: CharacterBody2D = null
var _target_hp_ratio: float = 1.0
var _display_hp_ratio: float = 1.0


func _ready() -> void:
	layer = 10

	# 面板（右上角）
	_panel = Panel.new()
	_panel.size = Vector2(PANEL_W, PANEL_H)
	_panel.visible = false
	add_child(_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.05, 0.8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.4, 0.4, 0.7)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	_panel.add_theme_stylebox_override("panel", style)

	# 名称
	_name_label = Label.new()
	_name_label.position = Vector2(12, 4)
	_name_label.size = Vector2(BAR_WIDTH, 14)
	_name_label.add_theme_font_size_override("font_size", 10)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_name_label.text = "悟空"
	_panel.add_child(_name_label)

	# 血条背景
	_hp_bg = ColorRect.new()
	_hp_bg.position = Vector2(12, 20)
	_hp_bg.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_hp_bg.color = Color(0.1, 0.1, 0.1, 0.8)
	_panel.add_child(_hp_bg)

	# 血条填充
	_hp_fill = ColorRect.new()
	_hp_fill.position = Vector2(12, 20)
	_hp_fill.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_hp_fill.color = HP_COLOR_FULL
	_panel.add_child(_hp_fill)

	# 血量数字
	_hp_label = Label.new()
	_hp_label.position = Vector2(12, 20)
	_hp_label.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_hp_label.add_theme_font_size_override("font_size", 8)
	_hp_label.add_theme_color_override("font_color", Color.WHITE)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_panel.add_child(_hp_label)

	# 延迟一帧找 player，确保所有节点都已 _ready
	await get_tree().process_frame
	_find_and_bind_player()


func _find_and_bind_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]
		if _player.has_signal("player_health_changed"):
			_player.player_health_changed.connect(_on_player_health_changed)
		# 面板定位：右上角（x = viewport width - panel width - margin）
		_panel.position.x = get_viewport().get_visible_rect().size.x - PANEL_W - 12
		_panel.position.y = 10
		_panel.visible = true


func _process(delta: float) -> void:
	if not _player:
		return
	if abs(_display_hp_ratio - _target_hp_ratio) > 0.001:
		_display_hp_ratio = move_toward(_display_hp_ratio, _target_hp_ratio, delta * 1.2)
		_update_bar_display()


func _on_player_health_changed(current: int, max_hp: int) -> void:
	_target_hp_ratio = float(current) / float(max_hp)
	_update_bar_display()


func _update_bar_display() -> void:
	var ratio := _display_hp_ratio
	var max_hp := 100
	var current_health := 100
	if _player:
		max_hp = _player.max_health
		current_health = _player.current_health

	_hp_fill.size.x = BAR_WIDTH * ratio

	# 颜色：绿→黄→红
	if ratio > MID_THRESHOLD:
		_hp_fill.color = HP_COLOR_FULL
	elif ratio > LOW_THRESHOLD:
		_hp_fill.color = HP_COLOR_MID
	else:
		_hp_fill.color = HP_COLOR_LOW

	_hp_label.text = "%d / %d" % [current_health, max_hp]
