## BT Sequence（AND 节点）
## 依次 tick 子节点，遇到 FAILURE 立即返回，全 SUCCESS 才返回 SUCCESS
## 遇到 RUNNING 时记住位置，下次 tick 从该节点继续
class_name BTSequence
extends BTNode

var _current_index: int = 0


func tick(delta: float, context: Dictionary) -> int:
	while _current_index < children.size():
		var child := children[_current_index]
		var status := child.tick(delta, context)
		if status == Status.FAILURE:
			_current_index = 0
			return Status.FAILURE
		if status == Status.RUNNING:
			return Status.RUNNING
		# SUCCESS → 继续下一个
		_current_index += 1
	_current_index = 0
	return Status.SUCCESS


func reset() -> void:
	_current_index = 0
	super.reset()
