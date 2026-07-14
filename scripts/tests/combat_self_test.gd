## 战斗手感自测框架 v2
## 三层测试：
##   L1 - FSM 状态转换穷举（查表验证）
##   L2 - 战斗常量契约 + Combo 伤害真实验证
##   L3 - 状态断言（替代 headless 下不可用的截图）
##
## 重构（2026-07-10, review by 砚砚）：
##   L2 原为手抄源码常量自算自判（假测试），改为读 player 真实属性绑定契约
##   L3 原为 headless 截图（无渲染器 + 无法自动断言），改为纯状态/数据断言
## 输出: docs/combat-feel-report.md
##
## 运行: godot --headless --script scripts/tests/combat_self_test.gd

extends SceneTree

const TEST_LEVEL := "res://scenes/levels/test_level.tscn"
const REPORT_PATH := "res://docs/combat-feel-report.md"

var _scene: Node2D
var _player: CharacterBody2D
var _fsm: PlayerStateMachine
var _results := {
	"fsm": {"passed": 0, "failed": 0, "details": []},
	"constants": {"passed": 0, "failed": 0, "details": []},
	"combo": {"passed": 0, "failed": 0, "details": [], "values": []},
	"state": {"passed": 0, "failed": 0, "details": []},
}


func _init() -> void:
	print("\n========================================")
	print("  像素悟空 - 战斗手感自测 v2")
	print("========================================\n")


func _initialize() -> void:
	_load_hitstop_class()
	await _load_scene()
	await _run_fsm_exhaustive()
	_run_constant_contract()
	await _run_combo_damage()
	await _run_state_assertions()
	_generate_report()
	_print_results()
	quit(0)


func _load_hitstop_class() -> void:
	var _unused = preload("res://scripts/utils/hit_stop.gd")


# ================================================================
#  Scene loading
# ================================================================

func _load_scene() -> void:
	print("[加载] 测试关卡...")
	var packed := load(TEST_LEVEL) as PackedScene
	if not packed:
		_scene = Node2D.new()
		root.add_child(_scene)
		print("  ⚠️ 无法加载场景，创建空场景")
	else:
		_scene = packed.instantiate()
		root.add_child(_scene)

	await _wait_frames(3)

	var players := _scene.get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]
		_fsm = _player.get_node_or_null("PlayerStateMachine")
	else:
		print("  ⚠️ 场景中无玩家节点")
		return

	print("  ✅ 场景就绪，玩家: %s, FSM: %s" % [
		_player.name if _player else "N/A",
		_fsm.name if _fsm else "N/A",
	])

	# L0: FSM 初始化完整性（Bug 回顾：setup() 未进入初始状态导致玩家无法移动）
	if _fsm:
		if _fsm.state_instance != null:
			print("  ✅ FSM 已初始化")
		else:
			print("  ❌ FSM.state_instance 为 null！setup() 未进入初始状态！")
		if _fsm.current_state == PlayerState.State.IDLE:
			print("  ✅ FSM 初始状态: IDLE")
		else:
			print("  ❌ FSM 当前状态异常: %d" % _fsm.current_state)


# ================================================================
#  L1: FSM 转换穷举测试（保留，已验证有效）
# ================================================================

func _run_fsm_exhaustive() -> void:
	print("\n[L1 FSM穷举] 验证状态转换表...")
	if not _fsm:
		print("  ⚠️ 无 FSM，跳过")
		return

	var legal_transitions := {
		PlayerState.State.IDLE: [
			[PlayerState.State.RUN, "IDLE→RUN"],
			[PlayerState.State.JUMP_RISE, "IDLE→JUMP_RISE"],
			[PlayerState.State.ATTACK_LIGHT, "IDLE→ATTACK_LIGHT"],
			[PlayerState.State.ATTACK_HEAVY, "IDLE→ATTACK_HEAVY"],
			[PlayerState.State.DODGE, "IDLE→DODGE"],
			[PlayerState.State.BLOCK, "IDLE→BLOCK"],
		],
		PlayerState.State.ATTACK_LIGHT: [
			[PlayerState.State.IDLE, "ATTACK_LIGHT→IDLE"],
			[PlayerState.State.ATTACK_LIGHT, "ATTACK_LIGHT→ATTACK_LIGHT 连招"],
			[PlayerState.State.ATTACK_HEAVY, "ATTACK_LIGHT→ATTACK_HEAVY"],
			[PlayerState.State.DODGE, "ATTACK_LIGHT→DODGE 取消"],
			[PlayerState.State.BLOCK, "ATTACK_LIGHT→BLOCK 取消"],
		],
		PlayerState.State.BLOCK: [
			[PlayerState.State.IDLE, "BLOCK→IDLE"],
			[PlayerState.State.DODGE, "BLOCK→DODGE"],
		],
		PlayerState.State.DODGE: [
			[PlayerState.State.IDLE, "DODGE→IDLE"],
		],
		PlayerState.State.HURT: [
			[PlayerState.State.IDLE, "HURT→IDLE"],
			[PlayerState.State.DEAD, "HURT→DEAD"],
		],
	}

	for from_state in legal_transitions:
		for entry in legal_transitions[from_state]:
			var to_state: int = entry[0]
			var desc: String = entry[1]
			_fsm.current_state = from_state
			if _fsm.can_transition(to_state):
				_results.fsm.passed += 1
			else:
				_results.fsm.failed += 1
				_results.fsm.details.append("❌ 合法转换被拒绝: %s" % desc)

	var illegal_pairs := [
		[PlayerState.State.DODGE, PlayerState.State.ATTACK_LIGHT, "DODGE→ATTACK_LIGHT"],
		[PlayerState.State.DEAD, PlayerState.State.IDLE, "DEAD→IDLE"],
		[PlayerState.State.JUMP_RISE, PlayerState.State.ATTACK_LIGHT, "JUMP_RISE→ATTACK_LIGHT"],
	]
	for entry in illegal_pairs:
		_fsm.current_state = entry[0]
		var ok := _fsm.can_transition(entry[1])
		if not ok:
			_results.fsm.passed += 1
		else:
			_results.fsm.failed += 1
			_results.fsm.details.append("❌ 非法转换被允许: %s" % entry[2])

	await _wait_frames(1)

	# 恢复 FSM 到 IDLE（L1 直接设 current_state 会残留非法状态）
	_fsm.current_state = PlayerState.State.IDLE

	print("  L1: %d 通过, %d 失败" % [_results.fsm.passed, _results.fsm.failed])


# ================================================================
#  L2: 战斗常量契约（读源码真实值，不手抄）
# ================================================================

func _run_constant_contract() -> void:
	print("\n[L2 常量契约] 锁定关键战斗常量...")
	if not _player:
		print("  ⚠️ 无玩家，跳过")
		return

	# 这些是战斗手感的核心常量——改了任何一个都应触发 review
	_assert_const("ATTACK_DURATION", _player.ATTACK_DURATION, 0.25, "轻攻击总时长")
	_assert_const("COMBO_INPUT_START", _player.COMBO_INPUT_START, 0.05, "预输入窗口起点")
	_assert_const("COMBO_INPUT_END", _player.COMBO_INPUT_END, 0.05, "预输入窗口终点")
	_assert_const("COMBO_WINDOW", _player.COMBO_WINDOW, 0.3, "连击窗口")
	_assert_const("HEAVY_ATTACK_DURATION", _player.HEAVY_ATTACK_DURATION, 0.4, "重攻击总时长")
	_assert_const("DODGE_DURATION", _player.DODGE_DURATION, 0.2, "闪避时长")
	_assert_const("HURT_DURATION", _player.HURT_DURATION, 0.3, "受伤硬直时长")
	_assert_const("PERFECT_BLOCK_WINDOW", _player.PERFECT_BLOCK_WINDOW, 0.15, "完美格挡窗口")

	print("  L2常量: %d 通过, %d 失败" % [_results.constants.passed, _results.constants.failed])


# ================================================================
#  L2: Combo 伤害真实验证（走 FSM + 读 get_current_attack_damage）
# ================================================================

func _run_combo_damage() -> void:
	print("\n[L2 Combo伤害] 验证 get_current_attack_damage() 公式...")
	if not _player:
		print("  ⚠️ 无玩家，跳过")
		return

	# 直接测试伤害公式（get_current_attack_damage 是纯函数：
	#   轻攻击: 10 + (attack_combo - 1) * 5
	#   重攻击: 25）
	var p = _player  # 无类型引用，绕过 GDScript 4 对 CharacterBody2D 的属性写限制

	p.last_attack_type = p.AttackType.LIGHT

	var expected := {"combo1": [1, 10], "combo2": [2, 15], "combo3": [3, 20]}
	for key in ["combo1", "combo2", "combo3"]:
		var entry: Array = expected[key]
		p.attack_combo = entry[0] as int
		var actual: int = p.get_current_attack_damage()
		_results.combo.values.append({"label": key, "damage": actual})
		if actual == entry[1]:
			_results.combo.passed += 1
		else:
			_results.combo.failed += 1
			_results.combo.details.append("❌ %s: expected %d, got %d" % [key, entry[1], actual])

	# 重攻击
	p.last_attack_type = p.AttackType.HEAVY
	var heavy_actual: int = p.get_current_attack_damage()
	_results.combo.values.append({"label": "heavy", "damage": heavy_actual})
	if heavy_actual == 25:
		_results.combo.passed += 1
	else:
		_results.combo.failed += 1
		_results.combo.details.append("❌ heavy: expected 25, got %d" % heavy_actual)

	print("  L2Combo: %d 通过, %d 失败" % [_results.combo.passed, _results.combo.failed])


# ================================================================
#  L3: 状态断言（替代 headless 截图）
# ================================================================

func _run_state_assertions() -> void:
	print("\n[L3 状态断言] 验证关键状态转换...")
	if not _player or not _fsm:
		print("  ⚠️ 无玩家/FSM，跳过")
		return

	await _assert_combo_hud()
	await _assert_telegraph()
	await _assert_hit_effect()

	print("  L3: %d 通过, %d 失败" % [_results.state.passed, _results.state.failed])


## 3a: 走完整三连击 → 验证 combo 计数 + 伤害递增
func _assert_combo_hud() -> void:
	var p = _player  # 无类型引用，绕过 GDScript 4 类型写限制
	_fsm.transition_to(PlayerState.State.IDLE)
	await _wait_frames(2)
	p.attack_combo = 0
	p.last_attack_type = p.AttackType.LIGHT

	# 三段 combo，走完整状态机
	var damages: Array[int] = []
	for _i in range(3):
		p.combo_window_timer = p.COMBO_WINDOW
		_fsm.transition_to(PlayerState.State.ATTACK_LIGHT)
		await _wait_frames(2)
		damages.append(p.get_current_attack_damage())

	await _wait_frames(2)

	# 断言 1: combo 计数 = 3
	_assert_state("combo_count_3", p.attack_combo == 3,
		"combo=%d" % p.attack_combo)
	# 断言 2: 伤害递增
	_assert_state("combo_damage_increasing",
		damages.size() >= 3 and damages[0] < damages[1] and damages[1] < damages[2],
		"damages=%s" % str(damages))

	# 回到 IDLE
	_fsm.transition_to(PlayerState.State.IDLE)
	await _wait_frames(2)


## 3b: 通过 AI 路径触发 telegraph（不绕过私有方法）
func _assert_telegraph() -> void:
	var enemies := []
	for child in _scene.get_children():
		if child is EnemyBase and not child.is_dead:
			enemies.append(child)

	if enemies.size() == 0:
		_results.state.details.append("⚠️ 无存活敌人，跳过 telegraph 断言")
		return

	var enemy: EnemyBase = enemies[0]

	# 设置 AI 前置条件：有目标 + 在攻击范围内
	enemy.target = _player
	enemy.global_position = _player.global_position + Vector2(20, 0)
	enemy.facing_right = false  # 面向玩家

	# 走 AI 路径：_physics_process → _process_behavior → _start_attack → telegraph
	enemy._physics_process(0.016)
	await _wait_frames(3)

	_assert_state("telegraph_active", enemy.is_telegraph_active(),
		"enemy telegraph 未激活（AI 路径未触发攻击前摇）")


## 3c: take_damage → 验证受击状态 + 血量下降
func _assert_hit_effect() -> void:
	if not _player.has_method("take_damage"):
		return

	var p = _player  # 无类型引用

	# 确保从 IDLE 开始
	_fsm.transition_to(PlayerState.State.IDLE)
	await _wait_frames(2)

	var hp_before: int = p.current_health
	p.take_damage(15, Vector2(-1, 0))
	await _wait_frames(3)

	# 断言 1: 进入 HURT 状态
	_assert_state("fsm_in_hurt", _fsm.current_state == PlayerState.State.HURT,
		"current_state=%d" % _fsm.current_state)
	# 断言 2: 血量正确减少
	_assert_state("health_reduced", p.current_health == hp_before - 15,
		"expected=%d, actual=%d" % [hp_before - 15, p.current_health])


# ================================================================
#  Helpers
# ================================================================

func _assert_const(name: String, actual, expected, desc: String) -> void:
	var ok: bool = actual == expected
	if ok:
		_results.constants.passed += 1
	else:
		_results.constants.failed += 1
		_results.constants.details.append(
			"❌ %s (%s): expected %s, got %s" % [name, desc, str(expected), str(actual)]
		)


func _assert_state(name: String, condition: bool, detail: String) -> void:
	if condition:
		_results.state.passed += 1
	else:
		_results.state.failed += 1
		_results.state.details.append("❌ %s: %s" % [name, detail])


func _wait_frames(count: int) -> void:
	for _i in range(count):
		await process_frame


func _ensure_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


# ================================================================
#  Report Generation
# ================================================================

func _generate_report() -> void:
	print("\n[报告] 生成 docs/combat-feel-report.md...")

	var r := _results
	var sb := PackedStringArray()

	sb.append("# 战斗手感自检报告 · %s\n" % Time.get_date_string_from_system())
	sb.append("> 自动生成（v2：常量契约 + 状态断言），无需人工介入\n")

	# L1
	sb.append("## 1. FSM 状态转换穷举\n")
	sb.append("| 结果 | 通过 | 失败 |")
	sb.append("|------|------|------|")
	var fsm_icon := "✅" if r.fsm.failed == 0 else "⚠️"
	sb.append("| %s | %d | %d |" % [fsm_icon, r.fsm.passed, r.fsm.failed])
	for detail in r.fsm.details:
		sb.append("- %s" % detail)
	sb.append("")

	# L2a: Constants
	sb.append("## 2. 战斗常量契约\n")
	sb.append("| 结果 | 通过 | 失败 |")
	sb.append("|------|------|------|")
	var const_icon := "✅" if r.constants.failed == 0 else "⚠️"
	sb.append("| %s | %d | %d |" % [const_icon, r.constants.passed, r.constants.failed])
	for detail in r.constants.details:
		sb.append("- %s" % detail)
	sb.append("")

	# L2b: Combo damage
	sb.append("## 3. Combo 伤害验证\n")
	sb.append("| 结果 | 通过 | 失败 |")
	sb.append("|------|------|------|")
	var combo_icon := "✅" if r.combo.failed == 0 else "⚠️"
	sb.append("| %s | %d | %d |" % [combo_icon, r.combo.passed, r.combo.failed])
	if r.combo.values.size() > 0:
		sb.append("")
		sb.append("| 攻击段 | 伤害 |")
		sb.append("|--------|------|")
		for v in r.combo.values:
			sb.append("| %s | %d |" % [v.label, v.damage])
	for detail in r.combo.details:
		sb.append("- %s" % detail)
	sb.append("")

	# L3: State assertions
	sb.append("## 4. 状态断言\n")
	sb.append("| 结果 | 通过 | 失败 |")
	sb.append("|------|------|------|")
	var state_icon := "✅" if r.state.failed == 0 else "⚠️"
	sb.append("| %s | %d | %d |" % [state_icon, r.state.passed, r.state.failed])
	for detail in r.state.details:
		sb.append("- %s" % detail)
	sb.append("")

	# Summary
	var total_pass: int = r.fsm.passed + r.constants.passed + r.combo.passed + r.state.passed
	var total_fail: int = r.fsm.failed + r.constants.failed + r.combo.failed + r.state.failed
	sb.append("## 5. 总览\n")
	sb.append("- ✅ 总计通过: %d" % total_pass)
	if total_fail > 0:
		sb.append("- ❌ 总计失败: %d" % total_fail)
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
	var total_pass: int = r.fsm.passed + r.constants.passed + r.combo.passed + r.state.passed
	var total_fail: int = r.fsm.failed + r.constants.failed + r.combo.failed + r.state.failed
	print("\n========================================")
	print("  自测完成")
	print("  L1 FSM:       %d 通过 / %d 失败" % [r.fsm.passed, r.fsm.failed])
	print("  L2 常量契约:   %d 通过 / %d 失败" % [r.constants.passed, r.constants.failed])
	print("  L2 Combo伤害: %d 通过 / %d 失败" % [r.combo.passed, r.combo.failed])
	print("  L3 状态断言:   %d 通过 / %d 失败" % [r.state.passed, r.state.failed])
	print("  ─────────────────────────────")
	print("  总计: %d 通过 / %d 失败" % [total_pass, total_fail])
	print("  报告: %s" % REPORT_PATH)
	print("========================================\n")
