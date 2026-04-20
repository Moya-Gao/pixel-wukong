extends CharacterBody2D

const SPEED = 200.0

# 跳跃参数
var is_jumping = false
var jump_height = 0.0
var jump_velocity = 0.0
const MAX_JUMP_HEIGHT = 40.0
const JUMP_GRAVITY = 600.0

# 视觉偏移（伪3D效果）
var visual_offset_x = 0.0  # 跳跃时的视觉水平偏移
const MAX_VISUAL_OFFSET = 15.0  # 最大视觉偏移量

# 朝向
var facing_right = true

# 节点引用
@onready var sprite_root = $SpriteRoot
@onready var shadow = $Shadow

func _physics_process(delta):
	# 移动输入
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

	# 更新跳跃物理
	if is_jumping:
		_update_jump(delta)

	move_and_slide()
	_update_visual()

func _start_jump():
	is_jumping = true
	jump_height = 0.0
	jump_velocity = sqrt(2 * JUMP_GRAVITY * MAX_JUMP_HEIGHT)

func _update_jump(delta):
	# 高度变化
	jump_velocity -= JUMP_GRAVITY * delta
	jump_height += jump_velocity * delta

	# 落地检测
	if jump_height <= 0.0:
		jump_height = 0.0
		jump_velocity = 0.0
		is_jumping = false

func _update_visual():
	# 计算跳跃时的视觉偏移（往朝向方向偏移）
	if is_jumping:
		# 视觉偏移随高度变化：上升时增加，下降时减少
		var height_ratio = jump_height / MAX_JUMP_HEIGHT
		visual_offset_x = MAX_VISUAL_OFFSET * height_ratio
	else:
		visual_offset_x = 0.0

	# 应用视觉偏移（只有精灵偏移，实际位置不变）
	if sprite_root:
		# 根据朝向决定偏移方向
		var offset_direction = 1 if facing_right else -1
		sprite_root.position.x = visual_offset_x * offset_direction
		sprite_root.position.y = -jump_height

		# 根据朝向翻转精灵
		sprite_root.scale.x = 1 if facing_right else -1

	# 阴影保持在原地（不偏移）
	if shadow:
		shadow.position.x = 0
		if is_jumping:
			var alpha = 0.3 - (jump_height / MAX_JUMP_HEIGHT) * 0.2
			shadow.modulate.a = alpha
		else:
			shadow.modulate.a = 0.3
