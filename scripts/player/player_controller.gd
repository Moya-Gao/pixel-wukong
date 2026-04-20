## 玩家控制器
## 管理玩家的移动、战斗和状态

extends CharacterBody2D
class_name Player

# 信号
signal health_changed(current: int, maximum: int)
signal stamina_changed(current: float, maximum: float)
signal state_changed(new_state: int)
signal transformation_changed(transformation_id: String)

# 节点引用
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var hitbox: Area2D = $Hitbox
@onready var hurtbox: Area2D = $Hurtbox
@onready var stats: PlayerStats = PlayerStats.new()

# 状态机
var current_state: PlayerState.State = PlayerState.State.IDLE
var previous_state: PlayerState.State = PlayerState.State.IDLE

# 移动变量
var direction: float = 1.0  # 1 = 右, -1 = 左
var was_on_floor: bool = false

# 战斗变量
var combo_count: int = 0
var combo_timer: float = 0.0
var is_attacking: bool = false
var can_combo: bool = false

# 闪避变量
var dodge_timer: float = 0.0
var dodge_direction: float = 1.0
var is_invincible: bool = false

# 格挡变量
var is_blocking: bool = false
var perfect_block_timer: float = 0.0

# 变身变量
var available_transformations: Dictionary = {}

func _ready() -> void:
	# 初始化
	health_changed.emit(stats.current_health, stats.max_health)
	stamina_changed.emit(stats.current_stamina, stats.max_stamina)

	# 设置初始位置
	position = Vector2(240, 200)

func _physics_process(delta: float) -> void:
	# 应用重力
	if not is_on_floor():
		velocity.y += stats.gravity * delta

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

	# 检测落地
	if is_on_floor() and not was_on_floor:
		_on_landed()
	was_on_floor = is_on_floor()

#region 状态处理

func _process_idle_state(_delta: float) -> void:
	# 检测移动输入
	var input_dir = Input.get_axis("move_left", "move_right")
	if input_dir != 0:
		_change_state(PlayerState.State.RUN)
		return

	# 检测跳跃
	if Input.is_action_just_pressed("jump") and is_on_floor():
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
	# 处理移动
	var input_dir = Input.get_axis("move_left", "move_right")
	if input_dir == 0:
		_change_state(PlayerState.State.IDLE)
		return

	# 更新方向和速度
	direction = sign(input_dir)
	velocity.x = input_dir * stats.move_speed
	sprite.flip_h = direction < 0

	# 检测跳跃
	if Input.is_action_just_pressed("jump") and is_on_floor():
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
		velocity.x = 0
		_change_state(PlayerState.State.BLOCK)
		return

func _process_jump_state(delta: float) -> void:
	# 空中控制
	var input_dir = Input.get_axis("move_left", "move_right")
	velocity.x = input_dir * stats.move_speed * 0.8

	if input_dir != 0:
		direction = sign(input_dir)
		sprite.flip_h = direction < 0

	# 下落
	if velocity.y > 0:
		_change_state(PlayerState.State.FALL)
		return

func _process_fall_state(delta: float) -> void:
	# 空中控制
	var input_dir = Input.get_axis("move_left", "move_right")
	velocity.x = input_dir * stats.move_speed * 0.8

	if input_dir != 0:
		direction = sign(input_dir)
		sprite.flip_h = direction < 0

	# 落地
	if is_on_floor():
		_change_state(PlayerState.State.IDLE)

func _process_attack_light_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, stats.move_speed * delta * 2)

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
	velocity.x = move_toward(velocity.x, 0, stats.move_speed * delta * 2)

func _process_dodge_state(delta: float) -> void:
	dodge_timer -= delta

	# 无敌帧检测
	if dodge_timer > stats.dodge_duration - stats.dodge_invincibility:
		is_invincible = true
	else:
		is_invincible = false

	# 闪避移动
	velocity.x = dodge_direction * stats.move_speed * 2

	if dodge_timer <= 0:
		is_invincible = false
		velocity.x = 0
		_change_state(PlayerState.State.IDLE)

func _process_block_state(_delta: float) -> void:
	velocity.x = 0

	# 完美格挡窗口
	if perfect_block_timer > 0:
		perfect_block_timer -= _delta

	if not Input.is_action_pressed("block"):
		_change_state(PlayerState.State.IDLE)

func _process_hurt_state(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, stats.move_speed * 0.5)

func _process_transform_state(_delta: float) -> void:
	velocity.x = 0

#endregion

#region 动作触发

func _start_jump() -> void:
	velocity.y = -stats.jump_force
	_change_state(PlayerState.State.JUMP)

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
	dodge_direction = direction
	_change_state(PlayerState.State.DODGE)

func _play_attack_animation() -> void:
	# 根据连招数播放不同动画
	match current_state:
		PlayerState.State.ATTACK_LIGHT:
			match combo_count:
				0: sprite.play("attack_light_1")
				1: sprite.play("attack_light_2")
				2: sprite.play("attack_light_3")
		PlayerState.State.ATTACK_HEAVY:
			sprite.play("attack_heavy")

#endregion

#region 信号回调

func _on_animated_sprite_2d_animation_finished() -> void:
	match current_state:
		PlayerState.State.ATTACK_LIGHT, PlayerState.State.ATTACK_HEAVY:
			is_attacking = false
			combo_count = 0
			_change_state(PlayerState.State.IDLE)
		PlayerState.State.HURT:
			_change_state(PlayerState.State.IDLE)
		PlayerState.State.TRANSFORM:
			_change_state(PlayerState.State.IDLE)

func _on_landed() -> void:
	if current_state in [PlayerState.State.JUMP, PlayerState.State.FALL]:
		_change_state(PlayerState.State.IDLE)

#endregion

#region 公共方法

func take_damage(amount: int, knockback_direction: float = 0) -> void:
	# 无敌帧检测
	if is_invincible:
		return

	# 格挡检测
	if current_state == PlayerState.State.BLOCK:
		if perfect_block_timer > 0:
			# 完美格挡
			perfect_block_timer = 0
			_perfect_block()
			return
		else:
			# 普通格挡，减少伤害
			amount = int(amount * 0.3)

	stats.take_damage(amount)
	health_changed.emit(stats.current_health, stats.max_health)

	if stats.current_health <= 0:
		die()
	else:
		# 击退
		velocity.x = knockback_direction * 200
		velocity.y = -100
		_change_state(PlayerState.State.HURT)

func die() -> void:
	# 死亡处理
	print("玩家死亡")
	# TODO: 实现死亡动画和重生

func transform_to(transformation_id: String) -> void:
	if stats.has_transformation(transformation_id):
		stats.set_transformation(transformation_id)
		_change_state(PlayerState.State.TRANSFORM)
		transformation_changed.emit(transformation_id)

func revert_transformation() -> void:
	stats.set_transformation("")
	_change_state(PlayerState.State.TRANSFORM)
	transformation_changed.emit("")

#endregion

#region 私有方法

func _change_state(new_state: PlayerState.State) -> void:
	previous_state = current_state
	current_state = new_state
	state_changed.emit(new_state)

	# 更新动画
	_update_animation()

func _update_animation() -> void:
	match current_state:
		PlayerState.State.IDLE:
			sprite.play("idle")
		PlayerState.State.RUN:
			sprite.play("run")
		PlayerState.State.JUMP:
			sprite.play("jump")
		PlayerState.State.FALL:
			sprite.play("fall")
		PlayerState.State.DODGE:
			sprite.play("dodge")
		PlayerState.State.BLOCK:
			sprite.play("block")
			perfect_block_timer = stats.perfect_block_window
		PlayerState.State.HURT:
			sprite.play("hurt")
		PlayerState.State.TRANSFORM:
			sprite.play("transform")

func _perfect_block() -> void:
	print("完美格挡!")
	# TODO: 完美格挡特效和反击机会

#endregion
