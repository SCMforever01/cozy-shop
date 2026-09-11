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


## 购买设备升级。category 为 "mop"/"ingredient"/"decor"。
func buy_upgrade(category: String) -> void:
	var info: Dictionary = Catalog.get_upgrades()[category]
	var level: int = GameState.shop["upgrades"][category]
	if level >= 3:
		return
	var cost: int = info["costs"][level]
	if GameState.shop["money"] < cost:
		return
	GameState.shop["money"] -= cost
	GameState.shop["upgrades"][category] = level + 1
	EventBus.emit("upgrade.bought", {"name": info["name"], "level": level + 1})
