## 敌人属性资源
## 定义敌人的基础属性，可在编辑器中配置

class_name EnemyStats
extends Resource

@export_group("生命属性")
@export var max_health: int = 50
@export var current_health: int = 50

@export_group("移动属性")
@export var move_speed: float = 80.0
@export var chase_speed: float = 120.0

@export_group("战斗属性")
@export var attack_damage: int = 10
@export var attack_range: float = 30.0
@export var attack_duration: float = 0.4
@export var attack_cooldown: float = 1.0

@export_group("受伤属性")
@export var hurt_duration: float = 0.3
@export var knockback_force: float = 150.0
@export var knockback_friction: float = 500.0

@export_group("AI 属性")
@export var detection_range: float = 100.0
@export var patrol_range: float = 50.0
@export var patrol_wait_time: float = 2.0

@export_group("奖励")
@export var exp_reward: int = 10
@export var gold_reward: int = 5
