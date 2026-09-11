class_name EventSystem
extends System
## 随机事件系统：每天随机安排事件（美食评论家、客流高峰、卫生检查、设备故障），
## 到点触发，制造「决策取舍」和变数。加新事件 = 加一个调度 + 广播事件，不改已有代码。


const CRITIC_PROB := 0.30
const RUSH_PROB := 0.35
const INSPECT_PROB := 0.25
const BREAK_PROB := 0.20
const HOLIDAY_PROB := 0.15

var _critic_minute := -1
var _rush_minute := -1
var _inspect_minute := -1
var _break_minute := -1
var _holiday_minute := -1


func setup() -> void:
	EventBus.subscribe("clock.day_started", _on_day_started)
	EventBus.subscribe("clock.tick", _on_tick)


func teardown() -> void:
	EventBus.unsubscribe("clock.day_started", _on_day_started)
	EventBus.unsubscribe("clock.tick", _on_tick)


func _on_day_started(_day) -> void:
	_critic_minute = -1
	_rush_minute = -1
	_inspect_minute = -1
	_break_minute = -1
	_holiday_minute = -1
	if randf() < CRITIC_PROB:
		_critic_minute = randi_range(8, 35)
	if randf() < RUSH_PROB:
		_rush_minute = randi_range(15, 45)
	if randf() < INSPECT_PROB:
		_inspect_minute = randi_range(20, 50)
	if randf() < BREAK_PROB:
		_break_minute = randi_range(20, 45)
	if randf() < HOLIDAY_PROB:
		_holiday_minute = randi_range(5, 30)


func _on_tick(minute) -> void:
	# 设备故障倒计时
	if GameState.equipment_broken_ticks > 0:
		GameState.equipment_broken_ticks -= 1

	if GameState.shop["day_state"] != "serving":
		return
	if minute == _critic_minute:
		EventBus.emit("event.food_critic")
	if minute == _rush_minute:
		EventBus.emit("event.rush_hour")
	if minute == _inspect_minute:
		_check_inspection()
	if minute == _break_minute:
		_break_equipment()
	if minute == _holiday_minute:
		_trigger_holiday()


func _check_inspection() -> void:
	var hygiene: float = GameState.shop["hygiene"]
	if hygiene < 50.0:
		var fine := 40
		GameState.shop["money"] = maxi(GameState.shop["money"] - fine, 0)
		GameState.shop["reputation"] -= 2
		EventBus.emit("event.inspect_fail", {"fine": fine})
	else:
		GameState.shop["reputation"] += 1
		EventBus.emit("event.inspect_pass")


func _break_equipment() -> void:
	GameState.equipment_broken_ticks = 3
	EventBus.emit("event.equipment_failure")


func _trigger_holiday() -> void:
	GameState.shop["holiday"] = true
	EventBus.emit("event.holiday")
