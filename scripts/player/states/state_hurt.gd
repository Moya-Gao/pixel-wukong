## 玩家状态：Hurt（受伤）
## 行为：应用击退速度，受伤计时器归零后回 IDLE

extends "res://scripts/player/states/state_base.gd"


func enter(data: Dictionary = {}) -> void:
	player.is_hurt = true
	player.hurt_timer = player.HURT_DURATION
	player.knockback_velocity = data.get("knockback", Vector2.ZERO)

	# 取消当前攻击/格挡状态（如果有）
	if player.is_attacking:
		player._end_attack()
	if player.is_blocking:
		player._end_block()


func process(delta: float) -> void:
	player.hurt_timer -= delta
	player.knockback_velocity = player.knockback_velocity.move_toward(Vector2.ZERO, 500.0 * delta)
	player.velocity = player.knockback_velocity

	if player.hurt_timer <= 0:
		player.is_hurt = false
		fsm.transition_to(PlayerState.State.IDLE)


func exit() -> void:
	player.is_hurt = false


func handle_input(_event: Dictionary) -> bool:
	# 受伤期间不接受任何输入
	return true