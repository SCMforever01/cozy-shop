class_name AutoPlay
extends Node
## 自动演示控制器：自动进货 / 开门 / 接单 / 派工位 / 取走 / 上菜 / 拖地 / 收桌。
## 用于快速看效果和冒烟测试：godot --headless --quit-after N -- --autoplay


var shop_system: ShopSystem
var hygiene_system: HygieneSystem
var customer_system: CustomerSystem
var kitchen_system: KitchenSystem


func _process(_delta: float) -> void:
	match GameState.shop["day_state"]:
		"preparing":
			shop_system.buy_ingredients(15, 35)
			shop_system.buy_ingredients(15, 35)
			shop_system.open_shop()
		"serving":
			if GameState.shop["hygiene"] < 40.0:
				hygiene_system.start_mop()
			for seat in GameState.seats:
				if seat["dirty"]:
					customer_system.clean_seat(seat["id"])
			for c in GameState.customers.duplicate():
				match c["state"]:
					"waiting":
						customer_system.take_order(c["id"])
					"being_served":
						kitchen_system.tap_dish(c["id"])
					"ready":
						customer_system.serve(c["id"])
