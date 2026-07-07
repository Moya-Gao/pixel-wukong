## 玩家状态基类
## 所有具体状态的父类，提供 enter/exit/process/handle_input 四个钩子
## 复用宪宪 spec：state_base 抽象接口，状态间不共享具体逻辑

class_name StateBase
extends RefCounted

var player: CharacterBody2D  # 引用 PlayerController（它是 CharacterBody2D）
var fsm: PlayerStateMachine


func enter(_data: Dictionary = {}) -> void:
	pass


func exit() -> void:
	pass


func process(_delta: float) -> void:
	pass


## 输入处理。返回 true 表示该输入已消费（不再传递给其他状态）
func handle_input(_event: Dictionary) -> bool:
	return false