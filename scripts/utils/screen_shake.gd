## 屏幕震动 Camera2D 扩展
## 提供 shake(intensity, duration) 方法触发瞬时震动
## 多个伤害事件同时发生时取最大震动强度叠加（不叠加出更猛）

extends Camera2D
class_name ScreenShake

var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0
var _shake_timer: float = 0.0
var _original_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("camera_shake")
	_original_offset = offset


## 触发一次屏幕震动。多次调用取最大强度叠加。
func shake(intensity: float, duration: float) -> void:
	if intensity > _shake_intensity:
		_shake_intensity = intensity
		_shake_duration = duration
		_shake_timer = duration


func _process(delta: float) -> void:
	if _shake_timer <= 0:
		if offset != _original_offset:
			offset = _original_offset
		return

	_shake_timer -= delta
	var random_offset := Vector2(
		randf_range(-_shake_intensity, _shake_intensity),
		randf_range(-_shake_intensity, _shake_intensity)
	)
	offset = _original_offset + random_offset
	# 强度随时间衰减
	_shake_intensity = _shake_intensity * (1.0 - delta * 3.0)