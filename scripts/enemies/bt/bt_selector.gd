## BT Selector（OR 节点）
## 依次 tick 子节点，遇到 SUCCESS/RUNNING 立即返回，全 FAILURE 才返回 FAILURE
class_name BTSelector
extends BTNode


func tick(delta: float, context: Dictionary) -> int:
	for child in children:
		var status := child.tick(delta, context)
		if status != Status.FAILURE:
			return status
	return Status.FAILURE
