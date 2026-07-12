## 快速验证：Boss 场景能加载 + 实例化
## 运行：Godot --headless --path . --script res://scripts/tests/verify_boss_scene.gd
extends Node

func _ready() -> void:
	print("========================================")
	print("  Boss 场景验证")
	print("========================================")

	# 1. 加载 boss 场景
	var boss_scene: PackedScene = load("res://scenes/enemies/black_bear_boss.tscn")
	assert(boss_scene != null, "FAIL: black_bear_boss.tscn load")
	print("[OK] black_bear_boss.tscn loaded")

	# 2. 实例化 boss
	var boss: BossBase = boss_scene.instantiate()
	assert(boss != null, "FAIL: boss instantiate")
	assert(boss is BossBase, "FAIL: boss is BossBase")
	assert(boss.stats is BossStats, "FAIL: boss.stats is BossStats")
	assert(boss.boss_stats.boss_name == "黑熊精", "FAIL: boss name")
	print("[OK] boss instantiated — name=%s, hp=%d/%d" % [boss.boss_stats.boss_name, boss.stats.current_health, boss.stats.max_health])

	# 3. 验证 BT 构建
	assert(boss.bt_root != null, "FAIL: bt_root null")
	assert(boss.bt_root.children.size() == 3, "FAIL: bt_root should have 3 children (P1, P2, P3)")
	print("[OK] behavior tree built — %d phase selectors" % boss.bt_root.children.size())

	# 4. 加载 arena 场景
	var arena_scene: PackedScene = load("res://scenes/levels/boss_arena.tscn")
	assert(arena_scene != null, "FAIL: boss_arena.tscn load")
	print("[OK] boss_arena.tscn loaded")

	# 5. 实例化 arena
	var arena: Node2D = arena_scene.instantiate()
	assert(arena != null, "FAIL: arena instantiate")
	assert(arena.has_node("BlackBearBoss"), "FAIL: arena has no BlackBearBoss")
	assert(arena.has_node("Player"), "FAIL: arena has no Player")
	assert(arena.has_node("BossHPBar"), "FAIL: arena has no BossHPBar")
	print("[OK] boss_arena instantiated — %d children" % arena.get_child_count())

	boss.queue_free()
	arena.queue_free()

	print("========================================")
	print("  全部通过 ✅")
	print("========================================")
	get_tree().quit(0)
