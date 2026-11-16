class_name Catalog
extends RefCounted
## 游戏内容数据目录：菜谱、客人类型、天气。
## 加新菜/新客人/新天气 = 在这里加条目，不改任何逻辑代码。
## 数据只构建一次并缓存（绘制每帧都会查菜谱/升级，避免反复创建对象产生 GC 压力）。

static var _recipes: Array = []
static var _recipe_index: Dictionary = {}
static var _weather: Dictionary = {}
static var _upgrades: Dictionary = {}


static func get_recipes() -> Array:
	if _recipes.is_empty():
		_recipes = [
			_make_recipe("milk_tea", "奶茶", [_step("加茶", "stove", 4), _step("加奶", "plate", 2)], 10, 0, "winter", Color(0.75, 0.55, 0.35)),
			_make_recipe("juice", "果汁", [_step("切水果", "prep", 3), _step("榨汁", "stove", 4)], 8, 0, "summer", Color(1.00, 0.60, 0.20)),
			_make_recipe("coffee", "咖啡", [_step("研磨", "prep", 3), _step("冲泡", "stove", 5)], 12, 0, "winter", Color(0.45, 0.30, 0.20)),
			_make_recipe("sandwich", "三明治", [_step("切面包", "prep", 3), _step("夹料", "prep", 3), _step("装盘", "plate", 2)], 15, 5, "spring", Color(0.92, 0.72, 0.30)),
			_make_recipe("salad", "沙拉", [_step("洗菜", "prep", 3), _step("切菜", "prep", 3), _step("拌酱", "plate", 2)], 14, 8, "spring", Color(0.50, 0.80, 0.40)),
			_make_recipe("burger", "汉堡", [_step("烤面包", "stove", 4), _step("煎肉", "stove", 6), _step("夹料", "plate", 2)], 18, 10, "autumn", Color(0.60, 0.38, 0.18)),
			_make_recipe("cake", "蛋糕", [_step("打面糊", "prep", 4), _step("烘焙", "stove", 7), _step("裱花", "plate", 3)], 20, 15, "spring", Color(0.95, 0.62, 0.75)),
			_make_recipe("soup", "热汤", [_step("切菜", "prep", 3), _step("炖煮", "stove", 8), _step("调味", "plate", 2)], 24, 18, "winter", Color(0.90, 0.60, 0.30)),
			_make_recipe("ice_cream", "冰淇淋", [_step("挖球", "prep", 3), _step("淋酱", "plate", 2), _step("装杯", "plate", 2)], 22, 22, "summer", Color(0.95, 0.85, 0.90)),
			_make_recipe("pizza", "披萨", [_step("揉面", "prep", 4), _step("铺料", "prep", 3), _step("烘烤", "stove", 8)], 28, 28, "autumn", Color(0.85, 0.50, 0.30)),
		]
		for r in _recipes:
			_recipe_index[r.id] = r
	return _recipes


## 制作步骤：name=步骤名，station=工位（prep 备菜台 / stove 灶台 / plate 装盘台），sec=耗时（真实秒）。
static func _step(name: String, station: String, sec: float) -> Dictionary:
	return {"name": name, "station": station, "sec": sec}


## 根据口碑返回已解锁的菜谱（口碑低于 unlock_reputation 的菜不出现）。
static func get_unlocked_recipes(reputation: int) -> Array:
	var result: Array = []
	for r in get_recipes():
		if reputation >= r.unlock_reputation:
			result.append(r)
	return result


## 四季顺序，每 7 天一个季节。
const SEASONS := ["spring", "summer", "autumn", "winter"]


static func get_season_name(id: String) -> String:
	match id:
		"spring":
			return "春"
		"summer":
			return "夏"
		"autumn":
			return "秋"
		"winter":
			return "冬"
	return id


static func get_season_for_day(day: int) -> String:
	return SEASONS[int((day - 1) / 7.0) % 4]


static func get_recipe_by_id(id: String) -> Recipe:
	get_recipes()  # 触发懒加载
	return _recipe_index.get(id)


static func get_weather() -> Dictionary:
	if _weather.is_empty():
		_weather = {
			"sunny": _make_weather("sunny", "晴", 1.0, 1.0, 0.0, 1.0),
			"overcast": _make_weather("overcast", "阴", 0.85, 1.0, -8.0, 1.0),
			"rain": _make_weather("rain", "雨", 0.55, 1.5, -15.0, 1.2),
			"storm": _make_weather("storm", "暴雨", 0.30, 1.8, -25.0, 1.35),
			"typhoon": _make_weather("typhoon", "台风", 0.10, 1.0, -35.0, 1.5),
		}
	return _weather


## 设备升级目录：costs 为各级花费（长度即为最大等级）。
## v2 P3 决策感：钱只够买一部分，每一档都是真取舍。
static func get_upgrades() -> Dictionary:
	if _upgrades.is_empty():
		_upgrades = {
			"mop": {"name": "高级拖把", "costs": [150, 300, 500], "desc": "拖地更快更净"},
			"stove": {"name": "快灶台", "costs": [200, 400], "desc": "烹饪提速 25%"},
			"seat": {"name": "座位扩建", "costs": [300], "desc": "加一张餐桌"},
			"ingredient": {"name": "优质食材", "costs": [200, 400, 600], "desc": "菜品售价更高"},
			"decor": {"name": "舒适装修", "costs": [150, 300, 450], "desc": "环境更舒适"},
		}
	return _upgrades


static func _make_recipe(id: String, name: String, steps: Array, price: int, unlock_reputation: int, season: String, fallback_color: Color) -> Recipe:
	var r := Recipe.new()
	r.id = id
	r.display_name = name
	r.steps = steps
	r.price = price
	r.unlock_reputation = unlock_reputation
	r.season = season
	r.fallback_color = fallback_color
	return r


static func _make_weather(id: String, name: String, traffic: float, hygiene_decay: float, environment: float, price: float) -> WeatherType:
	var w := WeatherType.new()
	w.id = id
	w.display_name = name
	w.customer_traffic_modifier = traffic
	w.hygiene_decay_modifier = hygiene_decay
	w.environment_modifier = environment
	w.price_modifier = price
	return w
