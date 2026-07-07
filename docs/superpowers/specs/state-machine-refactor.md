# 玩家状态机重构设计

> 设计者：宪宪 (@opus) | 日期：2026-07-07
> 状态：design | 目标：为连招系统和攻击取消提供架构基础

---

## 1. 问题诊断

当前 `player_controller.gd`（657行）用 **bool 标志** 管理状态：

```gdscript
var is_attacking = false
var is_dodging = false
var is_blocking = false
var is_hurt = false
var is_jumping = false
var is_dead = false
```

而 `player_state.gd` 定义的 `PlayerState.State` 枚举 **从未被使用**。

### 造成的具体问题

| 问题 | 影响 |
|------|------|
| 隐式状态转换 | `_physics_process` 里用 if/elif 链判断优先级，无法一眼看出"什么状态能转到什么状态" |
| 不一致的取消规则 | 攻击中可以格挡（line 236），但攻击中不能闪避——规则散落在代码各处 |
| 连招难扩展 | `attack_combo` 只是计数器，无法表达"轻→轻→重"这样的编排链 |
| 不可测试 | bool 标志的组合状态数 = 2⁷ = 128，无法穷举验证 |
| 文件过大 | 657行，超 350 行硬限 |

---

## 2. 目标架构：有限状态机 (FSM)

### 2.1 状态定义

复用现有 `PlayerState.State` 枚举，补全：

```
IDLE          → 站立
RUN           → 移动
JUMP_RISE     → 跳跃上升
JUMP_FALL     → 跳跃下落
ATTACK_LIGHT  → 轻攻击（内部跟踪 combo 计数）
ATTACK_HEAVY  → 重攻击
DODGE         → 闪避
BLOCK         → 格挡
HURT          → 受伤（含击退）
DEAD          → 死亡
```

### 2.2 状态转换表

```
                   ┌──────────────────────────────────────────────┐
                   │  可以从哪个状态 → 转到哪个状态               │
                   └──────────────────────────────────────────────┘

当前状态         → 可转换到
──────────────────────────────────────────
IDLE             → RUN, JUMP_RISE, ATTACK_LIGHT, ATTACK_HEAVY, DODGE, BLOCK, HURT, DEAD
RUN              → IDLE, JUMP_RISE, ATTACK_LIGHT, ATTACK_HEAVY, DODGE, BLOCK, HURT, DEAD
JUMP_RISE        → JUMP_FALL(自动), HURT, DEAD
JUMP_FALL        → IDLE(落地), HURT, DEAD
ATTACK_LIGHT     → IDLE(攻击结束), ATTACK_LIGHT(连招), ATTACK_HEAVY(重击接), DODGE(取消), BLOCK(取消), HURT, DEAD
ATTACK_HEAVY     → IDLE(攻击结束), DODGE(取消), BLOCK(取消), HURT, DEAD
DODGE            → IDLE(闪避结束), HURT(窗口外), DEAD
BLOCK            → IDLE(松开), DODGE(取消), HURT(非完美格挡), DEAD
HURT             → IDLE(受伤结束), DEAD(HP归零)
DEAD             → (终态，不可转换)
```

### 2.3 取消规则（Cancel Window）

这是攻击取消系统的核心——定义"什么操作可以打断当前状态"：

| 当前状态 | 可取消为 | 取消条件 |
|----------|---------|----------|
| ATTACK_LIGHT | DODGE | 攻击开始后 0.05s ~ 结束前 0.05s |
| ATTACK_LIGHT | BLOCK | 任意时刻（当前已有） |
| ATTACK_LIGHT | ATTACK_LIGHT | combo_window 内 + 攻击结束前 0.05s（预输入） |
| ATTACK_HEAVY | DODGE | 攻击开始后 0.1s ~ 结束前 0.08s（窗口比轻攻击窄） |
| ATTACK_HEAVY | BLOCK | 攻击开始后 0.1s ~ 结束前 0.08s |
| BLOCK | DODGE | 任意时刻（当前已有） |

---

## 3. 实现方案

### 3.1 文件拆分

当前 `player_controller.gd`（657行）拆为：

```
scripts/player/
├── player_controller.gd     (~150行) 输入读取 + 状态机调度（只做路由，不做逻辑）
├── player_state_machine.gd  (~150行) FSM 核心：transition/enter/exit/can_transition
├── states/
│   ├── state_base.gd         (~15行)  状态基类（enter/exit/process/handle_input）
│   ├── state_idle.gd         (~30行)
│   ├── state_run.gd          (~25行)
│   ├── state_jump.gd         (~40行)
│   ├── state_attack.gd       (~80行)  轻/重攻击合并，内部跟踪 combo
│   ├── state_dodge.gd        (~40行)
│   ├── state_block.gd        (~40行)
│   ├── state_hurt.gd         (~30行)
│   └── state_dead.gd         (~25行)
└── player_visual.gd          (~60行)  从 controller 抽出的视觉更新逻辑
```

**总计 ~635行，拆成 12 个文件，每个 ≤150行。**

### 3.2 核心类：PlayerStateMachine

```gdscript
class_name PlayerStateMachine
extends Node

# 当前状态
var current_state: PlayerState.State = PlayerState.State.IDLE
var state_instance: StateBase = null

# 状态实例缓存
var _states: Dictionary = {}

# 转换历史（用于 debug + 连招检测）
var state_history: Array = []  # 最近 N 个状态

func transition_to(target: PlayerState.State, data: Dictionary = {}) -> bool:
    if not can_transition(target):
        return false
    if state_instance:
        state_instance.exit()
    state_history.push_back({"from": current_state, "to": target, "time": Time.get_ticks_msec()})
    current_state = target
    state_instance = _get_state(target)
    state_instance.enter(data)
    return true

func can_transition(target: PlayerState.State) -> bool:
    # 查转换表
    return target in TRANSITION_TABLE[current_state]

func process(delta: float) -> void:
    if state_instance:
        state_instance.process(delta)

func handle_input(event: InputEvent) -> void:
    if state_instance:
        state_instance.handle_input(event)
```

### 3.3 状态基类

```gdscript
class_name StateBase
extends RefCounted

var player: CharacterBody2D
var fsm: PlayerStateMachine

func enter(_data: Dictionary = {}) -> void: pass
func exit() -> void: pass
func process(_delta: float) -> void: pass
func handle_input(_event: InputEvent) -> void: pass  # 返回是否消费了输入
```

### 3.4 输入处理：从 _physics_process 解耦

**当前问题**：所有输入检测都在 `_physics_process` 的 if/elif 链里，导致：
- 格挡检测用了 `is_action_pressed`（持续检测），但攻击用了 `is_action_just_pressed`（瞬间检测）
- 预输入队列 `queued_attack` 在 `_process_attack` 里处理——输入逻辑和攻击逻辑耦合

**新方案**：`player_controller._physics_process` 只做三件事：
```gdscript
func _physics_process(delta):
    if is_dead: return  # 死亡短路
    
    _read_input()        # 1. 读玩家输入 → 生成输入事件
    fsm.process(delta)   # 2. 状态机处理当前状态逻辑
    move_and_slide()     # 3. 物理移动
    
    _update_visual()
    _update_animation()
```

---

## 4. 连招系统的状态机表达

有了正式 FSM 后，连招不再是计数器，而是 **状态转换链**：

```
ATTACK_LIGHT(combo=1) → ATTACK_LIGHT(combo=2) → ATTACK_LIGHT(combo=3)
                                                     ↓
                                              ATTACK_HEAVY (终结技)
```

`state_attack.gd` 内部维护 combo 状态：
- `enter()`: 设置 attack_timer + 激活 hitbox + 更新 combo 计数
- `process()`: 检测预输入 → 预约下一个 ATTACK_LIGHT 或 ATTACK_HEAVY
- `exit()`: 清理 hitbox

---

## 5. 迁移策略（两步走）

### Step 1：FSM 替换 bool 标志（本 PR）
- 新建 `player_state_machine.gd` + `states/*.gd`
- `player_controller.gd` 接入 FSM，删除 bool 标志
- **行为保持完全一致**（重构不改功能）
- 验收：用现有 test_level 验证所有操作（移动/跳跃/攻击/闪避/格挡/受伤/死亡）

### Step 2：连招 + 取消系统（后续 PR）
- 基于 FSM 的 `TRANSITION_TABLE` 加入 combo 链规则
- 加入 cancel window 逻辑
- 验收：新增连招测试

---

## 6. 验收标准

| 标准 | 验证方式 |
|------|---------|
| 所有现有操作行为不变 | F5 跑 test_level，逐项验证：移动/WASD/攻击J/重击K/闪避L/格挡I/被敌人打/死亡RESTART |
| 文件不超 350 行 | `wc -l scripts/player/**/*.gd` |
| 不引入新 bug | 现有 death_system_test 通过 |
| FSM 转换可追踪 | `state_history` 数组可在 debug 面板查看 |
