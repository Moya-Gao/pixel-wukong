## Boss 登场 + 阶段切换特效控制器
## 纯视觉层：监听 boss_phase_changed 信号 → 屏幕暗化 + 阶段名大字 + 横条扩散
## 不改 BT/FSM/数值，仅叠加特效。
##
## 用法：
##   1. 在 Boss 场景根下挂一个 Node，脚本挂这个
##   2. arena._ready() 里 controller.bind(boss, hp_bar) 然后 play_intro()
##   3. 监听 intro_finished 信号（玩家开始可操作时机）

extends Node
class_name BossIntroController

# ========== 信号 ==========
signal intro_started
signal intro_finished

# ========== 引用 ==========
var _boss: BossBase
var _hp_bar: BossHPBar

# ========== CanvasLayer + 视觉节点 ==========
var _canvas: CanvasLayer
var _overlay: ColorRect        # 全屏暗化层
var _phase_label: Label        # 阶段名大字
var _phase_accent: ColorRect   # 阶段颜色横条

# ========== 常量 ==========
const LAYER := 20              # 高于 BossHPBar (layer=10)
const INTRO_NAME_DURATION := 1.8  # 登场序列总时长
const PHASE_EFFECT_DURATION := 1.5  # 与 BossBase._phase_transition_duration 对齐
const DARK_ALPHA := 0.65
const FONT_SIZE_BIG := 48
const PHASE_LABEL_RATIO := 0.4   # 屏幕高度比例

var _is_playing: bool = false
var _boss_saved_process_mode: int = -1  # intro 期间冻结 Boss 子树，结束后恢复


func _ready() -> void:
	# CanvasLayer 在最上层（layer=20 > BossHPBar=10）
	_canvas = CanvasLayer.new()
	_canvas.layer = LAYER
	add_child(_canvas)

	# 全屏暗化层（透明起步）
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.add_child(_overlay)

	# 阶段名称大字
	_phase_label = Label.new()
	_phase_label.add_theme_font_size_override("font_size", FONT_SIZE_BIG)
	_phase_label.add_theme_color_override("font_color", Color.WHITE)
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_phase_label.modulate.a = 0.0
	_canvas.add_child(_phase_label)

	# 阶段颜色横条（宽度从 0 扩展到全屏）
	_phase_accent = ColorRect.new()
	_phase_accent.color = Color.WHITE
	_phase_accent.modulate.a = 0.0
	_canvas.add_child(_phase_accent)


## 绑定 Boss + HP Bar，开始监听阶段切换
func bind(boss: BossBase, hp_bar: BossHPBar) -> void:
	_boss = boss
	_hp_bar = hp_bar
	_boss.boss_phase_changed.connect(_on_phase_changed)


func _on_phase_changed(new_phase: int, phase_name: String) -> void:
	# P1 是初始阶段，不触发切换特效
	if new_phase == 0:
		return
	_play_phase_effect(new_phase, phase_name)


## 阶段切换特效：暗化 → 名称浮现 → 横条扩展 → 持续 → 淡出
func _play_phase_effect(new_phase: int, phase_name: String) -> void:
	if _is_playing:
		return  # 防重入
	_is_playing = true

	# 取阶段颜色（与 HP bar 一致）
	var phase_color := Color.WHITE
	if _hp_bar and new_phase < _hp_bar.HP_COLORS.size():
		phase_color = _hp_bar.HP_COLORS[new_phase]

	_phase_label.text = phase_name
	_phase_label.add_theme_color_override("font_color", phase_color)
	_phase_accent.color = phase_color

	var screen_size := get_viewport().get_visible_rect().size
	# 阶段名居中（屏幕中上部）
	_phase_label.size = screen_size
	_phase_label.position = Vector2(0, screen_size.y * PHASE_LABEL_RATIO - FONT_SIZE_BIG)
	# 横条起始宽度 0，高度 4px，位于名称下方
	_phase_accent.size = Vector2(0, 4)
	_phase_accent.position = Vector2(0, screen_size.y * PHASE_LABEL_RATIO + FONT_SIZE_BIG * 0.5)

	var t := create_tween()
	# 暗化（0.3s）
	t.tween_property(_overlay, "color:a", DARK_ALPHA, 0.3)
	# 阶段名浮现（0.4s） + 横条扩展（0.5s）
	t.parallel().tween_property(_phase_label, "modulate:a", 1.0, 0.4)
	t.parallel().tween_property(_phase_accent, "modulate:a", 1.0, 0.2)
	t.parallel().tween_property(_phase_accent, "size:x", screen_size.x, 0.5)
	# 持续显示（0.6s）
	t.tween_interval(0.6)
	# 淡出（0.4s）
	t.tween_property(_overlay, "color:a", 0.0, 0.4)
	t.parallel().tween_property(_phase_label, "modulate:a", 0.0, 0.4)
	t.parallel().tween_property(_phase_accent, "modulate:a", 0.0, 0.4)
	t.parallel().tween_property(_phase_accent, "size:x", 0, 0.4)

	t.tween_callback(func(): _is_playing = false)


## 播放登场序列（开场）
## 流程：HP bar 隐藏 → Boss 冻结 → 黑屏 → Boss 名大字 → 淡出 → HP bar 从左滑入 → Boss 解冻
func play_intro() -> void:
	if _is_playing or not _boss:
		return
	_is_playing = true
	intro_started.emit()

	# 登场期间冻结 Boss 子树（BT 不 tick、不接受输入），演出结束恢复
	_boss_saved_process_mode = _boss.process_mode
	_boss.process_mode = Node.PROCESS_MODE_DISABLED

	# 登场前隐藏 HP bar
	if _hp_bar:
		_hp_bar.hide_for_intro()

	var boss_name := _boss.boss_stats.boss_name
	var phase_color := Color.WHITE
	if _hp_bar and not _hp_bar.HP_COLORS.is_empty():
		phase_color = _hp_bar.HP_COLORS[0]

	_phase_label.text = boss_name
	_phase_label.add_theme_color_override("font_color", phase_color)

	var screen_size := get_viewport().get_visible_rect().size
	_phase_label.size = screen_size
	_phase_label.position = Vector2(0, screen_size.y * PHASE_LABEL_RATIO - FONT_SIZE_BIG)

	# 第一段：黑屏 + 大字浮现
	var t := create_tween()
	t.tween_property(_overlay, "color:a", DARK_ALPHA, 0.4)
	t.parallel().tween_property(_phase_label, "modulate:a", 1.0, 0.5)
	t.tween_interval(1.0)
	t.tween_property(_overlay, "color:a", 0.0, 0.4)
	t.parallel().tween_property(_phase_label, "modulate:a", 0.0, 0.4)

	# 第二段：HP bar slide-in（HP bar 自己知道目标 X）
	t.tween_callback(_on_intro_slide_in)

	t.tween_callback(_finish_intro)


## HP bar slide-in 由 BossHPBar 自管
func _on_intro_slide_in() -> void:
	if _hp_bar:
		_hp_bar.slide_in()


## Intro 结束：恢复 Boss 处理
func _finish_intro() -> void:
	if _boss and _boss_saved_process_mode != -1:
		_boss.process_mode = _boss_saved_process_mode
		_boss_saved_process_mode = -1
	_is_playing = false
	intro_finished.emit()