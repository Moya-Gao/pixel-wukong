# 玩家死亡系统设计

## 概述
为玩家添加死亡动画和重新开始界面。

## 死亡动画流程

1. 玩家血量归零 → 调用 `_die()`
2. 播放 `death` 动画帧（利用现有 `hurt.png`，或后续替换为专门的死亡帧）
3. 动画播放完成后，`modulate.a` 从 1.0 渐变到 0.0（约 0.5 秒）
4. 渐变结束 → 隐藏玩家节点 → 显示 Game Over UI

## Game Over UI

### 布局
- 居中显示
- 标题："天命"（像素字体）
- 按钮："RESTART"

### 像素风格
- 字体：系统像素风格字体
- 按钮：深蓝/深紫背景 + 亮色粗边框（2px）
- 悬停：边框变亮 + 轻微放大
- 点击：反色闪烁反馈

### 交互
- RESTART 按钮 → `get_tree().reload_current_scene()` 重新加载当前关卡

## 实现文件

| 文件 | 职责 |
|------|------|
| `scripts/player/player_controller.gd` | 死亡动画逻辑（渐变消失） |
| `scenes/ui/game_over.tscn` | UI 场景 |
| `scripts/ui/game_over.gd` | UI 控制脚本 |

## 状态

- [x] 设计完成
- [ ] 实现中
- [ ] 测试验证
