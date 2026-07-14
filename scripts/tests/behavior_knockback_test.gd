## 玩家击退行为测试（headless）
## 回归守卫 Bug⑤（commit 79acfd6）：
##
## ⑤a 方向: projectile 击中玩家 → 击退方向应远离子弹（area.global_position），
##          而非远离场景原点（buggy: enemy.global_position = projectile 父节点）。
##          projectile 父节点 = _stage/场景根 (0,0)。玩家在 (100,0)，子弹在 (110,0)：
##            fixed → knockback.x < 0（向左，远离子弹）
##            buggy → knockback.x > 0（向右，朝原点反方向）
##          注: 玩家不能在原点(0,0)——否则 direction_to(原点) 退化零向量，测不出方向。
##
## ⑤b 量级: knockback_velocity 应 ≈ KNOCKBACK_FORCE (150)。
##          buggy 用单位向量 (~1px/s)，被摩擦一帧归零 → |knockback| ≈ 0。
##
## 运行: godot --headless --script scripts/tests/behavior_knockback_test.gd

extends SceneTree

## player_controller.KNOCKBACK_FORCE；击退速度应在此量级，远大于 1
const MAGNITUDE_FLOOR := 100.0

var _stage: Node2D


func _initialize() -> void:
	print("\n========================================")
	print("  玩家击退行为测试（headless）")
	print("  Bug⑤: 击退方向(⑤a) + 量级(⑤b)")
	print("========================================\n")

	_stage = Node2D.new()
	root.add_child(_stage)

	var results: Array[bool] = []
	results.append(await _test_bug5a_direction())
	results.append(await _test_bug5b_magnitude())

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


# ---------- ⑤a: 击退方向远离子弹 ----------
func _test_bug5a_direction() -> bool:
	# 玩家 (100,0)，子弹 (110,0) 在玩家右侧。击退应向左（x<0）。
	var player := await _spawn_player_at(Vector2(100, 0))
	var _proj := _spawn_projectile_at(Vector2(110, 0))

	for _i in 4:
		await physics_frame

	var kv: Vector2 = player.get("knockback_velocity")
	var ok: bool = kv.x < 0.0  # fixed: 向左；buggy(enemy=原点): 向右
	print("  [%s] ⑤a 方向: knockback.x=%.1f (期望 <0, 远离子弹向左)" % ["✅" if ok else "❌", kv.x])
	if not ok:
		print("      hint: 用 enemy.global_position(父节点=原点0,0) 则 x>0，玩家朝原点反方向飞")

	if is_instance_valid(player):
		player.queue_free()
	for _i in 2:
		await physics_frame
	return ok


# ---------- ⑤b: 击退量级 ≈ KNOCKBACK_FORCE ----------
func _test_bug5b_magnitude() -> bool:
	var player := await _spawn_player_at(Vector2(100, 0))
	var _proj := _spawn_projectile_at(Vector2(110, 0))

	for _i in 4:
		await physics_frame

	var kv: Vector2 = player.get("knockback_velocity")
	var ok: bool = kv.length() > MAGNITUDE_FLOOR  # fixed: ≈117-150；buggy: ~0(单位向量被摩擦归零)
	print("  [%s] ⑤b 量级: |knockback|=%.1f (期望 >%.0f, ≈150)" % ["✅" if ok else "❌", kv.length(), MAGNITUDE_FLOOR])
	if not ok:
		print("      hint: 未乘 KNOCKBACK_FORCE(150) 则 knockback_velocity 是单位向量(~1px/s)，一帧归零")

	if is_instance_valid(player):
		player.queue_free()
	for _i in 2:
		await physics_frame
	return ok


# ---------- 辅助 ----------
func _spawn_player_at(pos: Vector2) -> CharacterBody2D:
	var packed := load("res://scenes/player.tscn") as PackedScene
	var player := packed.instantiate() as CharacterBody2D
	_stage.add_child(player)
	player.global_position = pos
	for _i in 5:
		await physics_frame
	return player


func _spawn_projectile_at(pos: Vector2) -> Area2D:
	# 真 projectile.tscn（layer=8, mask=2, enemy_hitbox group, r=4）
	var packed := load("res://scenes/enemies/projectile.tscn") as PackedScene
	var proj := packed.instantiate() as Area2D
	_stage.add_child(proj)
	proj.set("direction", Vector2.ZERO)  # 停住，确保稳定重叠（测击退不测弹道）
	proj.global_position = pos
	return proj
