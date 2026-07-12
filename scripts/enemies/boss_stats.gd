## Boss 属性资源
## 继承 EnemyStats，增加阶段切换、阶段属性倍率、Boss 展示信息
class_name BossStats
extends EnemyStats

# ========== Boss 信息 ==========
@export_group("Boss 信息")
@export var boss_name: String = "Boss"
@export var boss_subtitle: String = ""  # 如 "黑风山妖王"

# ========== 阶段定义 ==========
## 阶段切换的血量阈值（按血量比例，从高到低）
## e.g. [0.66, 0.33] 表示 ≤66% 进 P2，≤33% 进 P3
@export var phase_thresholds: Array[float] = [0.66, 0.33]
## 阶段名称（UI 显示）
@export var phase_names: Array[String] = ["一阶段", "二阶段", "三阶段"]

# ========== 阶段属性倍率 ==========
## 各阶段的伤害倍率（索引 0 = P1，1 = P2，...）
@export var phase_damage_mult: Array[float] = [1.0, 1.3, 1.6]
## 各阶段的移动速度倍率
@export var phase_speed_mult: Array[float] = [1.0, 1.15, 1.3]
## 各阶段的攻击冷却倍率（<1.0 = 更快）
@export var phase_cooldown_mult: Array[float] = [1.0, 0.8, 0.6]

# ========== Boss 专属 ==========
## 阶段切换无敌时间（秒）
@export var phase_transition_invincible: float = 1.5
## 受击时减少的硬直（0=无硬直，1=正常硬直）
@export var poise_resistance: float = 0.3


## 获取当前阶段的伤害（基础伤害 × 阶段倍率）
func get_phase_damage(phase: int) -> int:
	if phase < phase_damage_mult.size():
		return int(float(attack_damage) * phase_damage_mult[phase])
	return attack_damage


## 获取当前阶段的移动速度（基础速度 × 阶段倍率）
func get_phase_speed(phase: int) -> float:
	if phase < phase_speed_mult.size():
		return move_speed * phase_speed_mult[phase]
	return move_speed


## 获取当前阶段的攻击冷却
func get_phase_cooldown(phase: int) -> float:
	if phase < phase_cooldown_mult.size():
		return attack_cooldown * phase_cooldown_mult[phase]
	return attack_cooldown
