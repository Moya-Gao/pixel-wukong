## Boss 血条 UI
## CanvasLayer 独立 UI，挂在任意场景中，调用 attach(boss) 绑定 Boss
## 显示：Boss 名称、血条（带平滑动画）、阶段指示器
class_name BossHPBar
extends CanvasLayer

# ========== 常量 ==========
const BAR_WIDTH: float = 200.0
const BAR_HEIGHT: float = 16.0
const BAR_Y: float = 30.0
const NAME_Y: float = 8.0
const PHASE_Y: float = 50.0

const BG_COLOR := Color(0.1, 0.1, 0.1, 0.8)
const HP_COLORS: Array[Color] = [
	Color(0.9, 0.2, 0.2, 0.9),  # P1: 红
	Color(0.9, 0.5, 0.1, 0.9),  # P2: 橙
	Color(0.7, 0.1, 0.7, 0.9),  # P3: 紫
]
const PHASE_COLORS: Array[Color] = [
	Color(1.0, 0.5, 0.5),
	Color(1.0, 0.7, 0.3),
	Color(0.8, 0.4, 0.9),
]

# ========== 节点 ==========
var _panel: Panel
var _name_label: Label
var _hp_bg: ColorRect
var _hp_fill: ColorRect
var _hp_label: Label
var _phase_label: Label

# ========== 状态 ==========
var _boss: BossBase = null
var _target_hp_ratio: float = 1.0
var _display_hp_ratio: float = 1.0
var _current_phase: int = 0
var _visible_tween: Tween


func _ready() -> void:
	layer = 10  # 最上层

	# 面板
	_panel = Panel.new()
	_panel.size = Vector2(BAR_WIDTH + 40, 80)
	_panel.position = Vector2(0, 0)
	_panel.visible = false
	add_child(_panel)

	# 样式
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.05, 0.85)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.4, 0.4, 0.8)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	_panel.add_theme_stylebox_override("panel", style)

	# Boss 名称
	_name_label = Label.new()
	_name_label.position = Vector2(20, NAME_Y)
	_name_label.size = Vector2(BAR_WIDTH, 20)
	_name_label.add_theme_font_size_override("font_size", 14)
	_name_label.add_theme_color_override("font_color", Color.WHITE)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_panel.add_child(_name_label)

	# 血条背景
	_hp_bg = ColorRect.new()
	_hp_bg.position = Vector2(20, BAR_Y)
	_hp_bg.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_hp_bg.color = BG_COLOR
	_panel.add_child(_hp_bg)

	# 血条填充
	_hp_fill = ColorRect.new()
	_hp_fill.position = Vector2(20, BAR_Y)
	_hp_fill.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_hp_fill.color = HP_COLORS[0]
	_panel.add_child(_hp_fill)

	# 血量数字
	_hp_label = Label.new()
	_hp_label.position = Vector2(20, BAR_Y)
	_hp_label.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_hp_label.add_theme_font_size_override("font_size", 10)
	_hp_label.add_theme_color_override("font_color", Color.WHITE)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_panel.add_child(_hp_label)

	# 阶段指示器
	_phase_label = Label.new()
	_phase_label.position = Vector2(20, PHASE_Y)
	_phase_label.size = Vector2(BAR_WIDTH, 18)
	_phase_label.add_theme_font_size_override("font_size", 11)
	_phase_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_phase_label)


func _process(_delta: float) -> void:
	if not _boss:
		return

	# 平滑血条动画
	if abs(_display_hp_ratio - _target_hp_ratio) > 0.001:
		_display_hp_ratio = move_toward(_display_hp_ratio, _target_hp_ratio, _delta * 0.8)
		_update_bar_display()


## 绑定 Boss
func attach(boss: BossBase) -> void:
	_boss = boss
	_target_hp_ratio = 1.0
	_display_hp_ratio = 1.0
	_current_phase = 0

	# 连接信号
	boss.boss_health_changed.connect(_on_boss_health_changed)
	boss.boss_phase_changed.connect(_on_boss_phase_changed)
	boss.died.connect(_on_boss_died)

	# 初始显示
	_name_label.text = boss.boss_stats.boss_name
	_update_bar_display()
	_update_phase_display()
	_show()


func _on_boss_health_changed(current: int, max_hp: int) -> void:
	_target_hp_ratio = float(current) / float(max_hp)
	_update_bar_display()


func _on_boss_phase_changed(new_phase: int, phase_name: String) -> void:
	_current_phase = new_phase
	_update_phase_display()

	# 血条颜色切换
	if new_phase < HP_COLORS.size():
		_hp_fill.color = HP_COLORS[new_phase]


func _on_boss_died(_enemy: Node) -> void:
	_hide()


func _update_bar_display() -> void:
	var max_hp := 100
	if _boss and _boss.stats:
		max_hp = _boss.stats.max_health
	var current := int(_display_hp_ratio * max_hp)

	_hp_fill.size.x = BAR_WIDTH * _display_hp_ratio
	_hp_label.text = "%d / %d" % [current, max_hp]


func _update_phase_display() -> void:
	if _boss and _current_phase < _boss.boss_stats.phase_names.size():
		_phase_label.text = _boss.boss_stats.phase_names[_current_phase]
	else:
		_phase_label.text = "Phase " + str(_current_phase + 1)

	if _current_phase < PHASE_COLORS.size():
		_phase_label.add_theme_color_override("font_color", PHASE_COLORS[_current_phase])


func _show() -> void:
	if _panel:
		_panel.visible = true
		_panel.modulate.a = 1.0


func _hide() -> void:
	if _panel:
		# 延迟隐藏，让玩家看到 Boss 血条消失
		var t := create_tween()
		t.tween_property(_panel, "modulate:a", 0.0, 0.5)
		t.tween_callback(func(): _panel.visible = false)
