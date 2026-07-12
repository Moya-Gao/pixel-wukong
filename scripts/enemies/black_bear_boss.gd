## 黑熊精 Boss
## 三阶段：黑风掌(P1) → 黑风怒(P2) → 黑风狂暴(P3)
## 行为树编排：Selector(Phase3 > Phase2 > Phase1) → 每阶段内含多种攻击模式
class_name BlackBearBoss
extends BossBase

# ========== 攻击名称常量 ==========
const ATK_SWIPE: String = "swipe"
const ATK_SWIPE_COMBO: String = "swipe_combo"
const ATK_SLAM: String = "ground_slam"
const ATK_CHARGE: String = "charge"
const ATK_BERSERK: String = "berserk"

# ========== 攻击参数（按阶段）==========
const SWIPE_RANGE: float = 48.0
const SLAM_RANGE: float = 80.0
const CHARGE_RANGE: float = 200.0
const BERSERK_RANGE: float = 60.0

const SWIPE_DURATION: float = 0.4
const SWIPE_COMBO_DURATION: float = 0.7
const SLAM_DURATION: float = 0.8
const CHARGE_DURATION: float = 0.5
const BERSERK_DURATION: float = 1.2

# ========== 冷却时间（按阶段）==========
# P1: [swipe, slam, charge, berserk]
const COOLDOWNS_P1: Array[float] = [2.0, 8.0, 999.0, 999.0]  # P1 只有 swipe + slam
const COOLDOWNS_P2: Array[float] = [1.5, 6.0, 4.0, 999.0]    # P2 加入 charge
const COOLDOWNS_P3: Array[float] = [1.0, 5.0, 3.0, 8.0]       # P3 全开 + berserk

# ========== 突进状态 ==========
var _is_charging: bool = false
var _charge_direction: Vector2 = Vector2.ZERO
var _charge_speed: float = 450.0


# ========== BT 构建 ==========
func _build_behavior_tree() -> BTNode:
	var root := BTSelector.new()

	# Phase 3: 黑风狂暴 (≤33%)
	var p3 := _build_phase_sequence(2)
	root.add_child(p3)

	# Phase 2: 黑风怒 (≤66%)
	var p2 := _build_phase_sequence(1)
	root.add_child(p2)

	# Phase 1: 黑风掌 (always)
	var p1 := _build_phase_sequence(0)
	root.add_child(p1)

	return root


func _build_phase_sequence(phase: int) -> BTSequence:
	var seq := BTSequence.new()

	# 阶段条件
	seq.add_child(BTCondition.new(func(ctx: Dictionary) -> bool:
		if phase == 0:
			return true
		return ctx["health_ratio"] <= boss_stats.phase_thresholds[phase - 1]
	))

	# 攻击选择器
	var attack_sel := BTSelector.new()

	# 获取该阶段的冷却配置
	var cooldowns: Array[float] = COOLDOWNS_P1
	match phase:
		1: cooldowns = COOLDOWNS_P2
		2: cooldowns = COOLDOWNS_P3

	# --- Berserk (仅 P3) ---
	# 索引对应 COOLDOWNS_Px 注释顺序 [swipe, slam, charge, berserk]
	if cooldowns[3] < 999.0:
		attack_sel.add_child(_build_attack_seq(ATK_BERSERK, BERSERK_RANGE, cooldowns[3], BERSERK_DURATION, func(): _do_berserk()))

	# --- Ground Slam ---
	attack_sel.add_child(_build_attack_seq(ATK_SLAM, SLAM_RANGE, cooldowns[1], SLAM_DURATION, func(): _do_slam()))

	# --- Charge ---
	if cooldowns[2] < 999.0:
		attack_sel.add_child(_build_attack_seq(ATK_CHARGE, CHARGE_RANGE, cooldowns[2], CHARGE_DURATION, func(): _do_charge()))

	# --- Swipe Combo (P2+) / Basic Swipe (P1) ---
	# Swipe Combo 共用 swipe 冷却（[0]）；保留独立常量需扩展为 5 元素数组
	if phase >= 1:
		attack_sel.add_child(_build_attack_seq(ATK_SWIPE_COMBO, SWIPE_RANGE, cooldowns[0], SWIPE_COMBO_DURATION, func(): _do_swipe_combo()))
	else:
		attack_sel.add_child(_build_attack_seq(ATK_SWIPE, SWIPE_RANGE, cooldowns[0] if cooldowns.size() > 0 else 2.0, SWIPE_DURATION, func(): _do_swipe()))

	# --- 追击（兜底）---
	attack_sel.add_child(BTAction.new(_chase_player, 0.0))

	seq.add_child(attack_sel)
	return seq


## 构建单个攻击序列：条件(冷却+距离) → telegraph → 执行攻击
func _build_attack_seq(atk_name: String, atk_range: float, cooldown: float, _atk_duration: float, exec_fn: Callable) -> BTSequence:
	var seq := BTSequence.new()

	# 条件：冷却就绪 + 目标在范围内
	seq.add_child(BTCondition.new(func(ctx: Dictionary) -> bool:
		if not is_cooldown_ready(atk_name):
			return false
		if not ctx["target"]:
			return false
		var dist := global_position.distance_to(ctx["target"].global_position)
		return dist <= atk_range
	))

	# Telegraph
	seq.add_child(BTAction.new(func(_d: float, _c: Dictionary):
		_show_attack_telegraph()
		velocity = Vector2.ZERO
	, 0.15))

	# 执行攻击 + 冷却
	seq.add_child(BTAction.new(func(_d: float, _c: Dictionary):
		exec_fn.call()
		start_custom_cooldown(atk_name, cooldown)
	, 0.0))

	return seq


# ========== 攻击实现 ==========

## 普攻：熊掌横扫
func _do_swipe() -> void:
	is_attacking = true
	attack_timer = SWIPE_DURATION
	velocity = Vector2.ZERO
	_activate_hitbox()


## 二连击：左右开弓
func _do_swipe_combo() -> void:
	is_attacking = true
	attack_timer = SWIPE_COMBO_DURATION
	velocity = Vector2.ZERO
	_activate_hitbox()
	# 第二击在攻击中途重新激活 hitbox（重置 _has_dealt_damage）
	# 用定时器：0.35s 后重置伤害标记，让第二击也能命中
	get_tree().create_timer(0.35).timeout.connect(func():
		if is_attacking:
			_has_dealt_damage = false
	)


## 地裂：跳起 → 砸地 AoE
func _do_slam() -> void:
	is_attacking = true
	attack_timer = SLAM_DURATION
	velocity = Vector2.ZERO
	_activate_hitbox()

	# 视觉跳跃效果
	var original_y := sprite_root.position.y if sprite_root else 0.0
	if sprite_root:
		var t := create_tween()
		t.tween_property(sprite_root, "position:y", original_y - 30, 0.25)
		t.tween_property(sprite_root, "position:y", original_y, 0.3)
		t.tween_callback(func():
			# 落地震动
			if get_tree():
				var shake := _get_screen_shake()
				if shake: shake.trigger(0.15, 8.0)
			# 扩大判定范围
			if hitbox:
				for child in hitbox.get_children():
					if child is CollisionShape2D:
						if child.shape is CircleShape2D:
							child.shape.radius = 28.0  # 临时扩大
		)


## 突进冲撞
func _do_charge() -> void:
	_is_charging = true
	attack_timer = CHARGE_DURATION
	is_attacking = true

	if target:
		_charge_direction = (target.global_position - global_position).normalized()
		facing_right = _charge_direction.x > 0
	else:
		_charge_direction = Vector2(1 if facing_right else -1, 0)

	_activate_hitbox()
	velocity = _charge_direction * _charge_speed


## 狂暴连击（P3 专属）
func _do_berserk() -> void:
	is_attacking = true
	attack_timer = BERSERK_DURATION
	velocity = Vector2.ZERO
	_activate_hitbox()

	# 多次重置伤害标记实现多段打击
	for i in range(3):
		get_tree().create_timer(0.25 * (i + 1)).timeout.connect(func():
			if is_attacking:
				_has_dealt_damage = false
				_check_hitbox_overlaps()
		)


# ========== 追击行为 ==========
func _chase_player(_delta: float, ctx: Dictionary) -> void:
	var t: Node2D = ctx.get("target", null)
	if not t:
		velocity = Vector2.ZERO
		return

	var dir_x: float = sign(t.global_position.x - global_position.x)
	var dir_y: float = sign(t.global_position.y - global_position.y)
	if dir_x != 0:
		facing_right = dir_x > 0

	var speed := boss_stats.get_phase_speed(current_phase)
	velocity.x = dir_x * speed
	velocity.y = dir_y * speed


# ========== 攻击结束 ==========
func _end_attack() -> void:
	super._end_attack()
	_is_charging = false

	# 恢复 hitbox 半径
	if hitbox:
		for child in hitbox.get_children():
			if child is CollisionShape2D:
				if child.shape is CircleShape2D:
					child.shape.radius = 14.0  # 恢复默认值


# ========== 辅助 ==========
func _get_screen_shake() -> Node:
	var main := get_tree().current_scene
	if main:
		for child in main.get_children():
			if child.has_method("trigger"):
				return child
	return null


# ========== 更新动画 ==========
func _update_animation() -> void:
	if not animated_sprite:
		return

	var new_anim := ""

	if is_dead:
		new_anim = "death"
	elif is_hurt:
		new_anim = "hurt"
	elif _is_charging:
		new_anim = "attack"
	elif is_attacking:
		new_anim = "attack"
	elif velocity.length() > 10:
		new_anim = "run"
	else:
		new_anim = "idle"

	if new_anim != animated_sprite.animation:
		animated_sprite.play(new_anim)
