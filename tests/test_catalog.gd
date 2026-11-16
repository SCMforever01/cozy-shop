extends SceneTree
## Catalog 数据完整性测试（v2：工位步骤 / 天气加价 / 升级目录）。
## 运行：godot --headless --script res://tests/test_catalog.gd

var _failed: int = 0


func _initialize() -> void:
	var C = load("res://data/catalog.gd")

	# 菜谱：10 道、id 唯一、价格/步骤/颜色齐全，步骤指向合法工位
	var recipes: Array = C.get_recipes()
	_check(recipes.size() == 10, "有 10 道菜（实际 %d）" % recipes.size())
	var ids := {}
	var ok := true
	for r in recipes:
		if ids.has(r.id) or r.id == "" or r.price <= 0 or r.steps.is_empty():
			ok = false
		if r.fallback_color.a < 1.0:
			ok = false
		for step in r.steps:
			if not (step["station"] in ["prep", "stove", "plate"]) or step["sec"] <= 0.0:
				ok = false
		ids[r.id] = true
	_check(ok, "菜谱 id 唯一且步骤/工位/颜色齐全")

	# 缓存：多次调用返回同一批对象（不重复建对象）
	_check(C.get_recipes()[0] == recipes[0], "菜谱缓存生效（同一实例）")
	_check(C.get_recipe_by_id("milk_tea") == C.get_recipe_by_id("milk_tea"), "get_recipe_by_id 缓存生效")
	_check(C.get_recipe_by_id("milk_tea").display_name == "奶茶", "按 id 查到正确菜谱")
	_check(C.get_recipe_by_id("no_such_dish") == null, "未知 id 返回 null")

	# 解锁过滤：口碑 0 只解锁低门槛菜；口碑满解锁全部
	var unlocked_low: Array = C.get_unlocked_recipes(0)
	var unlocked_all: Array = C.get_unlocked_recipes(999)
	var ok_filter := true
	for r in unlocked_low:
		if r.unlock_reputation > 0:
			ok_filter = false
	_check(ok_filter and unlocked_low.size() < unlocked_all.size(), "口碑过滤生效")
	_check(unlocked_all.size() == recipes.size(), "高口碑解锁全部菜")

	# 天气：5 种齐全，系数在合理范围，雨天起有单价加成
	var weather: Dictionary = C.get_weather()
	_check(weather.size() == 5, "有 5 种天气（实际 %d）" % weather.size())
	var ok_weather := true
	for id in ["sunny", "overcast", "rain", "storm", "typhoon"]:
		if not weather.has(id):
			ok_weather = false
			continue
		var w = weather[id]
		if w.customer_traffic_modifier <= 0 or w.hygiene_decay_modifier <= 0 or w.price_modifier <= 0:
			ok_weather = false
	_check(ok_weather, "天气 id 齐全且系数有效")
	_check(weather["rain"].price_modifier > 1.0 and weather["sunny"].price_modifier == 1.0, "雨天有单价加成、晴天没有")
	_check(C.get_weather() == weather, "天气缓存生效")

	# 升级目录：5 类，costs 非空且递增
	var upgrades: Dictionary = C.get_upgrades()
	var ok_upgrades := upgrades.size() == 5
	for key in ["mop", "stove", "seat", "ingredient", "decor"]:
		if not upgrades.has(key):
			ok_upgrades = false
			continue
		var costs: Array = upgrades[key]["costs"]
		if costs.is_empty():
			ok_upgrades = false
		for i in range(1, costs.size()):
			if costs[i] <= costs[i - 1]:
				ok_upgrades = false
	_check(ok_upgrades, "升级目录 5 类且花费递增")
	_check(C.get_upgrades() == upgrades, "升级目录缓存生效")

	# 季节：每 7 天轮换，春→夏→秋→冬
	_check(C.get_season_for_day(1) == "spring", "第 1 天是春")
	_check(C.get_season_for_day(7) == "spring", "第 7 天仍是春")
	_check(C.get_season_for_day(8) == "summer", "第 8 天入夏")
	_check(C.get_season_for_day(15) == "autumn", "第 15 天入秋")
	_check(C.get_season_for_day(22) == "winter", "第 22 天入冬")
	_check(C.get_season_for_day(29) == "spring", "第 29 天回春")
	_check(C.get_season_name("winter") == "冬", "季节名映射")

	if _failed == 0:
		print("PASS: Catalog 全部用例通过")
	else:
		print("FAIL: %d 个用例失败" % _failed)

	quit(_failed)


func _check(cond: bool, name: String) -> void:
	if cond:
		print("  PASS: %s" % name)
	else:
		_failed += 1
		print("  FAIL: %s" % name)
