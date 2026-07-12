## BT Action（动作叶节点）
## 执行 action Callable，持续 duration 秒，期间返回 RUNNING，完成返回 SUCCESS
## duration=0 表示瞬时动作（立即 SUCCESS）
class_name BTAction
extends BTNode

var action: Callable
var duration: float = 0.0
var _elapsed: float = 0.0


func _init(p_action: Callable = Callable(), p_duration: float = 0.0) -> void:
	action = p_action
	duration = p_duration


func tick(delta: float, context: Dictionary) -> int:
	if action.is_valid():
		action.call(delta, context)

	if duration <= 0.0:
		return Status.SUCCESS

	_elapsed += delta
	if _elapsed >= duration:
		_elapsed = 0.0
		return Status.SUCCESS
	return Status.RUNNING


func reset() -> void:
	_elapsed = 0.0
	super.reset()
