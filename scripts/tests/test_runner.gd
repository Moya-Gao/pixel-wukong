## 测试运行器
## 自动运行所有测试并输出结果
extends SceneTree

var tests_passed = 0
var tests_failed = 0
var current_test_name = ""

func _init():
	print("\n========================================")
	print("  像素悟空 - 自动化测试")
	print("========================================\n")

func _initialize():
	# 运行测试
	await _run_all_tests()

	# 输出结果
	_print_summary()

	# 退出
	quit(0 if tests_failed == 0 else 1)

func _run_all_tests():
	# 测试玩家功能
	await _run_test("玩家初始化", _test_player_init)
	await _run_test("玩家动画状态", _test_player_animation)
	await _run_test("玩家移动", _test_player_movement)
	await _run_test("玩家攻击系统", _test_player_attack)
	await _run_test("玩家闪避系统", _test_player_dodge)
	await _run_test("玩家格挡系统", _test_player_block)
	await _run_test("连招预输入系统", _test_player_combo_queue)

func _run_test(test_name: String, test_func: Callable):
	current_test_name = test_name
	print("[测试] %s..." % test_name)

	var result = await test_func.call()

	if result is bool and result == true:
		tests_passed += 1
		print("  ✅ 通过\n")
	else:
		tests_failed += 1
		var error_msg = result if result is String else "未知错误"
		print("  ❌ 失败: %s\n" % error_msg)

func _print_summary():
	print("========================================")
	print("  测试完成: %d 通过, %d 失败" % [tests_passed, tests_failed])
	print("========================================\n")

# ========== 测试用例 ==========

func _test_player_init() -> Variant:
	"""测试玩家初始化"""
	var player = _create_player()

	if not player:
		return "无法创建玩家实例"

	if not player.has_method("_physics_process"):
		return "玩家缺少 _physics_process 方法"

	if player.facing_right != true:
		return "玩家初始朝向应为右侧"

	return true

func _test_player_animation() -> Variant:
	"""测试玩家动画状态"""
	var player = _create_player()

	if not player:
		return "无法创建玩家实例"

	# 直接获取子节点（不依赖 @onready）
	var sprite_root = player.get_node_or_null("SpriteRoot")
	if not sprite_root:
		return "缺少 SpriteRoot 节点"

	var animated_sprite = sprite_root.get_node_or_null("AnimatedSprite2D")
	if not animated_sprite:
		return "缺少 AnimatedSprite2D 组件"

	# 检查动画资源
	var sprite_frames = animated_sprite.sprite_frames
	if not sprite_frames:
		return "缺少 SpriteFrames 资源"

	var animations = sprite_frames.get_animation_names()
	var required_anims = ["idle", "run", "jump_rise", "jump_fall"]

	for anim in required_anims:
		if anim not in animations:
			return "缺少动画: %s" % anim

	return true

func _test_player_movement() -> Variant:
	"""测试玩家移动参数"""
	var player = _create_player()

	if not player:
		return "无法创建玩家实例"

	# 检查移动速度
	if player.SPEED <= 0:
		return "移动速度应大于 0"

	# 检查跳跃参数
	if player.MAX_JUMP_HEIGHT <= 0:
		return "跳跃高度应大于 0"

	if player.JUMP_GRAVITY <= 0:
		return "跳跃重力应大于 0"

	return true

func _test_player_attack() -> Variant:
	"""测试玩家攻击系统"""
	var player = _create_player()

	if not player:
		return "无法创建玩家实例"

	# 检查攻击参数
	if player.ATTACK_DURATION <= 0:
		return "攻击持续时间应大于 0"

	if player.COMBO_WINDOW <= 0:
		return "连击窗口应大于 0"

	# 检查初始状态
	if player.is_attacking != false:
		return "初始状态不应在攻击中"

	if player.attack_combo != 0:
		return "初始连击数应为 0"

	# 检查攻击动画资源
	var sprite_root = player.get_node_or_null("SpriteRoot")
	if sprite_root:
		var animated_sprite = sprite_root.get_node_or_null("AnimatedSprite2D")
		if animated_sprite:
			var sprite_frames = animated_sprite.sprite_frames
			if sprite_frames:
				var animations = sprite_frames.get_animation_names()
				var required_anims = ["attack_light_1", "attack_light_2", "attack_light_3", "attack_heavy"]
				for anim in required_anims:
					if anim not in animations:
						return "缺少攻击动画: %s" % anim

	return true

func _test_player_dodge() -> Variant:
	"""测试玩家闪避系统"""
	var player = _create_player()

	if not player:
		return "无法创建玩家实例"

	# 检查闪避参数
	if player.DODGE_SPEED <= 0:
		return "闪避速度应大于 0"

	if player.DODGE_DURATION <= 0:
		return "闪避持续时间应大于 0"

	if player.DODGE_COOLDOWN <= 0:
		return "闪避冷却应大于 0"

	# 检查无敌帧设置
	if player.INVINCIBLE_START >= player.INVINCIBLE_END:
		return "无敌帧开始时间应小于结束时间"

	# 检查初始状态
	if player.is_dodging != false:
		return "初始状态不应在闪避中"

	if player.is_invincible != false:
		return "初始状态不应无敌"

	# 测试闪避方向 - 向上闪避
	player._start_dodge(Vector2.UP)
	if player.dodge_direction != Vector2.UP:
		return "向上闪避方向应为 UP，实际为 %s" % player.dodge_direction
	player._end_dodge()

	# 测试闪避方向 - 向下闪避
	player._start_dodge(Vector2.DOWN)
	if player.dodge_direction != Vector2.DOWN:
		return "向下闪避方向应为 DOWN，实际为 %s" % player.dodge_direction
	player._end_dodge()

	# 测试闪避方向 - 向左闪避
	player._start_dodge(Vector2.LEFT)
	if player.dodge_direction != Vector2.LEFT:
		return "向左闪避方向应为 LEFT，实际为 %s" % player.dodge_direction
	player._end_dodge()

	# 测试闪避方向 - 向右闪避
	player._start_dodge(Vector2.RIGHT)
	if player.dodge_direction != Vector2.RIGHT:
		return "向右闪避方向应为 RIGHT，实际为 %s" % player.dodge_direction
	player._end_dodge()

	# 检查闪避动画
	var sprite_root = player.get_node_or_null("SpriteRoot")
	if sprite_root:
		var animated_sprite = sprite_root.get_node_or_null("AnimatedSprite2D")
		if animated_sprite:
			var sprite_frames = animated_sprite.sprite_frames
			if sprite_frames:
				var animations = sprite_frames.get_animation_names()
				if "dodge" not in animations:
					return "缺少闪避动画: dodge"

	return true

func _test_player_block() -> Variant:
	"""测试玩家格挡系统"""
	var player = _create_player()

	if not player:
		return "无法创建玩家实例"

	# 检查格挡参数
	if player.BLOCK_SPEED <= 0:
		return "格挡移动速度应大于 0"

	if player.PERFECT_BLOCK_WINDOW <= 0:
		return "完美格挡窗口应大于 0"

	# 检查初始状态
	if player.is_blocking != false:
		return "初始状态不应在格挡中"

	if player.is_perfect_block != false:
		return "初始状态不应处于完美格挡"

	# 检查格挡动画
	var sprite_root = player.get_node_or_null("SpriteRoot")
	if sprite_root:
		var animated_sprite = sprite_root.get_node_or_null("AnimatedSprite2D")
		if animated_sprite:
			var sprite_frames = animated_sprite.sprite_frames
			if sprite_frames:
				var animations = sprite_frames.get_animation_names()
				if "block" not in animations:
					return "缺少格挡动画: block"

	# 检查公共接口
	if not player.has_method("can_take_damage"):
		return "缺少 can_take_damage 方法"

	if not player.has_method("is_perfect_blocking"):
		return "缺少 is_perfect_blocking 方法"

	if not player.has_method("get_block_state"):
		return "缺少 get_block_state 方法"

	return true

func _test_player_combo_queue() -> Variant:
	"""测试连招预输入系统"""
	var player = _create_player()

	if not player:
		return "无法创建玩家实例"

	# 检查预输入相关参数
	if player.ATTACK_MOVE_SPEED <= 0:
		return "攻击移动速度应大于 0"

	if player.COMBO_INPUT_START <= 0:
		return "预输入窗口开始时间应大于 0"

	if player.COMBO_INPUT_END <= 0:
		return "预输入窗口结束时间应大于 0"

	# 检查预输入窗口足够大（至少 0.1s）
	var attack_duration = player.ATTACK_DURATION
	var input_window = attack_duration - player.COMBO_INPUT_START - player.COMBO_INPUT_END
	if input_window < 0.1:
		return "预输入窗口太小（%s），应至少 0.1s" % input_window

	# 检查初始状态
	if player.queued_attack != "":
		return "初始预输入队列应为空"

	# 测试轻攻击启动
	player._start_light_attack()
	if player.attack_combo != 1:
		return "第一次轻攻击后 combo 应为 1"

	if player.last_attack_type != player.AttackType.LIGHT:
		return "轻攻击后类型应为 LIGHT"

	# 模拟预输入
	player.queued_attack = "light"

	# 模拟攻击结束并执行预输入
	player.attack_timer = 0
	player._process_attack(0.016)

	if player.attack_combo != 2:
		return "预输入执行后 combo 应为 2，实际为 %d" % player.attack_combo

	# 测试重攻击预输入
	player.queued_attack = "heavy"
	player.attack_timer = 0
	player._process_attack(0.016)

	if player.last_attack_type != player.AttackType.HEAVY:
		return "重攻击预输入后类型应为 HEAVY"

	return true

func _create_player():
	"""创建玩家实例用于测试"""
	var player_scene = load("res://scenes/player.tscn")
	if not player_scene:
		return null

	var player = player_scene.instantiate()
	# 添加到场景树以初始化 @onready 变量
	root.add_child(player)
	return player
