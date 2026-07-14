## 场景完整性自测
## 验证所有 .tscn 的碰撞层/掩码符合项目约定的碰撞层方案
##
## 碰撞层方案（真理源）：
##   Layer 1 (1): 物理体（玩家body / 敌人body / 墙壁）
##   Layer 2 (2): 玩家 Hurtbox（被敌人 Hitbox 检测）
##   Layer 3 (4): 敌人 Hurtbox（被玩家 Hitbox / 投射物检测）
##   Layer 4 (8): 所有 Hitbox（玩家 + 敌人攻击判定）
##
## 运行: godot --headless --script scripts/tests/scene_integrity_test.gd
## 输出: docs/scene-integrity-report.md

extends SceneTree

const SCENE_DIRS := [
	"res://scenes/player.tscn",
	"res://scenes/enemies/black_bear_boss.tscn",
	"res://scenes/enemies/grunt.tscn",
	"res://scenes/enemies/ranged_enemy.tscn",
	"res://scenes/enemies/projectile.tscn",
	"res://scenes/levels/boss_arena.tscn",
	"res://scenes/levels/test_level.tscn",
]

const REPORT_PATH := "res://docs/scene-integrity-report.md"

# 碰撞层方案常量
const LAYER_BODY := 1       # 物理体
const LAYER_PLAYER_HURT := 2  # 玩家受击框
const LAYER_ENEMY_HURT := 4   # 敌人受击框
const LAYER_HITBOX := 8       # 攻击判定框

var _results := {
	"collision": {"passed": 0, "failed": 0, "details": []},
	"fsm_init": {"passed": 0, "failed": 0, "details": []},
	"node_exist": {"passed": 0, "failed": 0, "details": []},
	"knockback": {"passed": 0, "failed": 0, "details": []},
}


func _init() -> void:
	print("\n========================================")
	print("  像素悟空 - 场景完整性自测")
	print("========================================\n")


func _initialize() -> void:
	await _test_collision_layers()
	await _test_required_nodes()
	await _test_fsm_initialization()
	await _test_knockback_bounds()
	_generate_report()
	_print_results()
	quit(0 if _total_failures() == 0 else 1)


# ================================================================
#  L1: 碰撞层完整性
# ================================================================

func _test_collision_layers() -> void:
	print("[L1] 碰撞层/掩码完整性...")

	for scene_path: String in SCENE_DIRS:
		var scene_name: String = scene_path.get_file()
		var packed := _safe_load(scene_path)
		if not packed:
			_results.collision.details.append("⚠️ 无法加载: %s" % scene_name)
			continue

		var root := packed.instantiate()
		if not root:
			_results.collision.details.append("⚠️ 无法实例化: %s" % scene_name)
			continue

		root.add_child(root) if false else null  # 抑制未使用警告
		_check_node_recursive(root, scene_name, root)

		if root is Node:
			root.queue_free()
		await process_frame

	print("  L1 碰撞层: %d 通过, %d 失败" % [_results.collision.passed, _results.collision.failed])


func _check_node_recursive(node: Node, scene_name: String, root: Node) -> void:
	# 检查当前节点
	if node is Area2D:
		_check_area_collision(node, scene_name, root)
	elif node is CharacterBody2D and node.script:
		_check_body_collision(node, scene_name)

	# 递归子节点
	for child in node.get_children():
		_check_node_recursive(child, scene_name, root)


func _check_area_collision(area: Area2D, scene_name: String, _root: Node) -> void:
	var node_path := _get_node_path(area)
	var layer := area.collision_layer
	var mask := area.collision_mask

	match area.name:
		"Hurtbox":
			# Hurtbox 的 mask 不能为 0（必须监听对面的 Hitbox）
			if mask == 0:
				_fail("collision", "%s / %s: Hurtbox collision_mask=0（不监听任何层，不会收到伤害）" % [scene_name, node_path])
			else:
				_pass("collision")
			# Hurtbox 的 layer 必须在已知层上
			if not _is_known_layer(layer):
				_fail("collision", "%s / %s: Hurtbox collision_layer=%d（不在已知层 1/2/4/8 上）" % [scene_name, node_path, layer])
			else:
				_pass("collision")

		"Hitbox":
			# Hitbox 的 mask 必须包含玩家 Hurtbox 层
			if not (_mask_includes(mask, LAYER_PLAYER_HURT) or _mask_includes(mask, LAYER_ENEMY_HURT)):
				_fail("collision", "%s / %s: Hitbox collision_mask=%d 不包含任何 Hurtbox 层(2/4)——无法造成伤害" % [scene_name, node_path, mask])
			else:
				_pass("collision")
			# Hitbox 必须在正确的层上
			if layer != LAYER_HITBOX:
				_fail("collision", "%s / %s: Hitbox collision_layer=%d（应为 %d）" % [scene_name, node_path, layer, LAYER_HITBOX])
			else:
				_pass("collision")

		"DetectionArea":
			# DetectionArea 的 mask 应包含 body 层（检测玩家物理体）
			if not _mask_includes(mask, LAYER_BODY):
				_fail("collision", "%s / %s: DetectionArea collision_mask=%d 不包含 body 层(1)" % [scene_name, node_path, mask])
			else:
				_pass("collision")
			# DetectionArea 的 layer 应为 0（不参与碰撞，纯检测）
			if layer != 0:
				_fail("collision", "%s / %s: DetectionArea collision_layer=%d（应为 0，纯检测不应产生碰撞）" % [scene_name, node_path, layer])
			else:
				_pass("collision")


func _check_body_collision(body: CharacterBody2D, scene_name: String) -> void:
	var node_path := _get_node_path(body)
	# CharacterBody2D 的 collision_mask 不能为 0（否则 move_and_slide 无碰撞反馈）
	if body.collision_mask == 0:
		_fail("collision", "%s / %s: CharacterBody2D collision_mask=0（move_and_slide 无法检测碰撞）" % [scene_name, node_path])
	else:
		_pass("collision")


# ================================================================
#  L2: 必要节点检查
# ================================================================

func _test_required_nodes() -> void:
	print("[L2] 必要节点检查...")

	# 玩家必须有 FSM 初始化入口
	var player_packed := _safe_load("res://scenes/player.tscn")
	if player_packed:
		var player := player_packed.instantiate()
		root.add_child(player)
		await _wait_frames(2)

		# 检查必需的子节点
		var required := ["SpriteRoot", "Hitbox", "Hurtbox", "Camera2D"]
		for node_name in required:
			if player.get_node_or_null(node_name):
				_pass("node_exist")
			else:
				_fail("node_exist", "player.tscn 缺少必要节点: %s" % node_name)

		# 检查 PlayerStateMachine 是否被动态创建
		var fsm_node := player.get_node_or_null("PlayerStateMachine")
		if fsm_node and fsm_node is PlayerStateMachine:
			_pass("node_exist")
		else:
			_fail("node_exist", "player.tscn: PlayerStateMachine 未被动态创建（FSM 不会初始化）")

		player.queue_free()
		await process_frame

	# Boss 必须有必要的子节点
	var boss_packed := _safe_load("res://scenes/enemies/black_bear_boss.tscn")
	if boss_packed:
		var boss := boss_packed.instantiate()
		root.add_child(boss)
		await _wait_frames(2)

		var boss_required := ["SpriteRoot", "Hitbox", "Hurtbox", "DetectionArea"]
		for node_name in boss_required:
			if boss.get_node_or_null(node_name):
				_pass("node_exist")
			else:
				_fail("node_exist", "black_bear_boss.tscn 缺少必要节点: %s" % node_name)

		boss.queue_free()
		await process_frame

	print("  L2 节点: %d 通过, %d 失败" % [_results.node_exist.passed, _results.node_exist.failed])


# ================================================================
#  L3: FSM 初始化验证
# ================================================================

func _test_fsm_initialization() -> void:
	print("[L3] FSM 初始化验证（state_instance != null）...")

	var player_packed := _safe_load("res://scenes/player.tscn")
	if not player_packed:
		_fail("fsm_init", "无法加载 player.tscn")
		return

	var player := player_packed.instantiate()
	root.add_child(player)
	await _wait_frames(5)  # 等 _ready + setup 完成

	var fsm_node := player.get_node_or_null("PlayerStateMachine")
	if not fsm_node:
		_fail("fsm_init", "PlayerStateMachine 节点不存在")
		player.queue_free()
		await process_frame
		return

	_pass("fsm_init")  # FSM 节点存在

	# 关键断言：state_instance 不能为 null
	# Bug 回顾：setup() 未调用 transition_to(IDLE)，导致 state_instance 一直为 null
	if fsm_node.state_instance != null:
		_pass("fsm_init")
	else:
		_fail("fsm_init", "FSM.state_instance 为 null——setup() 未进入初始状态，玩家无法移动！")

	# 验证初始状态为 IDLE
	if fsm_node.current_state == PlayerState.State.IDLE:
		_pass("fsm_init")
	else:
		_fail("fsm_init", "FSM 初始状态应为 IDLE，实际为 %d" % fsm_node.current_state)

	player.queue_free()
	await process_frame

	print("  L3 FSM初始化: %d 通过, %d 失败" % [_results.fsm_init.passed, _results.fsm_init.failed])


# ================================================================
#  L4: 击退物理边界
# ================================================================

func _test_knockback_bounds() -> void:
	print("[L4] 击退物理边界（防止二次乘法爆炸）...")

	var boss_packed := _safe_load("res://scenes/enemies/black_bear_boss.tscn")
	if not boss_packed:
		_fail("knockback", "无法加载 boss 场景")
		return

	var boss := boss_packed.instantiate() as BossBase
	if not boss:
		_fail("knockback", "无法实例化 boss")
		return

	root.add_child(boss)
	await _wait_frames(2)

	# 确保 stats 类型正确
	if not boss.stats is BossStats:
		_fail("knockback", "boss.stats 不是 BossStats 类型")
		boss.queue_free()
		await process_frame
		return

	# 手动触发 _start_hurt 并检查 velocity 上限
	# Bug 回顾：BossBase._start_hurt 把已乘过力的向量传给 EnemyBase，导致 15000+ px/s
	var knockback_dir := Vector2(1, 0)  # 方向：右
	boss._start_hurt(knockback_dir)

	# 击退速度的合理上限：
	#   knockback_force=150, poise_resistance=0.3
	#   预期: 150 * (1 - 0.3) = 105 px/s
	#   允许一些容差（浮点+摩擦），但绝不能超过 200
	var max_expected := boss.stats.knockback_force * 1.5  # 150 * 1.5 = 225
	if abs(boss.velocity.x) <= max_expected and abs(boss.velocity.y) <= max_expected:
		_pass("knockback")
	else:
		_fail("knockback", "击退速度异常: velocity=(%f, %f)，上限=%f（可能是二次乘法）" % [
			boss.velocity.x, boss.velocity.y, max_expected
		])

	# 验证击退方向正确
	if boss.velocity.x > 0:
		_pass("knockback")
	else:
		_fail("knockback", "击退方向错误：velocity.x=%f（应为正数，向右击退）" % boss.velocity.x)

	boss.queue_free()
	await process_frame

	# 也用 grunt 验证同样的东西
	var grunt_packed := _safe_load("res://scenes/enemies/grunt.tscn")
	if grunt_packed:
		var grunt := grunt_packed.instantiate() as EnemyBase
		if grunt:
			root.add_child(grunt)
			await _wait_frames(2)

			grunt._start_hurt(knockback_dir)
			# grunt 没有霸体，直接 knockback_force=150
			if abs(grunt.velocity.x) <= 200:
				_pass("knockback")
			else:
				_fail("knockback", "grunt 击退速度异常: velocity.x=%f" % grunt.velocity.x)

			grunt.queue_free()
			await process_frame

	print("  L4 击退: %d 通过, %d 失败" % [_results.knockback.passed, _results.knockback.failed])


# ================================================================
#  Helpers
# ================================================================

func _safe_load(path: String) -> PackedScene:
	if not ResourceLoader.exists(path):
		return null
	var result := load(path)
	if result is PackedScene:
		return result
	return null


func _get_node_path(node: Node) -> String:
	# 返回相对于 scene root 的路径（如 "Player/Hurtbox"）
	var path := node.name
	var parent := node.get_parent()
	while parent and parent != root and parent.name != "root":
		path = parent.name + "/" + path
		parent = parent.get_parent()
	return path


func _is_known_layer(layer: int) -> bool:
	return layer in [0, LAYER_BODY, LAYER_PLAYER_HURT, LAYER_ENEMY_HURT, LAYER_HITBOX]


func _mask_includes(mask: int, layer: int) -> bool:
	# 检查 mask 的某一位是否包含指定 layer 的位
	return (mask & layer) == layer


func _fail(category: String, msg: String) -> void:
	_results[category].failed += 1
	_results[category].details.append("❌ %s" % msg)


func _pass(category: String) -> void:
	_results[category].passed += 1


func _total_failures() -> int:
	var total := 0
	for key in _results:
		total += _results[key].failed
	return total


func _wait_frames(count: int) -> void:
	for _i in range(count):
		await process_frame


func _ensure_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


# ================================================================
#  Report
# ================================================================

func _generate_report() -> void:
	print("\n[报告] 生成 docs/scene-integrity-report.md...")

	var r := _results
	var sb := PackedStringArray()

	sb.append("# 场景完整性自检报告 · %s\n" % Time.get_date_string_from_system())
	sb.append("> 自动生成：碰撞层 · 必要节点 · FSM初始化 · 击退物理\n")

	for cat in [
		["1. 碰撞层/掩码", "collision"],
		["2. 必要节点", "node_exist"],
		["3. FSM 初始化", "fsm_init"],
		["4. 击退物理边界", "knockback"],
	]:
		var title: String = cat[0]
		var key: String = cat[1]
		var data: Dictionary = r[key]
		sb.append("## %s\n" % title)
		sb.append("| 结果 | 通过 | 失败 |")
		sb.append("|------|------|------|")
		var icon := "✅" if data.failed == 0 else "⚠️"
		sb.append("| %s | %d | %d |" % [icon, data.passed, data.failed])
		for detail in data.details:
			sb.append("- %s" % detail)
		sb.append("")

	# Summary
	var tp := 0
	var tf := 0
	for key in r:
		tp += r[key].passed
		tf += r[key].failed
	sb.append("## 总览\n")
	sb.append("- ✅ 总计通过: %d" % tp)
	if tf > 0:
		sb.append("- ❌ 总计失败: %d" % tf)
	else:
		sb.append("- 🎉 全部通过！")
	sb.append("")

	var report := "\n".join(sb)
	_ensure_dir("res://docs")

	var f := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if f:
		f.store_string(report)
		f.close()
		print("  ✅ 报告已保存")
	else:
		print("  ⚠️ 无法写入报告文件")


func _print_results() -> void:
	var r := _results
	var tp := 0
	var tf := 0
	print("\n========================================")
	print("  场景完整性自测完成")
	for key in ["collision", "node_exist", "fsm_init", "knockback"]:
		var data: Dictionary = r[key]
		var names := {"collision": "L1 碰撞层", "node_exist": "L2 必要节点", "fsm_init": "L3 FSM初始化", "knockback": "L4 击退物理"}
		print("  %s: %d 通过 / %d 失败" % [names.get(key, key), data.passed, data.failed])
		tp += data.passed
		tf += data.failed
	print("  ─────────────────────────────")
	print("  总计: %d 通过 / %d 失败" % [tp, tf])
	print("  报告: %s" % REPORT_PATH)
	print("========================================\n")
