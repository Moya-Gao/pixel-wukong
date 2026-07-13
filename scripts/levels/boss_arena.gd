## Boss 竞技场关卡脚本
## 连接 Boss 和 Boss HP Bar，管理战斗流程 + 登场演出
extends Node2D

# Headless 模式下 class_name 可能未注册，用 preload 保险
const BossIntroControllerScript = preload("res://scripts/effects/boss_intro.gd")

@onready var _boss: BossBase = $BlackBearBoss
@onready var _hp_bar: BossHPBar = $BossHPBar
@onready var _player: CharacterBody2D = $Player
@onready var _intro_controller: Node = $BossIntroController


func _ready() -> void:
	# 连接 Boss → HP Bar
	if _boss and _hp_bar:
		_hp_bar.attach(_boss)

	# 绑定特效控制器（监听 boss_phase_changed 自动触发阶段切换特效）
	if _intro_controller and _boss and _hp_bar:
		_intro_controller.bind(_boss, _hp_bar)
		_intro_controller.intro_finished.connect(_on_intro_finished)
		_intro_controller.play_intro()

	# 关卡就绪
	print("[BossArena] 黑熊精已就位 — 准备战斗！")


func _on_intro_finished() -> void:
	print("[BossArena] 登场完成 — 战斗开始！")


func _process(_delta: float) -> void:
	# 简单 AI：Boss 激活后始终以玩家为目标（替代 DetectionArea）
	if _boss and _player and not _boss.target:
		_boss.target = _player
