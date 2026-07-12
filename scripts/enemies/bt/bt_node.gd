## Behavior Tree 节点基类
## 轻量 BT 实现，使用 RefCounted 不依赖场景树
## tick(delta, context) → SUCCESS / FAILURE / RUNNING
class_name BTNode
extends RefCounted

enum Status { SUCCESS, FAILURE, RUNNING }

var children: Array[BTNode] = []


func add_child(node: BTNode) -> void:
	children.append(node)


func tick(_delta: float, _context: Dictionary) -> int:
	return Status.FAILURE


## 重置内部状态（Sequence 的游标等）
func reset() -> void:
	for child in children:
		child.reset()
