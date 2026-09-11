class_name ShopSystem
extends System
## 店铺系统：营业状态机、金钱、每日营收汇总。


var _day_start_money: int = 0


func setup() -> void:
	EventBus.subscribe("clock.day_started", _on_day_started)
	EventBus.subscribe("clock.day_ended", _on_day_ended)


func teardown() -> void:
	EventBus.unsubscribe("clock.day_started", _on_day_started)
	EventBus.unsubscribe("clock.day_ended", _on_day_ended)


func _on_day_started(_day) -> void:
	GameState.shop["day_state"] = "preparing"
	GameState.shop["hygiene"] = 100.0
	_day_start_money = GameState.shop["money"]


func _on_day_ended(day) -> void:
	GameState.shop["day_state"] = "closed"
	var earned: int = GameState.shop["money"] - _day_start_money
	EventBus.emit("day.summary", {"day": day, "earned": earned, "reputation": GameState.shop["reputation"]})


func open_shop() -> void:
	if GameState.shop["day_state"] == "preparing":
		GameState.shop["day_state"] = "serving"
