## 玩家状态机（FSM）
## 替换原 player_controller.gd 的 7 个 bool 标志
## 提供 transition_to / can_transition / process / handle_input 接口

class_name PlayerStateMachine
extends Node

# 当前状态
var current_state: PlayerState.State = PlayerState.State.IDLE
var state_instance: StateBase = null

# 状态实例缓存（避免重复创建）
var _states: Dictionary = {}

# 转换历史（用于 debug + 连招检测）
var state_history: Array = []  # 最近 N 个状态转换记录

# 转换表（合法状态转换）
# 不可变映射：当前状态 → 可转换到的状态集合
const TRANSITION_TABLE := {
	PlayerState.State.IDLE: [
		PlayerState.State.RUN,
		PlayerState.State.JUMP_RISE,
		PlayerState.State.ATTACK_LIGHT,
		PlayerState.State.ATTACK_HEAVY,
		PlayerState.State.DODGE,
		PlayerState.State.BLOCK,
		PlayerState.State.HURT,
		PlayerState.State.DEAD,
	],
	PlayerState.State.RUN: [
		PlayerState.State.IDLE,
		PlayerState.State.JUMP_RISE,
		PlayerState.State.ATTACK_LIGHT,
		PlayerState.State.ATTACK_HEAVY,
		PlayerState.State.DODGE,
		PlayerState.State.BLOCK,
		PlayerState.State.HURT,
		PlayerState.State.DEAD,
	],
	PlayerState.State.JUMP_RISE: [
		PlayerState.State.JUMP_FALL,
		PlayerState.State.HURT,
		PlayerState.State.DEAD,
	],
	PlayerState.State.JUMP_FALL: [
		PlayerState.State.IDLE,
		PlayerState.State.HURT,
		PlayerState.State.DEAD,
	],
	PlayerState.State.ATTACK_LIGHT: [
		PlayerState.State.IDLE,
		PlayerState.State.ATTACK_LIGHT,
		PlayerState.State.ATTACK_HEAVY,
		PlayerState.State.DODGE,
		PlayerState.State.BLOCK,
		PlayerState.State.HURT,
		PlayerState.State.DEAD,
	],
	PlayerState.State.ATTACK_HEAVY: [
		PlayerState.State.IDLE,
		PlayerState.State.DODGE,
		PlayerState.State.BLOCK,
		PlayerState.State.HURT,
		PlayerState.State.DEAD,
	],
	PlayerState.State.DODGE: [
		PlayerState.State.IDLE,
		PlayerState.State.HURT,
		PlayerState.State.DEAD,
	],
	PlayerState.State.BLOCK: [
		PlayerState.State.IDLE,
		PlayerState.State.DODGE,
		PlayerState.State.HURT,
		PlayerState.State.DEAD,
	],
	PlayerState.State.HURT: [
		PlayerState.State.IDLE,
		PlayerState.State.DEAD,
	],
	PlayerState.State.DEAD: [],  # 终态
}


## 尝试转换到目标状态。返回是否成功（不合法转换返回 false）
func transition_to(target: PlayerState.State, data: Dictionary = {}) -> bool:
	if not can_transition(target):
		return false

	var from_state: int = current_state

	if state_instance:
		state_instance.exit()

	state_history.push_back({
		"from": from_state,
		"to": target,
		"time": Time.get_ticks_msec(),
	})
	# 保留最近 20 条
	if state_history.size() > 20:
		state_history.pop_front()

	current_state = target
	state_instance = _get_state(target)

	# 把 prev_state 加入 data，让 state.enter() 区分"新进入"vs"续接"
	var enriched: Dictionary = data.duplicate()
	enriched["prev_state"] = from_state
	state_instance.enter(enriched)
	return true


## 检查目标状态是否合法
func can_transition(target: PlayerState.State) -> bool:
	if current_state not in TRANSITION_TABLE:
		return false
	return target in TRANSITION_TABLE[current_state]


## 当前状态处理逻辑（每帧调用）
func process(delta: float) -> void:
	if state_instance:
		state_instance.process(delta)


## 当前状态处理输入（返回是否消费）
func handle_input(event: Dictionary) -> bool:
	if state_instance:
		return state_instance.handle_input(event)
	return false


## 获取状态实例（懒加载 + 缓存）
## JUMP_RISE/JUMP_FALL 共享同一 instance；ATTACK_LIGHT/HEAVY 共享同一 instance
func _get_state(state: PlayerState.State) -> StateBase:
	# 共享 instance 的状态归一化到 base key
	var cache_key: PlayerState.State = state
	match state:
		PlayerState.State.JUMP_RISE, PlayerState.State.JUMP_FALL:
			cache_key = PlayerState.State.JUMP_RISE
		PlayerState.State.ATTACK_LIGHT, PlayerState.State.ATTACK_HEAVY:
			cache_key = PlayerState.State.ATTACK_LIGHT

	if cache_key in _states:
		return _states[cache_key]

	var instance: StateBase = null
	match cache_key:
		PlayerState.State.IDLE:
			instance = preload("res://scripts/player/states/state_idle.gd").new()
		PlayerState.State.RUN:
			instance = preload("res://scripts/player/states/state_run.gd").new()
		PlayerState.State.JUMP_RISE:
			instance = preload("res://scripts/player/states/state_jump.gd").new()
		PlayerState.State.ATTACK_LIGHT:
			instance = preload("res://scripts/player/states/state_attack.gd").new()
		PlayerState.State.DODGE:
			instance = preload("res://scripts/player/states/state_dodge.gd").new()
		PlayerState.State.BLOCK:
			instance = preload("res://scripts/player/states/state_block.gd").new()
		PlayerState.State.HURT:
			instance = preload("res://scripts/player/states/state_hurt.gd").new()
		PlayerState.State.DEAD:
			instance = preload("res://scripts/player/states/state_dead.gd").new()

	if instance:
		instance.player = _player_ref
		instance.fsm = self
		_states[cache_key] = instance
	return instance


# 内部引用：被 _get_state 调用前由 controller 设置
var _player_ref: CharacterBody2D = null


## 由 PlayerController._ready 调用，建立 player 引用
func setup(player: CharacterBody2D) -> void:
	_player_ref = player