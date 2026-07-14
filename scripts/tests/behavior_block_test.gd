## 格挡行为测试（headless）
## 验证 ④ 修复（commit 712b8fc, Option B）：projectile 改走 hurtbox area-overlap，
## 格挡判断现在对近战和远程统一生效。
##
## 5 case：
##   1. projectile 不格挡 → 全伤 10（基线：B 没破坏 projectile 伤害链路）
##   2. projectile 普通格挡 → 半伤 5（④ 核心：远程现在尊重格挡）
##   3. projectile 完美格挡 → 无伤 0（④：远程尊重完美格挡）
##   4. melee 普通格挡 → 半伤 5（回归守卫：近战格挡未被 B 破坏）
##   5. melee 完美格挡 → 无伤 0（回归守卫）
##
## 每 case 用新 player（避免 is_hurt 串扰）。所有节点挂 Node2D stage 下
## （root 是 Window，直接挂会导致 global_position setter 读 Window 失败）。
##
## 运行: godot --headless --script scripts/tests/behavior_block_test.gd

extends SceneTree

const FULL_DAMAGE := 10
const HALF_DAMAGE := 5
const NO_DAMAGE := 0

var _stage: Node2D


func _initialize() -> void:
	print("\n========================================")
	print("  格挡行为测试（headless）")
	print("  验证 ④: projectile 走 hurtbox 链路 → 格挡对远程也生效")
	print("========================================\n")

	_stage = Node2D.new()
	root.add_child(_stage)

	var results: Array[bool] = []
	results.append(await _test_case("projectile 不格挡   → 全伤 %d (基线)" % FULL_DAMAGE, "projectile", false, false, FULL_DAMAGE))
	results.append(await _test_case("projectile 普通格挡 → 半伤 %d [④]" % HALF_DAMAGE, "projectile", true, false, HALF_DAMAGE))
	results.append(await _test_case("projectile 完美格挡 → 无伤 %d [④]" % NO_DAMAGE, "projectile", true, true, NO_DAMAGE))
	results.append(await _test_case("melee 普通格挡     → 半伤 %d (回归)" % HALF_DAMAGE, "melee", true, false, HALF_DAMAGE))
	results.append(await _test_case("melee 完美格挡     → 无伤 %d (回归)" % NO_DAMAGE, "melee", true, true, NO_DAMAGE))

	var passed := 0
	for r in results:
		if r:
			passed += 1
	var ok: bool = passed == results.size()

	print("\n========================================")
	print("  %s — %d/%d 通过" % ["✅ 通过" if ok else "❌ 失败", passed, results.size()])
	print("========================================\n")

	_stage.queue_free()
	quit(0 if ok else 1)


func _spawn_player() -> CharacterBody2D:
	var packed := load("res://scenes/player.tscn") as PackedScene
	var player := packed.instantiate() as CharacterBody2D
	_stage.add_child(player)
	# 等 _ready：hurtbox 信号接线 + FSM setup(IDLE)
	for _i in 5:
		await physics_frame
	return player


func _make_melee_hitbox(at: Vector2) -> Area2D:
	# 模拟近战敌人 hitbox：layer=8（player hurtbox mask=8 监听），enemy_hitbox group
	var hitbox := Area2D.new()
	hitbox.collision_layer = 8
	hitbox.collision_mask = 0
	hitbox.add_to_group("enemy_hitbox")
	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	col.shape = circle
	hitbox.add_child(col)
	_stage.add_child(hitbox)  # 先入树（父=Node2D），再设 global_position
	hitbox.global_position = at
	return hitbox


func _spawn_projectile(at: Vector2) -> Area2D:
	# 真实 projectile.tscn（layer=8, mask=2, enemy_hitbox group）
	var packed := load("res://scenes/enemies/projectile.tscn") as PackedScene
	var proj := packed.instantiate() as Area2D
	_stage.add_child(proj)
	proj.set("direction", Vector2.ZERO)  # 停住，确保稳定重叠（测格挡不测弹道）
	proj.global_position = at
	return proj


func _test_case(label: String, kind: String, block: bool, perfect: bool, expected: int) -> bool:
	var player := await _spawn_player()
	player.set("is_blocking", block)
	if perfect:
		player.set("is_perfect_block", true)

	var h0: int = player.get("current_health")
	var hurtbox_pos: Vector2 = (player.get("hurtbox") as Node2D).global_position

	# 伤害源放到 hurtbox 上重叠 → area_entered 触发 → block 判断 → take_damage
	var source: Area2D
	if kind == "projectile":
		source = _spawn_projectile(hurtbox_pos)
	else:
		source = _make_melee_hitbox(hurtbox_pos)

	for _i in 6:
		await physics_frame

	var dealt: int = h0 - int(player.get("current_health"))
	var ok: bool = dealt == expected
	print("  [%s] %s" % ["✅" if ok else "❌", label])
	if not ok:
		print("      实际掉血=%d 期望=%d" % [dealt, expected])

	if is_instance_valid(source):
		source.queue_free()
	player.queue_free()
	for _i in 2:
		await physics_frame
	return ok
