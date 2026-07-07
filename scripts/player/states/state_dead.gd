## 玩家状态：Dead（死亡）
## 行为：播放死亡动画 + 渐变消失 + 显示 Game Over UI
## 终态，不可转换

extends "res://scripts/player/states/state_base.gd"


func enter(_data: Dictionary = {}) -> void:
	player.is_dead = true
	player.is_hurt = false  # 清除受伤状态，确保死亡逻辑能执行
	player.hurt_timer = 0

	# 取消所有状态
	if player.is_attacking:
		player._end_attack()
	if player.is_blocking:
		player._end_block()
	if player.is_dodging:
		player._end_dodge()

	# 禁用碰撞
	player.collision_layer = 0
	player.collision_mask = 0

	# 播放死亡动画
	if player.animated_sprite and player.animated_sprite.sprite_frames != null:
		if player.animated_sprite.sprite_frames.has_animation("death"):
			player.animated_sprite.play("death")

	# 延迟开始淡出（确保 death 动画先播放一帧）
	player.call_deferred("_start_death_fade")


func process(delta: float) -> void:
	if player.death_fade_timer > 0 and not player.death_fade_complete:
		player.death_fade_timer -= delta
		if player.death_fade_timer <= 0:
			player.death_fade_timer = 0
			player.death_fade_complete = true
			player.modulate.a = 0
			player._on_death_complete()
		else:
			player.modulate.a = player.death_fade_timer / player.DEATH_FADE_DURATION


func handle_input(_event: Dictionary) -> bool:
	# 死亡期间不接受任何输入
	return true