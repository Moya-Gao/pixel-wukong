## 玩家状态：Idle（站立）
## 行为：速度为零，检测输入转换到 RUN / JUMP / 攻击 / DODGE / BLOCK

extends "res://scripts/player/states/state_base.gd"


func enter(_data: Dictionary = {}) -> void:
	if player.has_method("set_velocity"):
		player.velocity = Vector2.ZERO


func process(delta: float) -> void:
	# 移动方向检测
	var direction: Vector2 = player._read_movement_direction()
	if direction.length() > 0.01:
		fsm.transition_to(PlayerState.State.RUN)
		return

	# 攻击输入
	if player._wants_light_attack():
		fsm.transition_to(PlayerState.State.ATTACK_LIGHT, {"combo": 1})
		return
	if player._wants_heavy_attack():
		fsm.transition_to(PlayerState.State.ATTACK_HEAVY, {"combo": 0})
		return

	# 跳跃
	if player._wants_jump():
		fsm.transition_to(PlayerState.State.JUMP_RISE)
		return

	# 闪避
	if player._wants_dodge():
		fsm.transition_to(PlayerState.State.DODGE)
		return

	# 格挡（按住）
	if player._wants_block():
		fsm.transition_to(PlayerState.State.BLOCK)
		return


func handle_input(_event: Dictionary) -> bool:
	# Idle 状态的输入由 process 检测，无需 handle_input 钩子
	return false