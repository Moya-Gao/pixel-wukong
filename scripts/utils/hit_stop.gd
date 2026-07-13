## Hit Stop（顿帧）工具
## 命中瞬间短暂冻结游戏，模拟"打到了"的重量感
## 用法：HitStop.trigger(0.05) — 冻结 50ms
##
## 安装：在场景根节点添加一个 HitStop 子节点即可
## Engine.time_scale 在 process 层生效（Timer process_always=true 不受影响）

class_name HitStop
extends Node

var _is_active: bool = false


## 触发顿帧。多次调用时忽略后续（不嵌套冻结）
func trigger(duration: float = 0.05, freeze_factor: float = 0.1) -> void:
	if _is_active:
		return  # 已经冻结中，不嵌套
	_is_active = true
	Engine.time_scale = freeze_factor

	# process_always=true → 不受 time_scale 影响，真实时间计时
	await get_tree().create_timer(duration, true, false).timeout

	Engine.time_scale = 1.0
	_is_active = false


## 便捷方法：根据伤害大小决定顿帧强度
## 高伤害 → 更长顿帧，更有"重击"感
static func trigger_by_damage(tree: SceneTree, damage: int) -> void:
	var hit_stop := _find_or_create(tree)
	if hit_stop:
		var duration: float = 0.03
		if damage >= 25:
			duration = 0.08
		elif damage >= 15:
			duration = 0.05
		hit_stop.trigger(duration)


## 便捷方法：按攻击类型决定顿帧强度（覆盖 trigger_by_damage 的纯伤害分级）
## 攻击类型: "light" → 0.05s, "heavy" → 0.10s, "boss_heavy" → 0.15s
static func trigger_by_attack_type(tree: SceneTree, attack_type: String) -> void:
	var hit_stop := _find_or_create(tree)
	if hit_stop:
		var duration: float
		match attack_type:
			"boss_heavy": duration = 0.15
			"heavy": duration = 0.10
			"light": duration = 0.05
			_: duration = 0.03
		hit_stop.trigger(duration)


static func _find_or_create(tree: SceneTree) -> HitStop:
	# 尝试在场景根节点下找已有的 HitStop
	for child in tree.current_scene.get_children():
		if child is HitStop:
			return child
	# 没有就创建一个
	var hs := HitStop.new()
	hs.name = "HitStop"
	tree.current_scene.add_child(hs)
	return hs
