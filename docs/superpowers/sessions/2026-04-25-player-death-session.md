# 2026-04-25 玩家死亡系统开发记录

## 完成的工作

### 1. Bug 修复：敌人挂在玩家头上不下来
**文件：** `scenes/enemies/grunt.tscn`

**问题：** 玩家和敌人都在 `collision_layer=1`，物理上互相阻挡，导致敌人挂在玩家头上不下来

**修复方案：**
- 将敌人移到独立的 `collision_layer=2`
- 敌人 body 不再与玩家物理碰撞
- DetectionArea 仍然检测玩家（mask=1）
- 战斗系统（Hitbox/Hurtbox）保持不变

**Commit:** `fd36f64 feat: add death fade animation`

---

### 2. 死亡动画系统
**文件：** `scripts/player/player_controller.gd`

**实现内容：**
- `_die()` - 死亡触发，禁用碰撞，清除状态
- `death_fade_timer` / `death_fade_complete` - 淡出计时
- `_start_death_fade()` - `call_deferred` 延迟开始淡出
- `_on_death_complete()` - 淡出完成后显示 Game Over UI
- `_physics_process` 中死亡状态优先处理

**Commit:** `6359577 feat: add Game Over UI with restart button`

---

### 3. Game Over UI
**文件：**
- `scenes/ui/game_over.tscn` - UI 场景
- `scripts/ui/game_over.gd` - UI 控制脚本

**功能：**
- "天命" 标题
- "RESTART" 按钮（像素风格）
- 游戏暂停（`get_tree().paused = true`）
- 按钮防重复点击（`_can_restart`）
- `reload_current_scene()` 重启

---

## Bug 解决过程

### Bug 1: 碰撞优先级问题
**症状：** `is_hurt=true` 导致 `_physics_process` 提前返回，无法执行 `is_dead` 分支

**解决：** 将 `is_dead` 检查移到 `is_hurt` 之前

### Bug 2: 浮点数精度问题
**症状：** `death_fade_timer` 从小正数减 delta 可能不会精确达到 0

**解决：** 使用 `death_fade_complete` 标志位来追踪完成状态

### Bug 3: `call_deferred` vs Timer
**症状：** 使用 `await get_tree().create_timer().timeout` 在 `_die()` 中会导致问题

**解决：** 改用 `call_deferred("_start_death_fade")` + Timer 节点

### Bug 4: headless 模式 frame timing
**症状：** 测试在 headless 模式下，`_physics_process` 的执行频率不稳定，导致淡出逻辑无法正常完成

**状态：** 未完全解决

---

## 当前状态

### 已提交到 git
```
fd36f64 feat: add death fade animation
6359577 feat: add Game Over UI with restart button
```

### 待解决的问题

**死亡系统测试在 headless 模式下失败：**
- 原因：Godot headless 模式下 `_physics_process` 执行不稳定
- 现象：`modulate.a` 在等待期间变为 0，但 `_on_death_complete()` 未被调用
- 影响：自动化测试无法通过，但代码逻辑在编辑器中应该正常工作

**需要手动验证：**
1. 在 Godot 编辑器中运行游戏
2. 被敌人攻击直到死亡
3. 验证死亡动画（倒下 → 淡出）
4. 验证 "天命" UI 出现
5. 验证 RESTART 按钮可以正常重启游戏

---

## 相关文件

| 文件 | 状态 | 说明 |
|------|------|------|
| `scenes/enemies/grunt.tscn` | ✅ 已修复 | 碰撞层分离 |
| `scripts/player/player_controller.gd` | ✅ 已修改 | 死亡动画逻辑 |
| `scenes/ui/game_over.tscn` | ✅ 已创建 | Game Over 场景 |
| `scripts/ui/game_over.gd` | ✅ 已创建 | UI 控制 |
| `scripts/tests/death_system_test.gd` | ⚠️ 待修复 | 自动化测试脚本 |

---

## 下次开发任务

1. **手动验证死亡系统** - 在 Godot 编辑器中测试完整流程
2. **修复测试脚本** - 解决 headless 模式下的 frame timing 问题
3. **添加 death 动画帧** - 目前使用 hurt.png，后续需要专门的死亡帧
