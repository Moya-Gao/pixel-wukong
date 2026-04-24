# Player Death System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add death animation (fall + fade) and a pixel-style "天命" Game Over UI with RESTART button.

**Architecture:** Death animation handled in `player_controller.gd` via `_die()`. Game Over UI is a separate scene instantiated and shown after death animation completes.

**Tech Stack:** Godot 4.x, GDScript, SceneTree

---

## File Structure

| File | Action | Purpose |
|------|--------|---------|
| `scripts/player/player_controller.gd` | Modify | Death animation with fade, show Game Over UI |
| `scenes/ui/game_over.tscn` | Create | Game Over UI scene |
| `scripts/ui/game_over.gd` | Create | UI control script |

---

## Task 1: Modify `_die()` in player_controller.gd

**Files:**
- Modify: `scripts/player/player_controller.gd:556-576`

**Changes:**
- Update `_die()` to play death animation, then fade out player, then show Game Over UI
- Add `death_fade_timer` variable for fade timing

- [ ] **Step 1: Add death fade variables**

Add after line 74 (after `is_dead`):
```gdscript
# 死亡动画
var death_fade_timer: float = 0.0
const DEATH_FADE_DURATION: float = 0.5
```

- [ ] **Step 2: Update `_die()` method**

Replace lines 556-576 with:
```gdscript
func _die() -> void:
    """玩家死亡"""
    is_dead = true
    print("💀 玩家死亡!")

    # 取消所有状态
    if is_attacking:
        _end_attack()
    if is_blocking:
        _end_block()
    if is_dodging:
        _end_dodge()

    # 禁用物理碰撞
    collision_layer = 0
    collision_mask = 0

    # 播放死亡动画（如果有）
    if animated_sprite and animated_sprite.sprite_frames.has_animation("death"):
        animated_sprite.play("death")
        await animated_sprite.animation_finished
    else:
        # 没有 death 动画时，等待一小段时间
        await get_tree().create_timer(0.3).timeout

    # 开始渐变消失
    death_fade_timer = DEATH_FADE_DURATION

- [ ] **Step 3: Add fade update in _physics_process**

Add after the hurt update block (after line 113, before "# 更新冷却和计时器"):

```gdscript
    # 更新死亡渐变
    if is_dead and death_fade_timer > 0:
        death_fade_timer -= delta
        var alpha = death_fade_timer / DEATH_FADE_DURATION
        modulate.a = alpha
        if death_fade_timer <= 0:
            _on_death_complete()
```

- [ ] **Step 4: Add `_on_death_complete()` method**

Add after `_die()`:
```gdscript
func _on_death_complete() -> void:
    """死亡动画完成后"""
    visible = false
    # 显示 Game Over UI
    var game_over = preload("res://scenes/ui/game_over.tscn").instantiate()
    get_tree().current_scene.add_child(game_over)
```

- [ ] **Step 5: Commit**

```bash
git add scripts/player/player_controller.gd
git commit -m "feat: add death fade animation"
```

---

## Task 2: Create Game Over UI Scene

**Files:**
- Create: `scenes/ui/game_over.tscn`
- Create: `scripts/ui/game_over.gd`

- [ ] **Step 1: Create game_over.gd script**

```gdscript
## Game Over UI
extends Control

@onready var restart_button: Button = $VBox/RestartButton

func _ready() -> void:
    restart_button.pressed.connect(_on_restart_pressed)

    # 设置随机提示文字（可选扩展）
    var tips = ["记住这个位置", "再来一次", "天命所归"]
    # 目前先不显示提示，保持简洁

func _on_restart_pressed() -> void:
    get_tree().reload_current_scene()
```

- [ ] **Step 2: Create game_over.tscn**

Create a new scene with:
- `Control` as root node named `GameOver`
- A dark semi-transparent `ColorRect` covering full screen
- A centered `VBoxContainer` containing:
  - `Label` with text "天命" (custom_style: large, pixel-feel)
  - `Button` with text "RESTART" (pixel-style border)

```gdscript
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/game_over.gd" id="1"]

[node name="GameOver" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1")

[node name="Background" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(0, 0, 0, 0.7)

[node name="VBox" type="VBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -100.0
offset_top = -60.0
offset_right = 100.0
offset_bottom = 60.0
grow_horizontal = 2
grow_vertical = 2

[node name="Title" type="Label" parent="VBox"]
layout_mode = 2
text = "天命"
horizontal_alignment = 1
vertical_alignment = 1

[node name="RestartButton" type="Button" parent="VBox"]
layout_mode = 2
text = "RESTART"
```

- [ ] **Step 3: Style the Title label**

In the Title node properties:
- Font size: Large (32 or 48)
- Add a dark outline effect via StyleBox or use theme

For pixel style, use a `StyleBoxFlat` with:
- Background: transparent
- Border: 2px all sides, bright color
- Padding to increase size

- [ ] **Step 4: Style the Restart button**

Create a pixel-style button with:
- Normal style: Dark purple/blue background + bright border
- Hover style: Brighter border
- Press style: Inverted colors

```gdscript
[node name="RestartButton" type="Button" parent="VBox"]
layout_mode = 2
theme_override_styles/normal = SubResource("StyleBoxNormal")
theme_override_styles/hover = SubResource("StyleBoxHover")
theme_override_styles/pressed = SubResource("StyleBoxPressed")
text = "RESTART"
```

Need to add StyleBox resources before this node.

- [ ] **Step 5: Commit**

```bash
git add scenes/ui/game_over.tscn scripts/ui/game_over.gd
git commit -m "feat: add Game Over UI with restart button"
```

---

## Task 3: Test the death system

**Files:**
- Test: Run the game in Godot editor

- [ ] **Step 1: Test in editor**

1. Open Godot editor: `open -a Godot .`
2. Open `scenes/levels/test_level.tscn`
3. Run the game (F5)
4. Find and attack the enemy until player dies
5. Verify:
   - Death animation plays
   - Player fades out
   - "天命" UI appears
   - RESTART button works

- [ ] **Step 2: Commit**

```bash
git commit -m "test: verify death system works in-game"
```

---

## Spec Coverage Check

- [x] Death animation (fall + fade) - Task 1
- [x] "天命" Game Over text - Task 2
- [x] RESTART button - Task 2
- [x] Pixel style - Task 2
- [x] Click to restart - Task 2
