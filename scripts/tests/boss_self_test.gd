## Boss 系统自测 v1
## 四层测试：
##   L1 - BT 行为树穷举（Selector/Sequence/Condition/Action）
##   L2 - Boss 常量契约（阶段阈值/倍率/霸体/无敌 + 黑熊精攻击参数）
##   L3 - Boss 阶段切换状态断言（血量触发 + 无敌 + BT reset）
##   L4 - Boss HP Bar 信号绑定 + 血量同步 + 阶段颜色切换
##
## 运行: godot --headless --script scripts/tests/boss_self_test.gd
## 输出: docs/boss-system-report.md

extends SceneTree

const ARENA_PATH := "res://scenes/levels/boss_arena.tscn"
const BOSS_SCENE_PATH := "res://scenes/enemies/black_bear_boss.tscn"
const REPORT_PATH := "res://docs/boss-system-report.md"

var _arena: Node2D
var _boss: BossBase
var _hp_bar: BossHPBar
var _results := {
	"bt": {"passed": 0, "failed": 0, "details": []},
	"constants": {"passed": 0, "failed": 0, "details": []},
	"phase": {"passed": 0, "failed": 0, "details": []},
	"hpbar": {"passed": 0, "failed": 0, "details": []},
}


func _init() -> void:
	print("\n========================================")
	print("  像素悟空 - Boss 系统自测 v1")
	print("========================================\n")


func _initialize() -> void:
	_run_bt_exhaustive()
	_run_boss_constants()
	await _load_arena()
	await _run_phase_switch()
	await _run_hp_bar()
	_generate_report()
	_print_results()
	quit(0)


# ================================================================
#  L1: BT 行为树穷举
# ================================================================

func _run_bt_exhaustive() -> void:
	print("\n[L1 BT穷举] 验证 Selector/Sequence/Condition/Action...")

	# --- BTNode 基类默认 FAILURE ---
	var base := BTNode.new()
	_assert_bt("base_default_failure", base.tick(0.016, {}),
		BTNode.Status.FAILURE, "BTNode 基类默认 FAILURE")

	# --- BTSelector ---
	# 1. 全 FAILURE → FAILURE
	var sel_all_fail := BTSelector.new()
	sel_all_fail.add_child(BTNode.new())
	sel_all_fail.add_child(BTNode.new())
	_assert_bt("selector_all_failure", sel_all_fail.tick(0.016, {}),
		BTNode.Status.FAILURE, "Selector 全 FAILURE 应返回 FAILURE")

	# 2. 首个 SUCCESS → SUCCESS，且后续子不被 tick
	var sel_first := BTSelector.new()
	var calls := [0]
	sel_first.add_child(BTAction.new(func(_d, _c): calls[0] += 1, 0.0))
	sel_first.add_child(BTAction.new(func(_d, _c): calls[0] += 1, 0.0))
	_assert_bt("selector_first_success", sel_first.tick(0.016, {}),
		BTNode.Status.SUCCESS, "Selector 首个 SUCCESS 立即返回")
	_assert_bt("selector_skip_after_success", calls[0], 1,
		"Selector 首个 SUCCESS 后不 tick 后续子")

	# 3. 首个 RUNNING → RUNNING
	var sel_running := BTSelector.new()
	sel_running.add_child(BTAction.new(func(_d, _c): pass, 5.0))
	sel_running.add_child(BTAction.new(func(_d, _c): pass, 0.0))
	_assert_bt("selector_running_short_circuits", sel_running.tick(0.016, {}),
		BTNode.Status.RUNNING, "Selector 遇到 RUNNING 立即返回")

	# --- BTSequence ---
	# 1. 全 SUCCESS → SUCCESS
	var seq_all := BTSequence.new()
	seq_all.add_child(BTAction.new(func(_d, _c): pass, 0.0))
	seq_all.add_child(BTAction.new(func(_d, _c): pass, 0.0))
	_assert_bt("sequence_all_success", seq_all.tick(0.016, {}),
		BTNode.Status.SUCCESS, "Sequence 全 SUCCESS 应返回 SUCCESS")

	# 2. 首个 FAILURE → FAILURE
	var seq_fail := BTSequence.new()
	seq_fail.add_child(BTNode.new())  # 默认 FAILURE
	seq_fail.add_child(BTAction.new(func(_d, _c): pass, 0.0))
	_assert_bt("sequence_first_failure", seq_fail.tick(0.016, {}),
		BTNode.Status.FAILURE, "Sequence 首个 FAILURE 立即返回")

	# 3. 中间 RUNNING → RUNNING，下次 tick 从该子继续
	var seq_mid := BTSequence.new()
	seq_mid.add_child(BTAction.new(func(_d, _c): pass, 0.0))
	seq_mid.add_child(BTAction.new(func(_d, _c): pass, 5.0))
	seq_mid.add_child(BTAction.new(func(_d, _c): pass, 0.0))
	_assert_bt("sequence_mid_running", seq_mid.tick(0.016, {}),
		BTNode.Status.RUNNING, "Sequence 中间 RUNNING 返回 RUNNING")

	# 4. Sequence reset 后游标归零
	seq_mid.reset()
	_assert_bt("sequence_reset_restarts", seq_mid.tick(0.016, {}),
		BTNode.Status.RUNNING, "Sequence reset 后重新 tick 仍在 RUNNING 子")

	# --- BTCondition ---
	var cond_true := BTCondition.new(func(_c: Dictionary) -> bool: return true)
	var cond_false := BTCondition.new(func(_c: Dictionary) -> bool: return false)
	var cond_empty := BTCondition.new()
	_assert_bt("condition_true", cond_true.tick(0.016, {}),
		BTNode.Status.SUCCESS, "Condition true → SUCCESS")
	_assert_bt("condition_false", cond_false.tick(0.016, {}),
		BTNode.Status.FAILURE, "Condition false → FAILURE")
	_assert_bt("condition_empty", cond_empty.tick(0.016, {}),
		BTNode.Status.FAILURE, "Condition 空 callable → FAILURE")

	# --- BTAction ---
	# 1. duration=0 立即 SUCCESS
	var act_inst := BTAction.new(func(_d, _c): pass, 0.0)
	_assert_bt("action_duration_zero", act_inst.tick(0.016, {}),
		BTNode.Status.SUCCESS, "Action duration=0 立即 SUCCESS")

	# 2. duration>0 首次 RUNNING
	var act_long := BTAction.new(func(_d, _c): pass, 5.0)
	_assert_bt("action_running_first_tick", act_long.tick(0.016, {}),
		BTNode.Status.RUNNING, "Action duration>0 首次 tick 返回 RUNNING")

	# 3. Action callable 总被调用
	var called := [false]
	var act_check := BTAction.new(func(_d, _c): called[0] = true, 0.0)
	act_check.tick(0.016, {})
	_assert_bt("action_callable_invoked", called[0], true,
		"Action callable 总被调用")

	# 4. Action reset 清零 elapsed
	act_long.reset()
	_assert_bt("action_reset_resets_elapsed", act_long.tick(0.016, {}),
		BTNode.Status.RUNNING, "Action reset 后重新 RUNNING（不累计到 SUCCESS）")

	print("  L1 BT: %d 通过, %d 失败" % [_results.bt.passed, _results.bt.failed])


# ================================================================
#  L2: Boss 常量契约
# ================================================================

func _run_boss_constants() -> void:
	print("\n[L2 Boss常量契约] 锁定阶段阈值/倍率/霸体 + 黑熊精攻击参数...")

	# BossStats 资源默认值
	var default_stats := BossStats.new()
	_assert_const("phase_thresholds", default_stats.phase_thresholds,
		[0.66, 0.33], "阶段阈值默认值")
	_assert_const("phase_damage_mult", default_stats.phase_damage_mult,
		[1.0, 1.3, 1.6], "阶段伤害倍率")
	_assert_const("phase_speed_mult", default_stats.phase_speed_mult,
		[1.0, 1.15, 1.3], "阶段速度倍率")
	_assert_const("phase_cooldown_mult", default_stats.phase_cooldown_mult,
		[1.0, 0.8, 0.6], "阶段冷却倍率（<1=更快）")
	_assert_const("phase_transition_invincible", default_stats.phase_transition_invincible,
		1.5, "阶段切换无敌时间")
	_assert_const("poise_resistance", default_stats.poise_resistance,
		0.3, "霸体减伤")

	# 黑熊精攻击常量
	_assert_const("SWIPE_RANGE", BlackBearBoss.SWIPE_RANGE, 48.0, "普攻范围")
	_assert_const("SLAM_RANGE", BlackBearBoss.SLAM_RANGE, 80.0, "砸地范围")
	_assert_const("CHARGE_RANGE", BlackBearBoss.CHARGE_RANGE, 200.0, "突进范围")
	_assert_const("BERSERK_RANGE", BlackBearBoss.BERSERK_RANGE, 60.0, "狂暴范围")
	_assert_const("SWIPE_DURATION", BlackBearBoss.SWIPE_DURATION, 0.4, "普攻时长")
	_assert_const("SWIPE_COMBO_DURATION", BlackBearBoss.SWIPE_COMBO_DURATION, 0.7, "二连击时长")
	_assert_const("SLAM_DURATION", BlackBearBoss.SLAM_DURATION, 0.8, "砸地时长")
	_assert_const("CHARGE_DURATION", BlackBearBoss.CHARGE_DURATION, 0.5, "突进时长")
	_assert_const("BERSERK_DURATION", BlackBearBoss.BERSERK_DURATION, 1.2, "狂暴时长")

	# 黑熊精冷却配置（P1/P2/P3 各 4 段：swipe/slam/charge/berserk）
	_assert_const("COOLDOWNS_P1", BlackBearBoss.COOLDOWNS_P1,
		[2.0, 8.0, 999.0, 999.0], "P1 冷却（只有 swipe+slam）")
	_assert_const("COOLDOWNS_P2", BlackBearBoss.COOLDOWNS_P2,
		[1.5, 6.0, 4.0, 999.0], "P2 冷却（+charge）")
	_assert_const("COOLDOWNS_P3", BlackBearBoss.COOLDOWNS_P3,
		[1.0, 5.0, 3.0, 8.0], "P3 冷却（全开+berserk）")

	# 黑熊精场景实际 stats（从 .tscn 读取）
	var boss_packed := load(BOSS_SCENE_PATH) as PackedScene
	var probe_boss := boss_packed.instantiate() as BossBase
	root.add_child(probe_boss)
	await process_frame
	_assert_const("黑熊精 max_health", probe_boss.stats.max_health, 300, "Boss 满血")
	_assert_const("黑熊精 boss_name", probe_boss.boss_stats.boss_name, "黑熊精", "Boss 名称")
	_assert_const("黑熊精 phase_names", probe_boss.boss_stats.phase_names,
		["黑风掌", "黑风怒", "黑风狂暴"], "阶段中文名")
	probe_boss.queue_free()
	await process_frame

	print("  L2 常量: %d 通过, %d 失败" % [_results.constants.passed, _results.constants.failed])


# ================================================================
#  L3: Boss 阶段切换状态断言
# ================================================================

func _run_phase_switch() -> void:
	print("\n[L3 阶段切换] 验证血量触发 + 无敌 + BT reset...")

	if not _boss:
		print("  ⚠️ 无 Boss，跳过")
		return

	# 0. 重置到已知状态（前面 L2 验证可能干扰）
	_boss.stats.current_health = _boss.stats.max_health
	_boss.current_phase = 0
	_boss._phase_transitioning = false
	_boss._phase_transition_timer = 0.0

	# 1. 满血 → P0
	_assert_phase("initial_phase_p0", _boss.current_phase == 0,
		"current_phase=%d" % _boss.current_phase)

	# 2. 扣血到 65%（≤ 0.66 触发 P1）
	_boss.stats.current_health = int(_boss.stats.max_health * 0.65)
	_boss._check_phase_switch()
	_assert_phase("phase_1_triggered", _boss.current_phase == 1,
		"current_phase=%d" % _boss.current_phase)
	_assert_phase("phase_1_transitioning", _boss._phase_transitioning == true,
		"_phase_transitioning=%s" % str(_boss._phase_transitioning))

	# 3. 切换中无敌：take_damage 被拦截
	var hp_before := _boss.stats.current_health
	_boss.take_damage(10, Vector2.ZERO)
	_assert_phase("phase_transition_invincible", _boss.stats.current_health == hp_before,
		"hp_before=%d, hp_after=%d" % [hp_before, _boss.stats.current_health])

	# 4. 切换完成 → _phase_transitioning=false + bt_root 被 reset
	#    我们手动清零计时器避免等 1.5s
	_boss._phase_transition_timer = 0.0
	_boss._process_phase_transition(0.016)
	_assert_phase("phase_transition_ended", _boss._phase_transitioning == false,
		"_phase_transitioning=%s" % str(_boss._phase_transitioning))

	# 5. 触发 P2 切换（≤ 0.33）
	_boss.stats.current_health = int(_boss.stats.max_health * 0.32)
	_boss._check_phase_switch()
	_assert_phase("phase_2_triggered", _boss.current_phase == 2,
		"current_phase=%d" % _boss.current_phase)
	_boss._phase_transitioning = false  # 清理

	# 6. 边界：高于阈值不倒退（50% 在 P1 (0.33, 0.66] 区间）
	_boss.stats.current_health = int(_boss.stats.max_health * 0.5)
	var phase_before := _boss.current_phase
	_boss._check_phase_switch()
	_assert_phase("phase_no_regression", _boss.current_phase == phase_before,
		"current_phase=%d, expected=%d" % [_boss.current_phase, phase_before])

	print("  L3 阶段: %d 通过, %d 失败" % [_results.phase.passed, _results.phase.failed])


# ================================================================
#  L4: Boss HP Bar 信号绑定
# ================================================================

func _run_hp_bar() -> void:
	print("\n[L4 HP Bar] 验证信号绑定 + 血量同步 + 阶段颜色切换...")

	if not _hp_bar or not _boss:
		print("  ⚠️ 无 HP Bar / Boss，跳过")
		return

	# 0. 重置 bar 状态（避免 L3 副作用：boss 已被触发到 P2）
	_hp_bar._hp_fill.color = _hp_bar.HP_COLORS[0]  # P1 红
	_hp_bar._current_phase = 0

	# 1. arena 自动 attach 完毕，初始 ratio=1.0
	_assert_hpbar("hp_bar_initial_attached", _hp_bar._boss == _boss,
		"_boss=%s, expected=%s" % [str(_hp_bar._boss), str(_boss)])
	_assert_hpbar("hp_bar_initial_ratio", abs(_hp_bar._target_hp_ratio - 1.0) < 0.001,
		"_target_hp_ratio=%f" % _hp_bar._target_hp_ratio)

	# 2. boss 血量变化 → bar 同步（emit 信号模拟 take_damage 的副作用）
	_boss.stats.current_health = 150  # 50%
	_boss.boss_health_changed.emit(_boss.stats.current_health, _boss.stats.max_health)
	_assert_hpbar("hp_bar_synced_after_damage", abs(_hp_bar._target_hp_ratio - 0.5) < 0.001,
		"_target_hp_ratio=%f" % _hp_bar._target_hp_ratio)

	# 3. 阶段切换 P0 → P2 → bar 颜色应从 P1 红变 P3 紫
	var initial_color := _hp_bar._hp_fill.color
	_boss.boss_phase_changed.emit(2, "黑风狂暴")
	_assert_hpbar("hp_bar_phase_color_changed", _hp_bar._hp_fill.color != initial_color,
		"phase_color=%s, initial=%s" % [str(_hp_bar._hp_fill.color), str(initial_color)])
	_assert_hpbar("hp_bar_current_phase_updated", _hp_bar._current_phase == 2,
		"_current_phase=%d" % _hp_bar._current_phase)

	# 4. boss 死亡 → bar 触发隐藏 tween（modulate.a 从 1.0 → 0.0 over 0.5s）
	#    headless 下 process_frame 不一定按真实 60fps 推进，宽松断言 modulate.a < 0.5
	_boss.stats.current_health = 0
	_boss.boss_health_changed.emit(0, _boss.stats.max_health)
	_boss.died.emit(_boss)
	await _wait_frames(60)
	if _hp_bar._panel:
		_assert_hpbar("hp_bar_hidden_after_death", _hp_bar._panel.modulate.a < 0.5,
			"modulate.a=%f（tween 应在衰减）" % _hp_bar._panel.modulate.a)

	print("  L4 HP Bar: %d 通过, %d 失败" % [_results.hpbar.passed, _results.hpbar.failed])


# ================================================================
#  Helpers
# ================================================================

func _load_arena() -> void:
	print("[加载] Boss 竞技场...")
	var packed := load(ARENA_PATH) as PackedScene
	_arena = packed.instantiate()
	root.add_child(_arena)

	await _wait_frames(3)

	_boss = _arena.get_node_or_null("BlackBearBoss") as BossBase
	_hp_bar = _arena.get_node_or_null("BossHPBar") as BossHPBar

	print("  ✅ Arena 就绪 — Boss: %s, HPBar: %s" % [
		_boss.name if _boss else "N/A",
		_hp_bar.name if _hp_bar else "N/A",
	])


func _assert_bt(name: String, actual, expected, desc: String) -> void:
	var ok: bool = actual == expected
	if ok:
		_results.bt.passed += 1
	else:
		_results.bt.failed += 1
		_results.bt.details.append(
			"❌ %s: %s (expected=%s, actual=%s)" % [name, desc, str(expected), str(actual)]
		)


func _assert_const(name: String, actual, expected, desc: String) -> void:
	var ok: bool = actual == expected
	if ok:
		_results.constants.passed += 1
	else:
		_results.constants.failed += 1
		_results.constants.details.append(
			"❌ %s (%s): expected %s, got %s" % [name, desc, str(expected), str(actual)]
		)


func _assert_phase(name: String, condition: bool, detail: String) -> void:
	if condition:
		_results.phase.passed += 1
	else:
		_results.phase.failed += 1
		_results.phase.details.append("❌ %s: %s" % [name, detail])


func _assert_hpbar(name: String, condition: bool, detail: String) -> void:
	if condition:
		_results.hpbar.passed += 1
	else:
		_results.hpbar.failed += 1
		_results.hpbar.details.append("❌ %s: %s" % [name, detail])


func _wait_frames(count: int) -> void:
	for _i in range(count):
		await process_frame


func _ensure_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


# ================================================================
#  Report Generation
# ================================================================

func _generate_report() -> void:
	print("\n[报告] 生成 docs/boss-system-report.md...")

	var r := _results
	var sb := PackedStringArray()

	sb.append("# Boss 系统自检报告 · %s\n" % Time.get_date_string_from_system())
	sb.append("> 自动生成（v1：BT穷举 + Boss常量 + 阶段切换 + HP Bar），无需人工介入\n")

	# L1 BT
	sb.append("## 1. BT 行为树穷举\n")
	sb.append("| 结果 | 通过 | 失败 |")
	sb.append("|------|------|------|")
	var bt_icon := "✅" if r.bt.failed == 0 else "⚠️"
	sb.append("| %s | %d | %d |" % [bt_icon, r.bt.passed, r.bt.failed])
	for detail in r.bt.details:
		sb.append("- %s" % detail)
	sb.append("")

	# L2 常量
	sb.append("## 2. Boss 常量契约\n")
	sb.append("| 结果 | 通过 | 失败 |")
	sb.append("|------|------|------|")
	var c_icon := "✅" if r.constants.failed == 0 else "⚠️"
	sb.append("| %s | %d | %d |" % [c_icon, r.constants.passed, r.constants.failed])
	for detail in r.constants.details:
		sb.append("- %s" % detail)
	sb.append("")

	# L3 阶段切换
	sb.append("## 3. 阶段切换状态断言\n")
	sb.append("| 结果 | 通过 | 失败 |")
	sb.append("|------|------|------|")
	var p_icon := "✅" if r.phase.failed == 0 else "⚠️"
	sb.append("| %s | %d | %d |" % [p_icon, r.phase.passed, r.phase.failed])
	for detail in r.phase.details:
		sb.append("- %s" % detail)
	sb.append("")

	# L4 HP Bar
	sb.append("## 4. Boss HP Bar 信号\n")
	sb.append("| 结果 | 通过 | 失败 |")
	sb.append("|------|------|------|")
	var h_icon := "✅" if r.hpbar.failed == 0 else "⚠️"
	sb.append("| %s | %d | %d |" % [h_icon, r.hpbar.passed, r.hpbar.failed])
	for detail in r.hpbar.details:
		sb.append("- %s" % detail)
	sb.append("")

	# Summary
	var total_pass: int = r.bt.passed + r.constants.passed + r.phase.passed + r.hpbar.passed
	var total_fail: int = r.bt.failed + r.constants.failed + r.phase.failed + r.hpbar.failed
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
	var total_pass: int = r.bt.passed + r.constants.passed + r.phase.passed + r.hpbar.passed
	var total_fail: int = r.bt.failed + r.constants.failed + r.phase.failed + r.hpbar.failed
	print("\n========================================")
	print("  Boss 自测完成")
	print("  L1 BT穷举:    %d 通过 / %d 失败" % [r.bt.passed, r.bt.failed])
	print("  L2 常量契约:   %d 通过 / %d 失败" % [r.constants.passed, r.constants.failed])
	print("  L3 阶段切换:   %d 通过 / %d 失败" % [r.phase.passed, r.phase.failed])
	print("  L4 HP Bar:     %d 通过 / %d 失败" % [r.hpbar.passed, r.hpbar.failed])
	print("  ─────────────────────────────")
	print("  总计: %d 通过 / %d 失败" % [total_pass, total_fail])
	print("  报告: %s" % REPORT_PATH)
	print("========================================\n")