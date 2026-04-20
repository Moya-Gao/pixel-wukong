## 玩家状态枚举
## 定义玩家的所有可能状态

class_name PlayerState
extends RefCounted

enum State {
	IDLE,           # 站立不动
	RUN,            # 奔跑
	JUMP,           # 跳跃
	FALL,           # 下落
	ATTACK_LIGHT,   # 轻攻击
	ATTACK_HEAVY,   # 重攻击
	DODGE,          # 闪避
	BLOCK,          # 格挡
	HURT,           # 受伤
	TRANSFORM,      # 变身
}

## 状态名称映射（用于调试）
static func get_state_name(state: State) -> String:
	match state:
		State.IDLE: return "Idle"
		State.RUN: return "Run"
		State.JUMP: return "Jump"
		State.FALL: return "Fall"
		State.ATTACK_LIGHT: return "AttackLight"
		State.ATTACK_HEAVY: return "AttackHeavy"
		State.DODGE: return "Dodge"
		State.BLOCK: return "Block"
		State.HURT: return "Hurt"
		State.TRANSFORM: return "Transform"
		_: return "Unknown"
