## Boss 竞技场关卡脚本
## 连接 Boss 和 Boss HP Bar，管理战斗流程
extends Node2D

@onready var _boss: BossBase = $BlackBearBoss
@onready var _hp_bar: BossHPBar = $BossHPBar
@onready var _player: CharacterBody2D = $Player


func _ready() -> void:
	# 连接 Boss → HP Bar
	if _boss and _hp_bar:
		_hp_bar.attach(_boss)

	# 关卡就绪
	print("[BossArena] 黑熊精已就位 — 准备战斗！")


func _process(_delta: float) -> void:
	# 简单 AI：Boss 激活后始终以玩家为目标（替代 DetectionArea）
	if _boss and _player and not _boss.target:
		_boss.target = _player
