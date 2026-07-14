## Boss 行为测试（headless）
## 回归守卫两个已修 bug（commit 9c61b68）：
##
## Bug2 — Boss 打人不掉血（伤害系统 mask=0 失效）
##   根因: player hurtbox collision_mask=0 → get_overlapping_areas 永远空 → 不掉血
##   修复: hurtbox mask 0→8
##   本测试: 真 boss hitbox (layer=8, 有 stats) 重叠 player hurtbox → player 掉
##           boss.stats.attack_damage (15)。覆盖 _on_hurtbox_area_entered 的
##           "stats" in enemy 读取分支（block_test 的 melee hitbox 无 stats，走默认
##           10，未覆盖此分支）。
##
## Bug3 — Boss 挨打飞出屏幕（击退速度二次乘法）
##   根因: BossBase._start_hurt 预乘后传 EnemyBase 又乘一次 → 15750 px/s
##   修复: 先 super._start_hurt（设 velocity=dir*force）再 *= (1-poise) → 105 px/s
##   本测试: boss.take_damage → velocity.length() == knockback_force*(1-poise) = 105
##           （bound < 1000 守 15750 爆炸；formula ≈105 守二次乘法）
##
## 运行: godot --headless --script scripts/tests/behavior_boss_test.gd

extends SceneTree

## 任何合理击退速度都 < 1000 px/s；二次乘法回归 (15750) 必超此界
const KNOCKBACK_BOUND := 1000.0

var _stage: Node2D


func _initialize() -> void:
	print("\n========================================")
	print("  Boss 行为测试（headless）")
	print("  Bug2: boss hitbox 造伤 | Bug3: 击退速度有界")
	print("========================================\n")

	_stage = Node2D.new()
	root.add_child(_stage)

	var results: Array[bool] = []
	results.append(await _test_bug2_boss_deals_damage())
	results.append(await _test_bug3_boss_knockback_bounded())

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


# ---------- Bug2: Boss hitbox → player 掉 boss.attack_damage ----------
func _test_bug2_boss_deals_damage() -> bool:
	var player := await _spawn_player()
	var boss := await _spawn_boss()

	# 激活 boss hitbox 的 CollisionShape2D（默认 disabled=true）并归零偏移
	var hitbox := boss.get("hitbox") as Area2D
	for child in hitbox.get_children():
		if child is CollisionShape2D:
			child.disabled = false
			child.position = Vector2.ZERO
	# 定位 hitbox 精确重叠 player hurtbox（两圆同心 → 必重叠）
	var hurtbox_pos: Vector2 = (player.get("hurtbox") as Node2D).global_position
	hitbox.global_position = hurtbox_pos

	var h0: int = player.get("current_health")
	for _i in 8:
		await physics_frame

	var stats_res = boss.get("stats")
	var expected: int = int(stats_res.attack_damage)  # 15
	var dealt: int = h0 - int(player.get("current_health"))
	var ok: bool = dealt == expected
	print("  [%s] Bug2: Boss hitbox → player 掉 %d (期望 %d = boss.attack_damage)" % ["✅" if ok else "❌", dealt, expected])
	if not ok:
		print("      hint: mask=0 回归则 dealt=0；stats 读取坏则 dealt=10(默认)")

	if is_instance_valid(boss):
		boss.queue_free()
	if is_instance_valid(player):
		player.queue_free()
	for _i in 2:
		await physics_frame
	return ok


# ---------- Bug3: Boss 受击击退速度有界且正确 ----------
func _test_bug3_boss_knockback_bounded() -> bool:
	var boss := await _spawn_boss()

	var v0: Vector2 = boss.get("velocity")
	# 同步调 take_damage → _start_hurt 设 velocity（冻结核下无摩擦干扰）
	boss.call("take_damage", 10, Vector2.LEFT)
	var v: Vector2 = boss.get("velocity")

	var stats_res = boss.get("stats")
	var expected_speed: float = float(stats_res.knockback_force) * (1.0 - float(stats_res.poise_resistance))

	var bounded: bool = v.length() < KNOCKBACK_BOUND
	var correct: bool = abs(v.length() - expected_speed) < 10.0
	var dir_ok: bool = v.x < 0.0  # knockback_dir=LEFT → velocity.x < 0
	var ok: bool = bounded and correct and dir_ok

	print("  [%s] Bug3: 击退 speed=%.1f (期望 ≈%.1f, bound<%.0f, dir=LEFT)" % ["✅" if ok else "❌", v.length(), expected_speed, KNOCKBACK_BOUND])
	if not ok:
		print("      实际 velocity=%s v0=%s | bounded=%s correct=%s dir=%s" % [str(v), str(v0), bounded, correct, dir_ok])
		print("      hint: 二次乘法回归则 speed≈15750(超 bound)；方向错则 dir=false")

	if is_instance_valid(boss):
		boss.queue_free()
	for _i in 2:
		await physics_frame
	return ok


# ---------- 辅助 ----------
func _spawn_player() -> CharacterBody2D:
	var packed := load("res://scenes/player.tscn") as PackedScene
	var player := packed.instantiate() as CharacterBody2D
	_stage.add_child(player)
	for _i in 5:
		await physics_frame
	return player


func _spawn_boss() -> CharacterBody2D:
	var packed := load("res://scenes/enemies/black_bear_boss.tscn") as PackedScene
	var boss := packed.instantiate() as CharacterBody2D
	_stage.add_child(boss)
	# 冻结：_physics_process 关 → BT 不 tick、不移动、不攻击、无摩擦 → 确定性。
	# _ready 仍正常跑（stats 拷贝、group、信号接线、BT 建树），不受影响。
	boss.set_physics_process(false)
	for _i in 5:
		await physics_frame
	return boss
