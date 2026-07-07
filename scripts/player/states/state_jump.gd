## 玩家状态：Jump（跳跃上升 + 下落）
## 同时处理 JUMP_RISE 和 JUMP_FALL，伪3D 跳跃（原地跳 + 视觉偏移）
## 上升结束自动转 JUMP_FALL，落地后转 IDLE
## RISE/FALL 共享 state instance，prev_state 区分"新跳跃"vs"续接"

extends "res://scripts/player/states/state_base.gd"


func enter(data: Dictionary = {}) -> void:
	# 只在从 IDLE/RUN 进入时才初始化跳跃参数
	# RISE→FALL 时 enter 也会被调用（同一 instance），但此时 jump_height 已被 process 推到 >0，跳过初始化
	var prev := data.get("prev_state", PlayerState.State.IDLE)
	if prev == PlayerState.State.IDLE or prev == PlayerState.State.RUN:
		player.jump_height = 0.0
		player.jump_velocity = sqrt(2.0 * player.JUMP_GRAVITY * player.MAX_JUMP_HEIGHT)


func process(delta: float) -> void:
	player.jump_velocity -= player.JUMP_GRAVITY * delta
	player.jump_height += player.jump_velocity * delta

	# RISE → FALL 自动转换（velocity 由正变负）
	if fsm.current_state == PlayerState.State.JUMP_RISE and player.jump_velocity <= 0:
		fsm.transition_to(PlayerState.State.JUMP_FALL)
		return

	# 落地 → IDLE
	if player.jump_height <= 0.0:
		player.jump_height = 0.0
		player.jump_velocity = 0.0
		fsm.transition_to(PlayerState.State.IDLE)
		return

	# 空中水平方向微调
	var direction := player._read_movement_direction()
	if direction.length() > 0.01:
		player.velocity = direction.normalized() * player.SPEED * 0.5
	else:
		player.velocity = Vector2.ZERO


func exit() -> void:
	# 不重置 jump_height/jump_velocity：
	# RISE→FALL 时需要保留数值继续下落
	# 落地时 process 已将数值清零
	pass


func handle_input(_event: Dictionary) -> bool:
	return true