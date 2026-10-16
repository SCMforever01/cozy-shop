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
	GameState.shop["holiday"] = false
	_day_start_money = GameState.shop["money"]


func _on_day_ended(day) -> void:
	GameState.shop["day_state"] = "closed"
	# 食材过期：当天结束损耗 20%（台风歇业豁免 = 「关门保库存」）
	if GameState.shop["skip_spoilage"]:
		GameState.shop["skip_spoilage"] = false
	else:
		var spoil: int = int(GameState.shop["ingredients"] * 0.2)
		if spoil > 0:
			GameState.shop["ingredients"] -= spoil
			EventBus.emit("ingredients.spoiled", {"amount": spoil})
	var earned: int = GameState.shop["money"] - _day_start_money
	EventBus.emit("day.summary", {"day": day, "earned": earned, "reputation": GameState.shop["reputation"]})


func open_shop() -> void:
	if GameState.shop["day_state"] == "preparing":
		GameState.shop["day_state"] = "serving"


## 购买设备升级。category 见 Catalog.get_upgrades()。
func buy_upgrade(category: String) -> void:
	var info: Dictionary = Catalog.get_upgrades()[category]
	var level: int = GameState.shop["upgrades"][category]
	if level >= info["costs"].size():
		return
	var cost: int = info["costs"][level]
	if GameState.shop["money"] < cost:
		return
	GameState.shop["money"] -= cost
	GameState.shop["upgrades"][category] = level + 1
	EventBus.emit("upgrade.bought", {"name": info["name"], "level": level + 1})


## 采购食材：大份单价更低，但囤多了过期会浪费（v2 P3 采购取舍）。
func buy_ingredients(amount: int, cost: int) -> void:
	if GameState.shop["money"] < cost:
		return
	GameState.shop["money"] -= cost
	GameState.shop["ingredients"] += amount
