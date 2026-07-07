## 伤害数字飘字
## 显示在受击点上方，向上飘动并淡出

extends Label
class_name DamageNumber

const FLOAT_DISTANCE := 32.0
const FLOAT_DURATION := 0.6


## 配置飘字内容（伤害值 + 受击方是玩家还是敌人）
func setup(damage: int, _is_enemy_hit: bool) -> void:
	text = str(damage)

	# 颜色按伤害等级分级：轻击白 / 中击黄 / 重击红
	if damage >= 25:
		modulate = Color(1.4, 0.4, 0.4)
		add_theme_font_size_override("font_size", 20)
	elif damage >= 15:
		modulate = Color(1.3, 1.0, 0.3)
		add_theme_font_size_override("font_size", 16)
	else:
		modulate = Color(2.0, 2.0, 2.0)
		add_theme_font_size_override("font_size", 14)

	# 飘字动画：上飘 + 淡出
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		self, "position:y", position.y - FLOAT_DISTANCE, FLOAT_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, FLOAT_DURATION)
	tween.set_parallel(false)
	tween.tween_callback(queue_free).set_delay(FLOAT_DURATION)