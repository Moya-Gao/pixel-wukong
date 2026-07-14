#!/usr/bin/env bash
## 像素悟空 - 全量自动化测试聚合器
## 运行: bash scripts/tests/run_all_tests.sh
## 每个测试独立运行，汇总结果

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"

TOTAL_PASS=0
TOTAL_FAIL=0
FAILED_TESTS=""

echo ""
echo "========================================"
echo "  像素悟空 - 全量自动化测试"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"
echo ""

# 测试列表：名称 + 脚本路径
declare -A TESTS=(
  ["场景完整性(碰撞层+FSM+击退)"]="scripts/tests/scene_integrity_test.gd"
  ["战斗手感自测(FSM+常量+Combo)"]="scripts/tests/combat_self_test.gd"
  ["Boss系统自测(BT+阶段+HPBar)"]="scripts/tests/boss_self_test.gd"
  ["死亡系统测试"]="scripts/tests/death_system_test.gd"
)

run_test() {
  local name="$1"
  local script="$2"

  echo "----------------------------------------"
  echo "  [$name]"
  echo "  $script"
  echo "----------------------------------------"

  cd "$PROJECT_DIR"

  # 运行测试，捕获退出码
  # --headless 模式，超时 120 秒
  if timeout 120 "$GODOT_BIN" --headless --script "$script" 2>&1; then
    local code=$?
    if [ $code -eq 0 ]; then
      echo "  ✅ 通过"
      TOTAL_PASS=$((TOTAL_PASS + 1))
    else
      echo "  ❌ 失败 (exit=$code)"
      TOTAL_FAIL=$((TOTAL_FAIL + 1))
      FAILED_TESTS="$FAILED_TESTS  - $name\n"
    fi
  else
    local code=$?
    echo "  ❌ 失败 (exit=$code)"
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
    FAILED_TESTS="$FAILED_TESTS  - $name\n"
  fi
  echo ""
}

# 运行所有测试
for name in "${!TESTS[@]}"; do
  run_test "$name" "${TESTS[$name]}"
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
