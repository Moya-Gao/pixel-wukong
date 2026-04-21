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

# 节点引用
@onready var sprite_root = $SpriteRoot
@onready var animated_sprite = $SpriteRoot/AnimatedSprite2D
@onready var shadow = $Shadow
@onready var hitbox = $Hitbox
@onready var hitbox_collision = $Hitbox/CollisionShape2D
@onready var hurtbox = $Hurtbox
@onready var shield_effect = $SpriteRoot/ShieldEffect
@onready var perfect_block_glow = $SpriteRoot/ShieldEffect/PerfectBlockGlow

func _physics_process(delta):
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

	# 攻击期间可以输入下一击或格挡
	if can_combo and Input.is_action_just_pressed("attack_light"):
		_queue_next_attack()

	# 攻击期间可以取消为格挡
	if Input.is_action_pressed("block"):
		_end_attack()
		_start_block()
		return

	# 攻击结束
	if attack_timer <= 0:
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
	"""开始轻攻击"""
	if attack_combo == 0:
		attack_combo = 1
	else:
		attack_combo = min(attack_combo + 1, 3)

	is_attacking = true
	attack_timer = ATTACK_DURATION
	can_combo = false
	velocity = Vector2.ZERO

	_activate_hitbox()

func _start_heavy_attack():
	"""开始重攻击"""
	is_attacking = true
	attack_combo = 0
	attack_timer = HEAVY_ATTACK_DURATION
	can_combo = false
	velocity = Vector2.ZERO

	_activate_hitbox()

func _queue_next_attack():
	"""预输入下一击"""
	if attack_combo < 3:
		combo_window_timer = COMBO_WINDOW

func _end_attack():
	"""结束攻击"""
	is_attacking = false
	attack_timer = 0
	can_combo = false

	if combo_window_timer <= 0:
		attack_combo = 0

	_deactivate_hitbox()

func _activate_hitbox():
	"""激活攻击碰撞箱"""
	if hitbox_collision:
		hitbox_collision.disabled = false

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

	# 状态优先级：闪避 > 格挡 > 攻击 > 跳跃 > 移动 > 站立
	if is_dodging:
		new_anim = "dodge"
	elif is_blocking:
		new_anim = "block"
	elif is_attacking:
		if attack_combo == 0:
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

		# 攻击动画播放到一半时允许输入下一击
		if new_anim.begins_with("attack"):
			await get_tree().create_timer(ATTACK_DURATION * 0.5).timeout
			can_combo = true

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
