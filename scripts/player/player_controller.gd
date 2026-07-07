## 玩家控制器（FSM 重构版，Step 1）
## 精简到 ~150 行：只做 输入读取 + FSM 调度 + 物理移动 + 公共方法
## 状态具体逻辑委托给 states/*.gd
## 视觉更新委托给 PlayerVisual
##
## 不修改 player.tscn：PlayerStateMachine 和 PlayerVisual 在 _ready 里动态 add_child

extends CharacterBody2D

# ========== 节点引用 ==========
@onready var sprite_root: Node2D = $SpriteRoot
@onready var animated_sprite: AnimatedSprite2D = $SpriteRoot/AnimatedSprite2D
@onready var shadow: ColorRect = $Shadow
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_collision: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var shield_effect: Node2D = $SpriteRoot/ShieldEffect
# fsm 和 visual 在 _ready 里动态 add_child（不改 player.tscn）
var fsm: PlayerStateMachine
var visual: PlayerVisual

# ========== 常量（state 需要直接访问）==========
const SPEED = 200.0
const MAX_JUMP_HEIGHT = 40.0
const JUMP_GRAVITY = 600.0
const MAX_VISUAL_OFFSET = 15.0
const ATTACK_DURATION = 0.25
const COMBO_WINDOW = 0.3
const HEAVY_ATTACK_DURATION = 0.4
const ATTACK_MOVE_SPEED = 80.0
const COMBO_INPUT_START = 0.05
const COMBO_INPUT_END = 0.05
const DODGE_SPEED = 400.0
const DODGE_DURATION = 0.2
const DODGE_COOLDOWN = 0.5
const INVINCIBLE_START = 0.05
const INVINCIBLE_END = 0.15
const BLOCK_SPEED = 80.0
const PERFECT_BLOCK_WINDOW = 0.15
const HURT_DURATION = 0.3
const KNOCKBACK_FORCE = 150.0
const DEATH_FADE_DURATION = 0.5

# ========== 共享状态（被多个 state 访问）==========
var facing_right: bool = true
var visual_offset_x: float = 0.0
var current_health: int = 100
var max_health: int = 100
var is_hurt: bool = false
var hurt_timer: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO
var is_dead: bool = false
var death_fade_timer: float = -1.0
var death_fade_complete: bool = false
var jump_height: float = 0.0
var jump_velocity: float = 0.0
var current_anim: String = ""

# 攻击（state_attack 维护，被 get_current_attack_damage 读）
var is_attacking: bool = false
var attack_combo: int = 0
var attack_timer: float = 0.0
var combo_window_timer: float = 0.0
var queued_attack: String = ""
var last_attack_type: int = 0
var _has_dealt_damage: bool = false
enum AttackType { LIGHT, HEAVY }

# 闪避
var is_dodging: bool = false
var dodge_timer: float = 0.0
var dodge_direction: Vector2 = Vector2.RIGHT
var is_invincible: bool = false
var dodge_cooldown_timer: float = 0.0

# 格挡
var is_blocking: bool = false
var perfect_block_timer: float = 0.0
var is_perfect_block: bool = false


func _ready() -> void:
	add_to_group("player")
	if hitbox:
		hitbox.add_to_group("player_hitbox")
	if hurtbox:
		hurtbox.add_to_group("player_hurtbox")
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)

	# 动态添加 FSM 和 Visual 节点（不动 player.tscn）
	fsm = preload("res://scripts/player/player_state_machine.gd").new()
	fsm.name = "PlayerStateMachine"
	add_child(fsm)
	fsm.setup(self)

	visual = preload("res://scripts/player/player_visual.gd").new()
	visual.name = "PlayerVisual"
	add_child(visual)
	visual.player = self


func _physics_process(delta: float) -> void:
	if dodge_cooldown_timer > 0:
		dodge_cooldown_timer -= delta
	fsm.process(delta)
	move_and_slide()
	visual.update_visual()
	visual.update_animation()


# ========== 输入检测（被 state 调用）==========
func _read_movement_direction() -> Vector2:
	var dir := Vector2.ZERO
	if Input.is_action_pressed("move_right"): dir.x += 1; facing_right = true
	if Input.is_action_pressed("move_left"): dir.x -= 1; facing_right = false
	if Input.is_action_pressed("move_down"): dir.y += 1
	if Input.is_action_pressed("move_up"): dir.y -= 1
	return dir

func _wants_light_attack() -> bool: return Input.is_action_just_pressed("attack_light")
func _wants_heavy_attack() -> bool: return Input.is_action_just_pressed("attack_heavy")
func _wants_jump() -> bool: return Input.is_action_just_pressed("jump")
func _wants_dodge() -> bool: return Input.is_action_just_pressed("dodge") and dodge_cooldown_timer <= 0
func _wants_block() -> bool: return Input.is_action_pressed("block")


# ========== 公共方法（被其他系统调用）==========
func can_take_damage() -> bool: return not (is_dodging and is_invincible)
func is_perfect_blocking() -> bool: return is_blocking and is_perfect_block
func get_block_state() -> Dictionary:
	return {"is_blocking": is_blocking, "is_perfect": is_perfect_block, "perfect_timer": perfect_block_timer}

# ========== 测试入口（包装 FSM 转换，保持测试兼容）==========
func _start_dodge(direction: Vector2) -> void:
	# 确保从 IDLE 开始（避免 DODGE→DODGE 非法转换）
	if fsm.current_state != PlayerState.State.IDLE:
		_end_dodge()
		fsm.transition_to(PlayerState.State.IDLE)
	fsm.transition_to(PlayerState.State.DODGE, {"direction": direction})

func _start_light_attack() -> void:
	fsm.transition_to(PlayerState.State.ATTACK_LIGHT)

func _process_attack(delta: float) -> void:
	fsm.process(delta)

func get_current_attack_damage() -> int:
	if last_attack_type == AttackType.HEAVY: return 25
	return 10 + (attack_combo - 1) * 5

func take_damage(damage: int, knockback_dir: Vector2) -> void:
	if is_hurt or is_dead: return
	current_health = maxi(current_health - damage, 0)
	if current_health <= 0:
		fsm.transition_to(PlayerState.State.DEAD)
	else:
		fsm.transition_to(PlayerState.State.HURT, {"knockback": knockback_dir})


# ========== Hitbox 管理（被 state_attack 调用）==========
func _activate_hitbox() -> void:
	if hitbox_collision:
		hitbox_collision.position.x = 8.0 if facing_right else -8.0
		hitbox_collision.disabled = false
	_has_dealt_damage = false

func _check_hitbox_damage() -> void:
	if _has_dealt_damage or not hitbox: return
	for area in hitbox.get_overlapping_areas():
		if area != hurtbox and area.is_in_group("enemy_hurtbox"):
			var enemy = area.get_parent()
			if enemy and enemy.has_method("take_damage"):
				enemy.take_damage(get_current_attack_damage(), enemy.global_position.direction_to(global_position) * -1)
			_has_dealt_damage = true
			break

func _deactivate_hitbox() -> void:
	if hitbox_collision: hitbox_collision.disabled = true


# ========== 攻击 / 格挡 / 闪避 结束（被对应 state 调用）==========
func _end_attack() -> void:
	is_attacking = false
	attack_timer = 0
	queued_attack = ""
	if combo_window_timer <= 0: attack_combo = 0
	_deactivate_hitbox()

func _end_block() -> void:
	is_blocking = false
	is_perfect_block = false
	perfect_block_timer = 0.0
	if shield_effect: shield_effect.visible = false

func _show_shield_effect(show: bool) -> void:
	if shield_effect: shield_effect.visible = show

func _end_dodge() -> void:
	is_dodging = false
	dodge_timer = 0
	is_invincible = false
	_set_hurtbox_active(true)
	velocity = Vector2.ZERO

func _set_hurtbox_active(active: bool) -> void:
	if hurtbox:
		for child in hurtbox.get_children():
			if child is CollisionShape2D: child.disabled = not active


# ========== 死亡 ==========
func _start_death_fade() -> void:
	death_fade_timer = DEATH_FADE_DURATION
	death_fade_complete = false

func _on_death_complete() -> void:
	visible = false
	get_tree().root.add_child(preload("res://scenes/ui/game_over.tscn").instantiate())


# ========== 受击信号（Player.Hurtbox.area_entered）==========
func _on_hurtbox_area_entered(area: Area2D) -> void:
	if not area.is_in_group("enemy_hitbox"): return
	if not can_take_damage(): return
	var enemy := area.get_parent()
	var damage := 10
	if "stats" in enemy and enemy.stats: damage = enemy.stats.attack_damage
	var knockback_dir := global_position.direction_to(enemy.global_position) * -1
	if is_perfect_blocking():
		if enemy.has_method("apply_stun"): enemy.apply_stun(0.5)
		return
	elif is_blocking:
		damage = damage / 2
	take_damage(damage, knockback_dir)