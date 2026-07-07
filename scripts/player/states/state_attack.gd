## 玩家状态：Attack（轻攻击 + 重攻击）
## 合并 ATTACK_LIGHT 和 ATTACK_HEAVY，内部跟踪 combo + 预输入队列
## 支持取消为格挡/闪避（cancel window），支持连招（预输入）

extends "res://scripts/player/states/state_base.gd"


func enter(data: Dictionary = {}) -> void:
	# 根据当前进入的状态决定是轻还是重
	var is_heavy: bool = fsm.current_state == PlayerState.State.ATTACK_HEAVY

	if is_heavy:
		# 重攻击：从非攻击状态进入 OR 连招接重击
		if data.has("combo"):
			player.attack_combo = 0
		player.last_attack_type = player.AttackType.HEAVY
		player.attack_timer = player.HEAVY_ATTACK_DURATION
	else:
		# 轻攻击：每次进入递增 combo（包括连招续击）
		if player.attack_combo < 3:
			player.attack_combo += 1
		player.last_attack_type = player.AttackType.LIGHT
		player.attack_timer = player.ATTACK_DURATION

	player.is_attacking = true
	player.queued_attack = ""
	player._activate_hitbox()


func process(delta: float) -> void:
	player.attack_timer -= delta

	# 攻击期间可以缓慢移动
	var direction: Vector2 = player._read_movement_direction()
	if direction.length() > 0.01:
		if direction.x != 0:
			player.facing_right = direction.x > 0
	player.velocity = direction.normalized() * player.ATTACK_MOVE_SPEED

	# 攻击期间持续检测碰撞
	player._check_hitbox_damage()

	# 计算 cancel window 和 input window
	var attack_duration: float = player.HEAVY_ATTACK_DURATION if player.last_attack_type == player.AttackType.HEAVY else player.ATTACK_DURATION
	var elapsed: float = attack_duration - player.attack_timer
	var in_input_window: bool = elapsed >= player.COMBO_INPUT_START and player.attack_timer > player.COMBO_INPUT_END

	# 连击窗口计时
	if player.combo_window_timer > 0:
		player.combo_window_timer -= delta
		if player.combo_window_timer <= 0:
			player.attack_combo = 0

	# 预输入处理（攻击期间）
	if in_input_window:
		if player._wants_light_attack():
			player.queued_attack = "light"
		elif player._wants_heavy_attack():
			player.queued_attack = "heavy"

	# 攻击期间可以取消为格挡
	if player._wants_block():
		player.queued_attack = ""
		player._end_attack()
		fsm.transition_to(PlayerState.State.BLOCK)
		return

	# 攻击期间可以取消为闪避（轻攻击 cancel window 较宽，重攻击较窄）
	var can_cancel_to_dodge: bool = false
	if player.last_attack_type == player.AttackType.LIGHT:
		can_cancel_to_dodge = elapsed >= 0.05 and player.attack_timer > 0.05
	elif player.last_attack_type == player.AttackType.HEAVY:
		can_cancel_to_dodge = elapsed >= 0.10 and player.attack_timer > 0.08

	if can_cancel_to_dodge and player._wants_dodge():
		player._end_attack()
		fsm.transition_to(PlayerState.State.DODGE, {"direction": direction})
		return

	# 攻击结束
	if player.attack_timer <= 0:
		if player.queued_attack != "":
			var next_attack: String = player.queued_attack
			player.queued_attack = ""
			_execute_queued_attack(next_attack)
		else:
			player._end_attack()
			fsm.transition_to(PlayerState.State.IDLE)


func exit() -> void:
	player._end_attack()


func handle_input(_event: Dictionary) -> bool:
	return true


func _execute_queued_attack(attack_type: String) -> void:
	player.combo_window_timer = player.COMBO_WINDOW
	if attack_type == "light":
		fsm.transition_to(PlayerState.State.ATTACK_LIGHT, {"combo": player.attack_combo})
	elif attack_type == "heavy":
		fsm.transition_to(PlayerState.State.ATTACK_HEAVY, {"combo": player.attack_combo})