## 死亡系统测试
extends SceneTree

func _init():
	print("\n========================================")
	print("  死亡系统测试")
	print("========================================\n")

func _initialize():
	await run_test()
	quit(0)

func run_test():
	var scene = Node2D.new()
	root.add_child(scene)

	# 创建玩家
	print("=== 步骤1: 创建玩家 ===")
	var player_scene = load("res://scenes/player.tscn")
	var player = player_scene.instantiate()
	player.global_position = Vector2(100, 100)
	scene.add_child(player)
	await wait_frames(10)

	var passed = true

	# 验证玩家初始状态
	print("玩家初始状态: is_dead=%s, health=%d" % [player.is_dead, player.current_health])
	if player.is_dead or player.current_health != 100:
		print("❌ 初始状态错误")
		passed = false

	# 应用伤害直到死亡
	print("\n=== 步骤2: 应用伤害直到死亡 ===")
	var attempt = 0
	while not player.is_dead and attempt < 20:
		attempt += 1
		if not player.is_hurt:
			player.take_damage(35, Vector2.LEFT)
			print("  攻击 %d: 血量=%d, is_dead=%s" % [attempt, player.current_health, player.is_dead])
		await wait_frames(1)
		while player.is_hurt and not player.is_dead:
			await wait_frames(1)

	# 验证死亡状态
	print("死亡后: is_dead=%s, collision_layer=%d" % [player.is_dead, player.collision_layer])
	if not player.is_dead:
		print("❌ 玩家应该死亡")
		passed = false
	if player.collision_layer != 0:
		print("❌ collision_layer 应该为 0")
		passed = false

	# 等待死亡动画完成（最多5秒）
	print("\n=== 步骤3: 等待死亡淡出 ===")
	var wait_count = 0
	while player.visible and wait_count < 300:
		await wait_frames(10)
		wait_count += 10
		if wait_count % 50 == 0:
			print("  已等待 %d 帧, visible=%s, alpha=%.2f" % [wait_count, player.visible, player.modulate.a])

	# 验证 Game Over UI
	print("\n=== 步骤4: 检查 Game Over UI ===")
	var game_over = root.get_node_or_null("GameOver")
	if not game_over:
		print("❌ Game Over UI 未出现")
		passed = false
	else:
		print("✅ Game Over UI 已出现")
		var btn = game_over.get_node_or_null("VBox/RestartButton")
		if btn:
			print("✅ RESTART 按钮存在")
		else:
			print("❌ RESTART 按钮不存在")
			passed = false

	# 结果
	print("\n========================================")
	if passed:
		print("  所有测试通过! ✅")
	else:
		print("  有测试失败 ❌")
	print("========================================")

func wait_frames(frames: int):
	for i in range(frames):
		await process_frame
