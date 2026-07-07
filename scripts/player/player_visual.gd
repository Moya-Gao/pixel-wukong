## 玩家视觉更新
## 从 player_controller 抽出的 _update_visual 和 _update_animation 逻辑
## 包括：SpriteRoot 位置/缩放（朝向 + 跳跃视觉偏移）、阴影 alpha、动画状态选择

extends Node
class_name PlayerVisual

var player: CharacterBody2D


## 更新视觉偏移（SprintRoot 位置 + 缩放 + 阴影 alpha）
func update_visual() -> void:
	var is_jumping := player.fsm.current_state == PlayerState.State.JUMP_RISE \
		or player.fsm.current_state == PlayerState.State.JUMP_FALL

	# 跳跃视觉偏移（伪3D 效果）
	if is_jumping and player.MAX_JUMP_HEIGHT > 0:
		var height_ratio: float = player.jump_height / player.MAX_JUMP_HEIGHT
		player.visual_offset_x = player.MAX_VISUAL_OFFSET * height_ratio
	else:
		player.visual_offset_x = 0.0

	# SpriteRoot 位置和缩放
	if player.sprite_root:
		var offset_dir := 1 if player.facing_right else -1
		player.sprite_root.position.x = player.visual_offset_x * offset_dir
		player.sprite_root.position.y = -player.jump_height
		player.sprite_root.scale.x = 1 if player.facing_right else -1

	# 阴影透明度（跳跃越高越淡）
	if player.shadow:
		player.shadow.position.x = 0
		if is_jumping and player.MAX_JUMP_HEIGHT > 0:
			var alpha: float = 0.3 - (player.jump_height / player.MAX_JUMP_HEIGHT) * 0.2
			player.shadow.modulate.a = alpha
		else:
			player.shadow.modulate.a = 0.3


## 更新动画状态（按状态优先级选择动画）
func update_animation() -> void:
	if not player.animated_sprite:
		return

	var new_anim := ""
	var state := player.fsm.current_state

	# 状态优先级：受伤 > 闪避 > 格挡 > 攻击 > 跳跃 > 移动 > 站立
	if player.is_hurt:
		new_anim = "hurt"
	elif player.is_dodging:
		new_anim = "dodge"
	elif player.is_blocking:
		new_anim = "block"
	elif player.is_attacking:
		if player.last_attack_type == player.AttackType.HEAVY:
			new_anim = "attack_heavy"
		else:
			new_anim = "attack_light_%d" % player.attack_combo
	elif state == PlayerState.State.JUMP_RISE or state == PlayerState.State.JUMP_FALL:
		new_anim = "jump_rise" if player.jump_velocity > 0 else "jump_fall"
	elif player.velocity.length() > 10:
		new_anim = "run"
	else:
		new_anim = "idle"

	if new_anim != player.current_anim:
		player.current_anim = new_anim
		player.animated_sprite.play(new_anim)