#!/usr/bin/env bash
## 像素悟空 - 全量自动化测试聚合器
## 运行: bash scripts/tests/run_all_tests.sh
## 每个测试独立运行，汇总结果
##
## 兼容性：macOS (bash 3.2) / Linux (bash 4+) / CI
##   - 使用索引数组（不用关联数组，bash 3.2 不支持）
##   - timeout → 优先 gtimeout，其次 timeout，都没有则直跑（无超时保护）

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"

# macOS 兼容 timeout 检测（brew install coreutils → gtimeout）
TIMEOUT_CMD=""
if command -v gtimeout &>/dev/null; then
	TIMEOUT_CMD="gtimeout"
elif command -v timeout &>/dev/null; then
	TIMEOUT_CMD="timeout"
fi

TOTAL_PASS=0
TOTAL_FAIL=0
FAILED_TESTS=""

echo ""
echo "========================================"
echo "  像素悟空 - 全量自动化测试"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"
echo ""

# 测试列表：索引数组（偶数下标=名称，奇数下标=脚本路径）
# bash 3.2 兼容 —— 不用关联数组
TESTS=(
	"场景完整性(碰撞层+FSM+击退)"  "scripts/tests/scene_integrity_test.gd"
	"战斗手感自测(FSM+常量+Combo)"  "scripts/tests/combat_self_test.gd"
	"Boss系统自测(BT+阶段+HPBar)"   "scripts/tests/boss_self_test.gd"
	"死亡系统测试"                  "scripts/tests/death_system_test.gd"
	"行为冒烟(玩家移动+FSM启动)"    "scripts/tests/behavior_smoke_test.gd"
)

run_test() {
	local name="$1"
	local script="$2"

	echo "----------------------------------------"
	echo "  [$name]"
	echo "  $script"
	echo "----------------------------------------"

	cd "$PROJECT_DIR"

	local exit_code=0

	if [ -n "$TIMEOUT_CMD" ]; then
		"$TIMEOUT_CMD" 120 "$GODOT_BIN" --headless --script "$script" 2>&1 || exit_code=$?
	else
		# macOS 无 timeout 命令：直跑（大多数测试 10-30s 完成）
		"$GODOT_BIN" --headless --script "$script" 2>&1 || exit_code=$?
	fi

	if [ $exit_code -eq 0 ]; then
		echo "  ✅ 通过"
		TOTAL_PASS=$((TOTAL_PASS + 1))
	else
		echo "  ❌ 失败 (exit=$exit_code)"
		TOTAL_FAIL=$((TOTAL_FAIL + 1))
		FAILED_TESTS="$FAILED_TESTS  - $name"$'\n'
	fi
	echo ""
}

# 运行所有测试：用索引遍历（i+=2 取名称+脚本）
for ((i = 0; i < ${#TESTS[@]}; i += 2)); do
	run_test "${TESTS[$i]}" "${TESTS[$((i + 1))]}"
done

# 汇总
echo "========================================"
echo "  测试完成"
echo "  ✅ 通过: $TOTAL_PASS"
echo "  ❌ 失败: $TOTAL_FAIL"
echo "========================================"

if [ -n "$FAILED_TESTS" ]; then
	echo ""
	echo "失败项:"
	printf "%b" "$FAILED_TESTS"
fi

# 退出码：有失败则非零
if [ $TOTAL_FAIL -gt 0 ]; then
	exit 1
else
	exit 0
fi
