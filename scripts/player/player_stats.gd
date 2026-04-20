## 玩家统计数据
## 管理玩家的属性、变身能力等

class_name PlayerStats
extends Resource

@export_group("基础属性")
@export var max_health: int = 100
@export var current_health: int = 100
@export var max_stamina: float = 100.0
@export var current_stamina: float = 100.0
@export var move_speed: float = 150.0
@export var jump_force: float = 300.0
@export var gravity: float = 800.0

@export_group("战斗属性")
@export var attack_damage_light: int = 10
@export var attack_damage_heavy: int = 25
@export var combo_window: float = 0.5  # 连招时间窗口
@export var dodge_duration: float = 0.3  # 闪避持续时间
@export var dodge_invincibility: float = 0.2  # 闪避无敌帧时长
@export var dodge_cooldown: float = 0.5  # 闪避冷却
@export var perfect_block_window: float = 0.15  # 完美格挡窗口

@export_group("变身能力")
@export var unlocked_transformations: Array[String] = []  # 已解锁的变身
@export var current_transformation: String = ""  # 当前变身形态

## 恢复生命值
func heal(amount: int) -> void:
	current_health = mini(current_health + amount, max_health)

## 受到伤害
func take_damage(amount: int) -> void:
	current_health = maxi(current_health - amount, 0)

## 消耗耐力
func use_stamina(amount: float) -> bool:
	if current_stamina >= amount:
		current_stamina -= amount
		return true
	return false

## 恢复耐力
func recover_stamina(amount: float) -> void:
	current_stamina = minf(current_stamina + amount, max_stamina)

## 解锁变身
func unlock_transformation(transformation_id: String) -> void:
	if transformation_id not in unlocked_transformations:
		unlocked_transformations.append(transformation_id)

## 切换变身
func set_transformation(transformation_id: String) -> bool:
	if transformation_id in unlocked_transformations or transformation_id == "":
		current_transformation = transformation_id
		return true
	return false

## 检查是否已解锁变身
func has_transformation(transformation_id: String) -> bool:
	return transformation_id in unlocked_transformations
