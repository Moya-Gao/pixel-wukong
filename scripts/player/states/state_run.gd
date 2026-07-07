## 玩家状态：Run（移动）
## 行为：应用移动速度，无输入则回 IDLE

extends "res://scripts/player/states/state_base.gd"


func process(delta: float) -> void:
	var direction: Vector2 = player._read_movement_direction()

	# 无方向输入 → 回 IDLE
	if direction.length() < 0.01:
		fsm.transition_to(PlayerState.State.IDLE)
		return

	# 更新朝向
	if direction.x != 0:
		player.facing_right = direction.x > 0

	# 应用移动速度（伪3D 8 方向）
	player.velocity = direction.normalized() * player.SPEED

	# 攻击输入（移动中也能攻击）
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

	# 闪避 / 格挡
	if player._wants_dodge():
		fsm.transition_to(PlayerState.State.DODGE)
		return
	if player._wants_block():
		fsm.transition_to(PlayerState.State.BLOCK)
		return


func handle_input(_event: Dictionary) -> bool:
	return false