class_name Catalog
extends RefCounted
## 游戏内容数据目录：菜谱、客人类型、天气。
## 加新菜/新客人/新天气 = 在这里加条目，不改任何逻辑代码。


static func get_recipes() -> Array:
	return [
		_make_recipe("milk_tea", "奶茶", ["加茶", "加奶"], 10),
		_make_recipe("coffee", "咖啡", ["研磨", "冲泡"], 12),
		_make_recipe("sandwich", "三明治", ["切面包", "夹料", "装盘"], 15),
		_make_recipe("juice", "果汁", ["切水果", "榨汁"], 8),
	]


static func get_recipe_by_id(id: String) -> Recipe:
	for r in get_recipes():
		if r.id == id:
			return r
	return null


static func get_weather() -> Dictionary:
	return {
		"sunny": _make_weather("sunny", "晴", 1.0, 1.0, 0.0),
		"rain": _make_weather("rain", "雨", 0.55, 1.5, -15.0),
	}


static func _make_recipe(id: String, name: String, steps: Array, price: int) -> Recipe:
	var r := Recipe.new()
	r.id = id
	r.display_name = name
	r.steps = steps
	r.price = price
	return r


static func _make_weather(id: String, name: String, traffic: float, hygiene_decay: float, environment: float) -> WeatherType:
	var w := WeatherType.new()
	w.id = id
	w.display_name = name
	w.customer_traffic_modifier = traffic
	w.hygiene_decay_modifier = hygiene_decay
	w.environment_modifier = environment
	return w
