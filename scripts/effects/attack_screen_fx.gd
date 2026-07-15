## Boss 重击屏幕效果控制器
## 监听 group "boss" 里 BossBase.boss_attack_landed 信号
## attack_name 含 slam / charge / berserk / combo / heavy 任一关键字触发径向暗角
## 自管 CanvasLayer, 防重入

extends Node
class_name AttackScreenFX

# ========== 常量 ==========
const LAYER := 25
const VIGNETTE_PEAK := Color(0.04, 0.0, 0.08, 0.25)
const ATTACK_IN := 0.03
const ATTACK_HOLD := 0.05
const ATTACK_OUT := 0.12
const HEAVY_KEYWORDS := ["slam", "charge", "berserk", "combo", "heavy"]

# ========== 视觉节点 ==========
var _canvas: CanvasLayer
var _vignette: ColorRect

var _is_playing: bool = false


func _ready() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = LAYER
	add_child(_canvas)

	_vignette = ColorRect.new()
	_vignette.color = Color(0, 0, 0, 0)
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_vignette)

	await get_tree().process_frame
	for boss in get_tree().get_nodes_in_group("boss"):
		if boss.has_signal("boss_attack_landed"):
			if not boss.boss_attack_landed.is_connected(_on_boss_attack_landed):
				boss.boss_attack_landed.connect(_on_boss_attack_landed)


func _on_boss_attack_landed(attack_name: String) -> void:
	var is_heavy := false
	for kw in HEAVY_KEYWORDS:
		if attack_name.contains(kw):
			is_heavy = true
			break
	if not is_heavy:
		return
	trigger_heavy()


## 触发重击屏幕效果
func trigger_heavy() -> void:
	if _is_playing:
		return
	_is_playing = true

	var t := create_tween()
	t.tween_property(_vignette, "color", VIGNETTE_PEAK, ATTACK_IN)
	t.tween_interval(ATTACK_HOLD)
	t.tween_property(_vignette, "color:a", 0.0, ATTACK_OUT)
	t.tween_callback(func(): _is_playing = false)
