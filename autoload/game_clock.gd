extends Node
## 游戏内时钟：驱动一切时间类机制（客人焦虑、卫生劣化、天气切换）。
##
## 真实时间按比例换算为游戏内分钟，可变速、可暂停。
## 通过 EventBus 广播时间事件（clock.tick / clock.day_started / clock.day_ended）。
## 注意：第一天的 clock.day_started 由主场景在系统注册后手动触发，
## 之后的每天由 _end_day() 触发。

## 每个游戏内分钟对应的真实秒数。
## 3.0 = 营业日约 3 分钟真实时间（评审反馈 2 分钟太慌、单子死在锅里跨天蒸发）：
## 烹饪链 2~3 步 × 真实秒计时，需要给休闲玩家留出完成一单的余量。
var seconds_per_minute: float = 3.0
## 每天营业的游戏内分钟数（默认 60 分钟 = 1 小时，约 1 分钟真实时间）。
var minutes_per_day: int = 60

var day: int = 1
var game_minute: int = 0
## 时间倍速：同时缩放游戏分钟和真实秒机制（做菜/拖地/用餐计时），
## 保持两边时间尺度一致。演示模式调大它整体加速，普通游玩保持 1.0。
var speed_multiplier: float = 1.0
var is_paused: bool = false

var _accumulated: float = 0.0


func _process(delta: float) -> void:
	if is_paused:
		return
	# 只有营业中才走游戏时间：准备/打烊阶段看菜单、逛商店不烧天数
	if GameState.shop["day_state"] != "serving":
		return
	_accumulated += delta * speed_multiplier
	while _accumulated >= seconds_per_minute:
		_accumulated -= seconds_per_minute
		_advance_minute()


func _advance_minute() -> void:
	game_minute += 1
	EventBus.emit("clock.tick", game_minute)
	if game_minute >= minutes_per_day:
		_end_day()


func _end_day() -> void:
	EventBus.emit("clock.day_ended", day)
	day += 1
	game_minute = 0
	EventBus.emit("clock.day_started", day)


## 提前结束当前天（玩家点「提前打烊」时调用）。
func end_day_now() -> void:
	_end_day()


func pause() -> void:
	is_paused = true


func resume() -> void:
	is_paused = false
