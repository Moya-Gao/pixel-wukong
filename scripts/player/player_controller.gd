## 玩家控制器
## 伪3D/等距视角 - 8方向移动 + 跳跃系统

extends CharacterBody2D
class_name Player

# 信号
signal health_changed(current: int, maximum: int)
signal stamina_changed(current: float, maximum: float)
signal state_changed(new_state: int)
signal transformation_changed(transformation_id: String)

# 节点引用
@onready var sprite: Node2D = $SpriteRoot
@onready var shadow: Node2D = $Shadow
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var hitbox: Area2D = $Hitbox
@onready var hurtbox: Area2D = $Hurtbox
@onready var stats: PlayerStats = PlayerStats.new()

# 状态机
var current_state: PlayerState.State = PlayerState.State.IDLE
var previous_state: PlayerState.State = PlayerState.State.IDLE

# 移动变量
var move_direction: Vector2 = Vector2.ZERO  # 8方向移动
var facing_direction: Vector2 = Vector2.DOWN  # 面朝方向

# 跳跃变量 (伪3D高度模拟)
var is_jumping: bool = false
var jump_height: float = 0.0  # 当前高度
var jump_velocity: float = 0.0  # 垂直速度
var max_jump_height: float = 40.0
var jump_speed: float = 200.0
var gravity: float = 400.0

# 战斗变量
var combo_count: int = 0
var combo_timer: float = 0.0
var is_attacking: bool = false
var can_combo: bool = false

# 闪避变量
var dodge_timer: float = 0.0
var dodge_direction: Vector2 = Vector2.ZERO
var is_invincible: bool = false

# 格挡变量
var is_blocking: bool = false
var perfect_block_timer: float = 0.0

# 变身变量
var available_transformations: Dictionary = {}

func _ready() -> void:
	health_changed.emit(stats.current_health, stats.max_health)
	stamina_changed.emit(stats.current_stamina, stats.max_stamina)

func _physics_process(delta: float) -> void:
	# 处理各种状态
	match current_state:
		PlayerState.State.IDLE:
			_process_idle_state(delta)
		PlayerState.State.RUN:
			_process_run_state(delta)
		PlayerState.State.JUMP:
			_process_jump_state(delta)
		PlayerState.State.FALL:
			_process_fall_state(delta)
		PlayerState.State.ATTACK_LIGHT:
			_process_attack_light_state(delta)
		PlayerState.State.ATTACK_HEAVY:
			_process_attack_heavy_state(delta)
		PlayerState.State.DODGE:
			_process_dodge_state(delta)
		PlayerState.State.BLOCK:
			_process_block_state(delta)
		PlayerState.State.HURT:
			_process_hurt_state(delta)
		PlayerState.State.TRANSFORM:
			_process_transform_state(delta)

	# 更新跳跃物理
	_update_jump_physics(delta)

	# 更新连招计时器
	if combo_timer > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			combo_count = 0

	# 恢复耐力
	if not is_attacking and not is_blocking:
		stats.recover_stamina(20.0 * delta)
		stamina_changed.emit(stats.current_stamina, stats.max_stamina)

	# 移动
	move_and_slide()

	# 更新视觉位置（跳跃高度偏移）
	_update_visual_position()

#region 状态处理

func _process_idle_state(_delta: float) -> void:
	# 停止移动
	velocity = Vector2.ZERO

	# 检测移动输入
	var input = _get_movement_input()
	if input != Vector2.ZERO:
		_change_state(PlayerState.State.RUN)
		return

	# 检测跳跃
	if Input.is_action_just_pressed("jump"):
		_start_jump()
		return

	# 检测攻击
	if Input.is_action_just_pressed("attack_light"):
		_start_light_attack()
		return
	if Input.is_action_just_pressed("attack_heavy"):
		_start_heavy_attack()
		return

	# 检测闪避
	if Input.is_action_just_pressed("dodge"):
		_start_dodge()
		return

	# 检测格挡
	if Input.is_action_pressed("block"):
		_change_state(PlayerState.State.BLOCK)
		return

func _process_run_state(_delta: float) -> void:
	# 获取移动输入
	var input = _get_movement_input()

	if input == Vector2.ZERO:
		_change_state(PlayerState.State.IDLE)
		return

	# 更新方向和速度
	move_direction = input
	facing_direction = input
	velocity = input * stats.move_speed

	# 更新朝向动画
	_update_facing_animation()

	# 检测跳跃
	if Input.is_action_just_pressed("jump"):
		_start_jump()
		return

	# 检测攻击
	if Input.is_action_just_pressed("attack_light"):
		_start_light_attack()
		return
	if Input.is_action_just_pressed("attack_heavy"):
		_start_heavy_attack()
		return

	# 检测闪避
	if Input.is_action_just_pressed("dodge"):
		_start_dodge()
		return

	# 检测格挡
	if Input.is_action_pressed("block"):
		velocity = Vector2.ZERO
		_change_state(PlayerState.State.BLOCK)
		return

func _process_jump_state(delta: float) -> void:
	# 空中移动控制
	var input = _get_movement_input()
	if input != Vector2.ZERO:
		velocity = input * stats.move_speed * 0.7
		facing_direction = input
		_update_facing_animation()
	else:
		velocity = velocity.move_toward(Vector2.ZERO, stats.move_speed * delta)

	# 检测跳跃攻击
	if Input.is_action_just_pressed("attack_light"):
		_start_light_attack()  # 空中攻击
		return
	if Input.is_action_just_pressed("attack_heavy"):
		_start_heavy_attack()  # 空中重攻击
		return

func _process_fall_state(delta: float) -> void:
	# 与跳跃状态相同
	_process_jump_state(delta)

func _process_attack_light_state(delta: float) -> void:
	# 攻击时减缓移动
	velocity = velocity.move_toward(Vector2.ZERO, stats.move_speed * delta * 2)

	# 连招检测
	if can_combo and Input.is_action_just_pressed("attack_light"):
		combo_count = (combo_count + 1) % 3
		can_combo = false
		combo_timer = stats.combo_window
		_play_attack_animation()

	# 重攻击取消
	if can_combo and Input.is_action_just_pressed("attack_heavy"):
		_change_state(PlayerState.State.ATTACK_HEAVY)
		return

func _process_attack_heavy_state(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, stats.move_speed * delta * 2)

func _process_dodge_state(delta: float) -> void:
	dodge_timer -= delta

	# 无敌帧检测
	if dodge_timer > stats.dodge_duration - stats.dodge_invincibility:
		is_invincible = true
	else:
		is_invincible = false

	# 闪避移动（8方向）
	velocity = dodge_direction * stats.move_speed * 2

	if dodge_timer <= 0:
		is_invincible = false
		velocity = Vector2.ZERO
		_change_state(PlayerState.State.IDLE)

func _process_block_state(_delta: float) -> void:
	velocity = Vector2.ZERO

	# 完美格挡窗口
	if perfect_block_timer > 0:
		perfect_block_timer -= _delta

	# 可以在格挡时缓慢移动
	var input = _get_movement_input()
	if input != Vector2.ZERO:
		velocity = input * stats.move_speed * 0.2

	if not Input.is_action_pressed("block"):
		_change_state(PlayerState.State.IDLE)

func _process_hurt_state(_delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, stats.move_speed * 0.5)

func _process_transform_state(_delta: float) -> void:
	velocity = Vector2.ZERO

#endregion

#region 跳跃系统

func _start_jump() -> void:
	if is_jumping:
		return

	is_jumping = true
	jump_velocity = -sqrt(2 * gravity * max_jump_height)  # 计算初速度
	_change_state(PlayerState.State.JUMP)

func _update_jump_physics(delta: float) -> void:
	if not is_jumping:
		return

	# 应用重力
	jump_velocity += gravity * delta
	jump_height += jump_velocity * delta

	# 到达最高点
	if jump_velocity > 0 and current_state == PlayerState.State.JUMP:
		_change_state(PlayerState.State.FALL)

	# 落地
	if jump_height >= 0 and jump_velocity > 0:
		jump_height = 0.0
		jump_velocity = 0.0
		is_jumping = false

		# 根据输入决定落地状态
		var input = _get_movement_input()
		if input != Vector2.ZERO:
			_change_state(PlayerState.State.RUN)
		else:
			_change_state(PlayerState.State.IDLE)

func _update_visual_position() -> void:
	# 更新精灵位置（跳跃高度偏移）
	if sprite:
		sprite.position.y = -jump_height
	# 阴影保持在地面
	if shadow:
		shadow.modulate.a = 1.0 - (jump_height / max_jump_height) * 0.5

#endregion

#region 输入处理

func _get_movement_input() -> Vector2:
	var input = Vector2.ZERO
	input.x = Input.get_axis("move_left", "move_right")
	input.y = Input.get_axis("move_up", "move_down")
	return input.normalized()

func _update_facing_animation() -> void:
	# 根据朝向决定动画
	# 这里可以添加8方向动画支持
	if facing_direction.x < 0:
		sprite.scale.x = -1  # 水平翻转
	elif facing_direction.x > 0:
		sprite.scale.x = 1

#endregion

#region 动作触发

func _start_light_attack() -> void:
	is_attacking = true
	combo_timer = stats.combo_window
	_change_state(PlayerState.State.ATTACK_LIGHT)
	_play_attack_animation()

func _start_heavy_attack() -> void:
	is_attacking = true
	_change_state(PlayerState.State.ATTACK_HEAVY)
	_play_attack_animation()

func _start_dodge() -> void:
	dodge_timer = stats.dodge_duration
	# 闪避方向：当前移动方向或面朝方向
	var input = _get_movement_input()
	if input != Vector2.ZERO:
		dodge_direction = input
	else:
		dodge_direction = facing_direction
	_change_state(PlayerState.State.DODGE)

func _play_attack_animation() -> void:
	# 根据连招数播放不同动画
	# TODO: 添加动画支持
	pass

#endregion

#region 信号回调

func _on_animated_sprite_2d_animation_finished() -> void:
	match current_state:
		PlayerState.State.ATTACK_LIGHT, PlayerState.State.ATTACK_HEAVY:
			is_attacking = false
			combo_count = 0
			# 如果还在跳跃中，保持跳跃状态
			if is_jumping:
				_change_state(PlayerState.State.JUMP)
			else:
				_change_state(PlayerState.State.IDLE)
		PlayerState.State.HURT:
			_change_state(PlayerState.State.IDLE)
		PlayerState.State.TRANSFORM:
			_change_state(PlayerState.State.IDLE)

#endregion

#region 公共方法

func take_damage(amount: int, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if is_invincible:
		return

	if current_state == PlayerState.State.BLOCK:
		if perfect_block_timer > 0:
			perfect_block_timer = 0
			_perfect_block()
			return
		else:
			amount = int(amount * 0.3)

	stats.take_damage(amount)
	health_changed.emit(stats.current_health, stats.max_health)

	if stats.current_health <= 0:
		die()
	else:
		velocity = knockback_dir * 200
		_change_state(PlayerState.State.HURT)

func die() -> void:
	print("玩家死亡")

func transform_to(transformation_id: String) -> void:
	if stats.has_transformation(transformation_id):
		stats.set_transformation(transformation_id)
		_change_state(PlayerState.State.TRANSFORM)
		transformation_changed.emit(transformation_id)

func revert_transformation() -> void:
	stats.set_transformation("")
	_change_state(PlayerState.State.TRANSFORM)
	transformation_changed.emit("")

func get_ground_position() -> Vector2:
	# 返回地面位置（用于碰撞检测等）
	return position

#endregion

#region 私有方法

func _change_state(new_state: PlayerState.State) -> void:
	previous_state = current_state
	current_state = new_state
	state_changed.emit(new_state)
	_update_animation()

func _update_animation() -> void:
	# TODO: 添加动画支持
	pass

func _perfect_block() -> void:
	print("完美格挡!")

#endregion
