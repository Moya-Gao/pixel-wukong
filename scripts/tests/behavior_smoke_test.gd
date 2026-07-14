## 行为冒烟测试（headless 模拟输入）
## 证明：headless 下能模拟玩家输入 + 跑真实物理帧 + 断言行为，
##       直接抓"玩家不动"这类"代码看着对、实机跑炸"的 bug。
##
## 这是 co-creator 要的"不用手动操作就能发现问题"的最小验证：
##   - 不开渲染窗口（headless，CI 友好）
##   - 模拟按方向键 → 断言玩家真的移动了
##   - Bug 1（setup 不进 IDLE → state_instance null → 玩家不动）会被本测试抓红
##
## 运行: godot --headless --script scripts/tests/behavior_smoke_test.gd

extends SceneTree


func _initialize() -> void:
	print("\n========================================")
	print("  行为冒烟测试（headless 模拟输入）")
	print("  抓 Bug1: 玩家不动（setup 没进初始状态）")
	print("========================================\n")

	var ok := await _test_player_movement()

	print("\n========================================")
	if ok:
		print("  ✅ 通过 — 玩家能动，headless 行为测试可行")
	else:
		print("  ❌ 失败 — 玩家没动，行为测试抓到问题")
	print("========================================\n")

	quit(0 if ok else 1)


func _test_player_movement() -> bool:
	var packed := load("res://scenes/player.tscn") as PackedScene
	if not packed:
		print("  ❌ 无法加载 player.tscn")
		return false

	var player := packed.instantiate() as CharacterBody2D
	if not player:
		print("  ❌ player 实例化失败或非 CharacterBody2D")
		return false
	root.add_child(player)

	# 等 _ready + setup(IDLE) 完成
	for _i in 5:
		await physics_frame

	var fsm := player.get_node_or_null("PlayerStateMachine")
	var fsm_alive := is_instance_valid(fsm) and fsm.get("state_instance") != null

	# 记录初始 X
	var x0 := player.global_position.x

	# 模拟按住"右"跑 30 个物理帧（Godot 自动跑 _physics_process + move_and_slide）
	Input.action_press("move_right")
	for _i in 30:
		await physics_frame
	Input.action_release("move_right")

	var dx := player.global_position.x - x0
	var moved := dx > 5.0

	print("  [断言1] FSM 启动 (setup 进 IDLE, state_instance!=null): %s" %
		["❌ null → Bug1 玩家不动", "✅ 活着"][int(fsm_alive)])
	print("  [断言2] 玩家右移 dx=%.2f (阈值>5): %s" %
		[dx, ["❌ 没动 → Bug1", "✅ 动了"][int(moved)]])

	player.queue_free()
	for _i in 2:
		await physics_frame

	return fsm_alive and moved
