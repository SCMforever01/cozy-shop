class_name Catalog
extends RefCounted
## 游戏内容数据目录：菜谱、客人类型、天气。
## 加新菜/新客人/新天气 = 在这里加条目，不改任何逻辑代码。


static func get_recipes() -> Array:
	return [
		_make_recipe("milk_tea", "奶茶", ["加茶", "加奶"], 10, 0),
		_make_recipe("juice", "果汁", ["切水果", "榨汁"], 8, 0),
		_make_recipe("coffee", "咖啡", ["研磨", "冲泡"], 12, 0),
		_make_recipe("sandwich", "三明治", ["切面包", "夹料", "装盘"], 15, 5),
		_make_recipe("burger", "汉堡", ["烤面包", "煎肉", "夹料"], 18, 10),
		_make_recipe("cake", "蛋糕", ["打面糊", "烘焙", "裱花"], 20, 15),
	]


## 根据口碑返回已解锁的菜谱（口碑低于 unlock_reputation 的菜不出现）。
static func get_unlocked_recipes(reputation: int) -> Array:
	var result: Array = []
	for r in get_recipes():
		if reputation >= r.unlock_reputation:
			result.append(r)
	return result


static func get_recipe_by_id(id: String) -> Recipe:
	for r in get_recipes():
		if r.id == id:
			return r
	return null


static func get_weather() -> Dictionary:
	return {
		"sunny": _make_weather("sunny", "晴", 1.0, 1.0, 0.0),
		"overcast": _make_weather("overcast", "阴", 0.85, 1.0, -8.0),
		"rain": _make_weather("rain", "雨", 0.55, 1.5, -15.0),
		"storm": _make_weather("storm", "暴雨", 0.30, 1.8, -25.0),
		"typhoon": _make_weather("typhoon", "台风", 0.10, 1.0, -35.0),
	}


static func _make_recipe(id: String, name: String, steps: Array, price: int, unlock_reputation: int) -> Recipe:
	var r := Recipe.new()
	r.id = id
	r.display_name = name
	r.steps = steps
	r.price = price
	r.unlock_reputation = unlock_reputation
	return r


static func _make_weather(id: String, name: String, traffic: float, hygiene_decay: float, environment: float) -> WeatherType:
	var w := WeatherType.new()
	w.id = id
	w.display_name = name
	w.customer_traffic_modifier = traffic
	w.hygiene_decay_modifier = hygiene_decay
	w.environment_modifier = environment
	return w
