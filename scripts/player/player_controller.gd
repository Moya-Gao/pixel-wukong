extends CharacterBody2D

# 移动参数
const SPEED = 200.0

# 跳跃参数
var is_jumping = false
var jump_height = 0.0
var jump_velocity = 0.0
const MAX_JUMP_HEIGHT = 40.0
const JUMP_GRAVITY = 600.0

# 视觉偏移（伪3D效果）
var visual_offset_x = 0.0
const MAX_VISUAL_OFFSET = 15.0

# 朝向
var facing_right = true

# 当前动画状态
var current_anim = ""

# 攻击系统
var is_attacking = false
var attack_combo = 0
var attack_timer = 0.0
var combo_window_timer = 0.0
var can_combo = false

const ATTACK_DURATION = 0.25
const COMBO_WINDOW = 0.3
const HEAVY_ATTACK_DURATION = 0.4

# 攻击系统扩展
const ATTACK_MOVE_SPEED = 80.0  # 攻击时移动速度
const COMBO_INPUT_START = 0.05  # 攻击开始多久后可以预输入（更早开始）
const COMBO_INPUT_END = 0.05  # 攻击结束前多久停止预输入（更晚结束）

# 预输入队列
var queued_attack: String = ""  # "" | "light" | "heavy"

# 连招类型
enum AttackType { LIGHT, HEAVY }
var last_attack_type: AttackType = AttackType.LIGHT

# 闪避系统
var is_dodging = false
var dodge_timer = 0.0
var dodge_direction = Vector2.RIGHT
var is_invincible = false
var dodge_cooldown_timer = 0.0

const DODGE_SPEED = 400.0
const DODGE_DURATION = 0.2
const DODGE_COOLDOWN = 0.5
const INVINCIBLE_START = 0.05
const INVINCIBLE_END = 0.15

# 格挡系统
var is_blocking = false
var perfect_block_timer = 0.0
var is_perfect_block = false

const BLOCK_SPEED = 80.0  # 格挡时移动速度大幅降低
const PERFECT_BLOCK_WINDOW = 0.15  # 完美格挡窗口

# 生命值系统
var max_health = 100
var current_health = 100
var is_hurt = false
var hurt_timer = 0.0
var knockback_velocity = Vector2.ZERO
const HURT_DURATION = 0.3
var is_dead = false  # 玩家死亡状态
const KNOCKBACK_FORCE = 150.0

# 死亡动画
var death_fade_timer: float = 0.0
const DEATH_FADE_DURATION: float = 0.5

# 节点引用
@onready var sprite_root = $SpriteRoot
@onready var animated_sprite = $SpriteRoot/AnimatedSprite2D
@onready var shadow = $Shadow
@onready var hitbox = $Hitbox
@onready var hitbox_collision = $Hitbox/CollisionShape2D
@onready var hurtbox = $Hurtbox
@onready var shield_effect = $SpriteRoot/ShieldEffect
@onready var perfect_block_glow = $SpriteRoot/ShieldEffect/PerfectBlockGlow


func _ready():
	# 添加到 player 组（用于敌人检测区域识别）
	add_to_group("player")

	# 为 Hitbox 添加组名（用于敌人识别）
	if hitbox:
		hitbox.add_to_group("player_hitbox")

	# 为 Hurtbox 添加组名（用于攻击检测）
	if hurtbox:
		hurtbox.add_to_group("player_hurtbox")
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)


func _physics_process(delta):
	# 更新受伤状态
	if is_hurt:
		hurt_timer -= delta
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 500.0 * delta)
		velocity = knockback_velocity
		if hurt_timer <= 0:
			is_hurt = false
		move_and_slide()
		_update_visual()
		_update_animation()
		return

	# 更新死亡渐变（从DEATH_FADE_DURATION渐变到0，alpha从1.0渐变到0.0）
	if is_dead:
		if death_fade_timer > 0:
			death_fade_timer -= delta
			var alpha = death_fade_timer / DEATH_FADE_DURATION
			modulate.a = alpha
			if death_fade_timer <= 0:
				_on_death_complete()
		return  # 死亡渐变期间跳过正常物理处理

	# 更新冷却和计时器
	if dodge_cooldown_timer > 0:
		dodge_cooldown_timer -= delta
	if perfect_block_timer > 0:
		perfect_block_timer -= delta
		if perfect_block_timer <= 0:
			is_perfect_block = false

	# 处理不同状态
	if is_dodging:
		_process_dodge(delta)
	elif is_blocking:
		_process_block(delta)
	elif is_attacking:
		_process_attack(delta)
	else:
		_process_movement(delta)

	# 更新跳跃物理
	if is_jumping:
		_update_jump(delta)

	move_and_slide()
	_update_visual()
	_update_animation()

func _process_movement(delta):
	"""处理移动输入"""
	var direction = Vector2.ZERO
	if Input.is_action_pressed("move_right"):
		direction.x += 1
		facing_right = true
	if Input.is_action_pressed("move_left"):
		direction.x -= 1
		facing_right = false
	if Input.is_action_pressed("move_down"):
		direction.y += 1
	if Input.is_action_pressed("move_up"):
		direction.y -= 1

	velocity = direction.normalized() * SPEED

	# 跳跃
	if Input.is_action_just_pressed("jump") and not is_jumping:
		_start_jump()

	# 格挡（按住）
	if Input.is_action_pressed("block"):
		_start_block()
		return

	# 闪避
	if Input.is_action_just_pressed("dodge") and dodge_cooldown_timer <= 0:
		_start_dodge(direction)
		return

	# 攻击输入
	if Input.is_action_just_pressed("attack_light"):
		_start_light_attack()
	elif Input.is_action_just_pressed("attack_heavy"):
		_start_heavy_attack()

	# 连击窗口计时
	if combo_window_timer > 0:
		combo_window_timer -= delta
		if combo_window_timer <= 0:
			attack_combo = 0

func _process_attack(delta):
	"""处理攻击状态"""
	attack_timer -= delta

	# 攻击期间可以缓慢移动
	var direction = Vector2.ZERO
	if Input.is_action_pressed("move_right"):
		direction.x += 1
		facing_right = true
	if Input.is_action_pressed("move_left"):
		direction.x -= 1
		facing_right = false
	if Input.is_action_pressed("move_down"):
		direction.y += 1
	if Input.is_action_pressed("move_up"):
		direction.y -= 1

	velocity = direction.normalized() * ATTACK_MOVE_SPEED

	# 攻击期间持续检测碰撞
	_check_hitbox_damage()

	# 计算是否处于可输入窗口（扩大窗口让连招更容易）
	var attack_duration = HEAVY_ATTACK_DURATION if last_attack_type == AttackType.HEAVY else ATTACK_DURATION
	var elapsed_time = attack_duration - attack_timer
	var in_input_window = elapsed_time >= COMBO_INPUT_START and attack_timer > COMBO_INPUT_END

	# 处理预输入
	if in_input_window:
		if Input.is_action_just_pressed("attack_light"):
			queued_attack = "light"
		elif Input.is_action_just_pressed("attack_heavy"):
			queued_attack = "heavy"

	# 攻击期间可以取消为格挡
	if Input.is_action_pressed("block"):
		queued_attack = ""
		_end_attack()
		_start_block()
		return

	# 攻击结束
	if attack_timer <= 0:
		# 检查是否有排队的攻击
		if queued_attack != "":
			var next_attack = queued_attack
			queued_attack = ""
			_execute_queued_attack(next_attack)
		else:
			_end_attack()

func _process_dodge(delta):
	"""处理闪避状态"""
	dodge_timer -= delta

	# 无敌帧管理
	if dodge_timer <= DODGE_DURATION - INVINCIBLE_START and dodge_timer >= DODGE_DURATION - INVINCIBLE_END:
		if not is_invincible:
			is_invincible = true
			_set_hurtbox_active(false)
	else:
		if is_invincible:
			is_invincible = false
			_set_hurtbox_active(true)

	# 闪避移动
	velocity = dodge_direction * DODGE_SPEED

	# 闪避结束
	if dodge_timer <= 0:
		_end_dodge()

func _process_block(delta):
	"""处理格挡状态"""
	# 格挡时可以缓慢移动
	var direction = Vector2.ZERO
	if Input.is_action_pressed("move_right"):
		direction.x += 1
		facing_right = true
	if Input.is_action_pressed("move_left"):
		direction.x -= 1
		facing_right = false
	if Input.is_action_pressed("move_down"):
		direction.y += 1
	if Input.is_action_pressed("move_up"):
		direction.y -= 1

	velocity = direction.normalized() * BLOCK_SPEED

	# 更新完美格挡视觉
	_update_shield_visual()

	# 松开格挡键结束格挡
	if not Input.is_action_pressed("block"):
		_end_block()
		return

	# 格挡期间可以取消为闪避
	if Input.is_action_just_pressed("dodge") and dodge_cooldown_timer <= 0:
		_end_block()
		_start_dodge(direction)
		return

func _start_block():
	"""开始格挡"""
	var was_blocking = is_blocking
	is_blocking = true

	# 只在刚按下时设置完美格挡窗口
	if not was_blocking:
		perfect_block_timer = PERFECT_BLOCK_WINDOW
		is_perfect_block = true
		# 取消当前攻击
		if is_attacking:
			_end_attack()

	# 显示护盾效果
	_show_shield_effect(true)

func _end_block():
	"""结束格挡"""
	is_blocking = false
	is_perfect_block = false
	perfect_block_timer = 0.0

	# 隐藏护盾效果
	_show_shield_effect(false)

func _show_shield_effect(show: bool):
	"""显示或隐藏护盾效果"""
	if shield_effect:
		shield_effect.visible = show

func _update_shield_visual():
	"""更新护盾视觉效果"""
	if perfect_block_glow:
		perfect_block_glow.enabled = is_perfect_block

func _start_dodge(direction: Vector2):
	"""开始闪避"""
	is_dodging = true
	dodge_timer = DODGE_DURATION
	dodge_cooldown_timer = DODGE_COOLDOWN

	# 确定闪避方向
	if direction.length() > 0.1:
		dodge_direction = direction.normalized()
	else:
		dodge_direction = Vector2.RIGHT if facing_right else Vector2.LEFT

	# 取消当前状态
	if is_attacking:
		_end_attack()
	if is_blocking:
		_end_block()

func _end_dodge():
	"""结束闪避"""
	is_dodging = false
	dodge_timer = 0
	is_invincible = false
	_set_hurtbox_active(true)
	velocity = Vector2.ZERO

func _set_hurtbox_active(active: bool):
	"""设置受伤碰撞箱是否激活"""
	if hurtbox:
		for child in hurtbox.get_children():
			if child is CollisionShape2D:
				child.disabled = not active

func _start_light_attack():
	"""开始轻攻击（从非攻击状态）"""
	attack_combo = 1
	last_attack_type = AttackType.LIGHT
	is_attacking = true
	attack_timer = ATTACK_DURATION
	can_combo = false
	queued_attack = ""

	# 不再设置 velocity = Vector2.ZERO，让 _process_attack 处理移动

	_activate_hitbox()

func _continue_light_attack():
	"""继续轻攻击连招"""
	if attack_combo < 3:
		attack_combo += 1

	last_attack_type = AttackType.LIGHT
	is_attacking = true
	attack_timer = ATTACK_DURATION
	can_combo = false
	queued_attack = ""

	_activate_hitbox()

func _start_heavy_attack():
	"""开始重攻击（从非攻击状态）"""
	attack_combo = 0  # 重攻击使用单独的动画
	last_attack_type = AttackType.HEAVY
	is_attacking = true
	attack_timer = HEAVY_ATTACK_DURATION
	can_combo = false
	queued_attack = ""

	_activate_hitbox()

func _continue_heavy_attack():
	"""重攻击接在连招后"""
	last_attack_type = AttackType.HEAVY
	is_attacking = true
	attack_timer = HEAVY_ATTACK_DURATION
	can_combo = false
	queued_attack = ""

	_activate_hitbox()

func _execute_queued_attack(attack_type: String):
	"""执行排队的攻击"""
	if attack_type == "light":
		_continue_light_attack()
	elif attack_type == "heavy":
		_continue_heavy_attack()

func _queue_next_attack():
	"""预输入下一击 - 保持向后兼容"""
	queued_attack = "light"

func _end_attack():
	"""结束攻击"""
	is_attacking = false
	attack_timer = 0
	can_combo = false
	queued_attack = ""

	if combo_window_timer <= 0:
		attack_combo = 0

	_deactivate_hitbox()

# 攻击伤害标记（防止重复造成伤害）
var _has_dealt_damage = false

func _activate_hitbox():
	"""激活攻击碰撞箱"""
	# 根据朝向更新 Hitbox 位置
	if hitbox_collision:
		var offset_x = 8.0 if facing_right else -8.0
		hitbox_collision.position.x = offset_x
		hitbox_collision.disabled = false
	_has_dealt_damage = false  # 重置伤害标记

func _check_hitbox_damage():
	"""检查 Hitbox 并对敌人造成伤害"""
	if _has_dealt_damage:
		return  # 本次攻击已经造成过伤害

	if not hitbox:
		return

	var overlapping = hitbox.get_overlapping_areas()
	for area in overlapping:
		# 排除自己的 Hurtbox
		if area != hurtbox and area.is_in_group("enemy_hurtbox"):
			var enemy = area.get_parent()
			if enemy and enemy.has_method("take_damage"):
				var knockback_dir = enemy.global_position.direction_to(global_position) * -1
				enemy.take_damage(get_current_attack_damage(), knockback_dir)
				_has_dealt_damage = true  # 标记已造成伤害
				break  # 只对一个敌人造成伤害

func _deactivate_hitbox():
	"""禁用攻击碰撞箱"""
	if hitbox_collision:
		hitbox_collision.disabled = true

func _start_jump():
	is_jumping = true
	jump_height = 0.0
	jump_velocity = sqrt(2 * JUMP_GRAVITY * MAX_JUMP_HEIGHT)

func _update_jump(delta):
	jump_velocity -= JUMP_GRAVITY * delta
	jump_height += jump_velocity * delta

	if jump_height <= 0.0:
		jump_height = 0.0
		jump_velocity = 0.0
		is_jumping = false

func _update_visual():
	if is_jumping:
		var height_ratio = jump_height / MAX_JUMP_HEIGHT
		visual_offset_x = MAX_VISUAL_OFFSET * height_ratio
	else:
		visual_offset_x = 0.0

	if sprite_root:
		var offset_direction = 1 if facing_right else -1
		sprite_root.position.x = visual_offset_x * offset_direction
		sprite_root.position.y = -jump_height
		sprite_root.scale.x = 1 if facing_right else -1

	if shadow:
		shadow.position.x = 0
		if is_jumping:
			var alpha = 0.3 - (jump_height / MAX_JUMP_HEIGHT) * 0.2
			shadow.modulate.a = alpha
		else:
			shadow.modulate.a = 0.3

func _update_animation():
	"""根据玩家状态更新动画"""
	if not animated_sprite:
		return

	var new_anim = ""

	# 状态优先级：受伤 > 闪避 > 格挡 > 攻击 > 跳跃 > 移动 > 站立
	if is_hurt:
		new_anim = "hurt"
	elif is_dodging:
		new_anim = "dodge"
	elif is_blocking:
		new_anim = "block"
	elif is_attacking:
		if last_attack_type == AttackType.HEAVY:
			new_anim = "attack_heavy"
		else:
			new_anim = "attack_light_%d" % attack_combo
	elif is_jumping:
		if jump_velocity > 0:
			new_anim = "jump_rise"
		else:
			new_anim = "jump_fall"
	elif velocity.length() > 10:
		new_anim = "run"
	else:
		new_anim = "idle"

	if new_anim != current_anim:
		current_anim = new_anim
		animated_sprite.play(new_anim)

	# 移除 await 逻辑，can_combo 现在由 _process_attack 控制

# ========== 公共接口（供其他系统调用） ==========

func can_take_damage() -> bool:
	"""检查是否可以受到伤害"""
	if is_dodging and is_invincible:
		return false
	return true

func is_perfect_blocking() -> bool:
	"""检查是否处于完美格挡状态"""
	return is_blocking and is_perfect_block

func get_block_state() -> Dictionary:
	"""获取格挡状态信息"""
	return {
		"is_blocking": is_blocking,
		"is_perfect": is_perfect_block,
		"perfect_timer": perfect_block_timer
	}

func get_current_attack_damage() -> int:
	"""获取当前攻击伤害"""
	if last_attack_type == AttackType.HEAVY:
		return 25  # 重攻击伤害
	return 10 + (attack_combo - 1) * 5  # 轻攻击连击递增

func _die() -> void:
	"""玩家死亡"""
	is_dead = true
	print("💀 玩家死亡!")

	# 取消所有状态
	if is_attacking:
		_end_attack()
	if is_blocking:
		_end_block()
	if is_dodging:
		_end_dodge()

	# 禁用碰撞（死亡后不再阻挡敌人）
	collision_layer = 0
	collision_mask = 0

	# 播放死亡动画（如果有）
	if animated_sprite and animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("death"):
		animated_sprite.play("death")
		await get_tree().create_timer(0.3).timeout
	else:
		await get_tree().create_timer(0.3).timeout

	# 开始淡出
	death_fade_timer = DEATH_FADE_DURATION

func _on_death_complete() -> void:
	"""死亡动画完成后"""
	visible = false
	# 显示 Game Over UI
	var game_over = preload("res://scenes/ui/game_over.tscn").instantiate()
	get_tree().root.add_child(game_over)

func take_damage(damage: int, knockback_dir: Vector2) -> void:
	"""受到伤害"""
	if is_hurt or is_dead:
		return

	current_health = maxi(current_health - damage, 0)
	is_hurt = true
	hurt_timer = HURT_DURATION
	knockback_velocity = knockback_dir * KNOCKBACK_FORCE

	# 取消当前状态
	if is_attacking:
		_end_attack()
	if is_blocking:
		_end_block()

	# 检查是否死亡
	if current_health <= 0:
		_die()

func _on_hurtbox_area_entered(area: Area2D) -> void:
	"""Hurtbox 接收到攻击"""
	if area.is_in_group("enemy_hitbox"):
		if not can_take_damage():
			return

		var enemy = area.get_parent()
		var damage = 10
		if "stats" in enemy and enemy.stats:
			damage = enemy.stats.attack_damage

		var knockback_dir = global_position.direction_to(enemy.global_position) * -1

		# 检查格挡
		if is_perfect_blocking():
			# 完美格挡：不受伤，敌人眩晕
			if enemy.has_method("apply_stun"):
				enemy.apply_stun(0.5)
			return
		elif is_blocking:
			# 普通格挡：伤害减半
			damage = damage / 2

		take_damage(damage, knockback_dir)
