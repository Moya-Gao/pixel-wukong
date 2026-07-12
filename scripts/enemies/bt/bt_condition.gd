## BT Condition（条件叶节点）
## 执行 condition Callable，返回 SUCCESS 或 FAILURE（永不 RUNNING）
class_name BTCondition
extends BTNode

var condition: Callable


func _init(p_condition: Callable = Callable()) -> void:
	condition = p_condition


func tick(_delta: float, context: Dictionary) -> int:
	if condition.is_valid():
		return Status.SUCCESS if condition.call(context) else Status.FAILURE
	return Status.FAILURE
