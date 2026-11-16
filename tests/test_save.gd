extends SceneTree
## SaveSystem 序列化/反序列化纯函数测试（v2：5 类升级 / 熟客瘦身存档）。
## 运行：godot --headless --script res://tests/test_save.gd

var _failed: int = 0


func _initialize() -> void:
	var S = load("res://scripts/systems/save_system.gd")

	var shop := {
		"money": 345, "reputation": 7, "level": 2,
		"upgrades": {"mop": 1, "stove": 2, "seat": 1, "ingredient": 0, "decor": 3},
	}
	var regulars := [
		{"id": "laozhang", "name": "老张", "favorite": "milk_tea", "relationship": 2, "visits": 5, "lost": false},
		{"id": "xiaowang", "name": "小王", "favorite": "coffee", "relationship": -2, "visits": 1, "lost": true},
	]

	# 往返：数字与布尔完整保留，且类型归一化为 int/bool
	var text: String = S.serialize(4, shop, regulars)
	var data: Dictionary = S.deserialize(text)
	_check(data["day"] == 4 and data["day"] is int, "day 往返且为 int")
	_check(data["shop"]["money"] == 345 and data["shop"]["money"] is int, "money 往返且为 int")
	_check(data["shop"]["reputation"] is int and data["shop"]["level"] is int, "reputation/level 为 int")
	_check(data["shop"]["upgrades"]["mop"] is int and data["shop"]["upgrades"]["stove"] == 2, "升级字段往返且为 int")
	_check(data["shop"]["upgrades"]["seat"] == 1 and data["shop"]["upgrades"]["decor"] == 3, "seat/decor 升级往返")
	_check(data["regulars"].size() == 2, "熟客数量往返")
	var rz: Dictionary = data["regulars"][0]
	_check(rz["id"] == "laozhang" and rz["relationship"] is int and rz["visits"] == 5, "熟客字段往返且为 int")
	_check(data["regulars"][1]["lost"] == true, "熟客 lost 布尔往返")

	# 数字全 float 的文本（模拟 JSON 解析行为）也能归一化为 int
	var float_text := '{"day": 2.0, "shop": {"money": 12.5, "reputation": 3.0, "level": 1.0, "upgrades": {"mop": 2.0}}, "regulars": []}'
	var fd: Dictionary = S.deserialize(float_text)
	_check(fd["day"] == 2 and fd["day"] is int, "float day 归一化为 int")
	_check(fd["shop"]["money"] == 12 and fd["shop"]["money"] is int, "float money 截断为 int")

	# v1 旧格式（熟客带 name/favorite 等完整字段、升级缺新键）兼容
	var v1_text := '{"day": 3, "shop": {"money": 250, "reputation": 4, "level": 1, "upgrades": {"mop": 1, "ingredient": 0, "decor": 0}}, "regulars": [{"id": "laozhang", "name": "老张", "favorite": "milk_tea", "relationship": 2, "visits": 5, "lost": false}]}'
	var v1: Dictionary = S.deserialize(v1_text)
	_check(v1["day"] == 3, "v1 旧格式 day 解析")
	_check(v1["shop"]["upgrades"]["stove"] == 0 and v1["shop"]["upgrades"]["seat"] == 0, "旧存档缺升级键补 0")
	_check(v1["regulars"].size() == 1 and v1["regulars"][0]["relationship"] == 2, "v1 旧格式熟客解析")

	# 脏数据防御：坏 JSON / 缺字段 / 类型错乱都不崩，返回空或默认值
	_check(S.deserialize("not json at all").is_empty(), "坏 JSON 返回空字典")
	_check(S.deserialize('{"shop": {}}').is_empty(), "缺 day 返回空字典")
	_check(S.deserialize('[]').is_empty(), "非对象 JSON 返回空字典")
	var partial: Dictionary = S.deserialize('{"day": 5, "shop": {"money": "abc"}}')
	_check(partial["shop"]["money"] == 100 and partial["shop"]["upgrades"]["mop"] == 0, "坏字段回退默认值")

	if _failed == 0:
		print("PASS: SaveSystem 全部用例通过")
	else:
		print("FAIL: %d 个用例失败" % _failed)

	quit(_failed)


func _check(cond: bool, name: String) -> void:
	if cond:
		print("  PASS: %s" % name)
	else:
		_failed += 1
		print("  FAIL: %s" % name)
