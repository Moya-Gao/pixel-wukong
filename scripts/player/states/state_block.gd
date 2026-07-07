## 玩家状态：Block（格挡）
## 行为：移动速度降低，开局有完美格挡窗口，松开或闪避输入退出

extends "res://scripts/player/states/state_base.gd"


func enter(_data: Dictionary = {}) -> void:
	player.is_blocking = true

	# 只在刚进入格挡时开启完美格挡窗口
	player.perfect_block_timer = player.PERFECT_BLOCK_WINDOW
	player.is_perfect_block = true

	# 取消当前攻击
	if player.is_attacking:
		player._end_attack()

	player._show_shield_effect(true)


func process(delta: float) -> void:
	# 应用移动（格挡时可缓慢移动）
	var direction: Vector2 = player._read_movement_direction()
	player.velocity = direction.normalized() * player.BLOCK_SPEED

	# 更新完美格挡窗口
	player.perfect_block_timer -= delta
	if player.perfect_block_timer <= 0:
		player.is_perfect_block = false

	# 松开格挡键 → IDLE
	if not player._wants_block():
		player._end_block()
		fsm.transition_to(PlayerState.State.IDLE)
		return

	# 闪避取消 → DODGE
	if player._wants_dodge():
		player._end_block()
		fsm.transition_to(PlayerState.State.DODGE, {"direction": direction})
		return


func exit() -> void:
	player.is_blocking = false
	player.is_perfect_block = false
	player.perfect_block_timer = 0.0
	player._show_shield_effect(false)


func handle_input(_event: Dictionary) -> bool:
	return true