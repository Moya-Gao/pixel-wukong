## 玩家状态：Dodge（闪避）
## 行为：高速移动 + 无敌帧管理，闪避结束回 IDLE

extends "res://scripts/player/states/state_base.gd"


func enter(data: Dictionary = {}) -> void:
	player.is_dodging = true
	player.dodge_timer = player.DODGE_DURATION
	player.dodge_cooldown_timer = player.DODGE_COOLDOWN

	# 确定闪避方向（传入的方向优先，否则按朝向）
	var direction := data.get("direction", Vector2.ZERO)
	if direction.length() > 0.1:
		player.dodge_direction = direction.normalized()
	else:
		player.dodge_direction = Vector2.RIGHT if player.facing_right else Vector2.LEFT

	# 取消当前状态
	if player.is_attacking:
		player._end_attack()
	if player.is_blocking:
		player._end_block()


func process(delta: float) -> void:
	player.dodge_timer -= delta

	# 无敌帧管理：闪避后段（DODGE_DURATION - INVINCIBLE_START 到 - INVINCIBLE_END）
	if player.dodge_timer <= player.DODGE_DURATION - player.INVINCIBLE_START and \
	   player.dodge_timer >= player.DODGE_DURATION - player.INVINCIBLE_END:
		if not player.is_invincible:
			player.is_invincible = true
			player._set_hurtbox_active(false)
	else:
		if player.is_invincible:
			player.is_invincible = false
			player._set_hurtbox_active(true)

	# 闪避移动
	player.velocity = player.dodge_direction * player.DODGE_SPEED

	# 闪避结束
	if player.dodge_timer <= 0:
		player._end_dodge()
		fsm.transition_to(PlayerState.State.IDLE)


func exit() -> void:
	player.is_invincible = false
	player._set_hurtbox_active(true)
	player.velocity = Vector2.ZERO


func handle_input(_event: Dictionary) -> bool:
	# 闪避期间不接受新输入（已经是高速移动中）
	return true