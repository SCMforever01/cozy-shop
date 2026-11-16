class_name SaveSystem
extends System
## 存档系统：每天结束自动存档，启动时自动读档。
## 序列化/反序列化是纯函数（serialize/deserialize，可脱离单例单测），
## 实例方法只负责接线 GameState/GameClock。
## web 端 user:// 走 IndexedDB 持久化，原生端走真实文件。


const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 2


func setup() -> void:
	EventBus.subscribe("clock.day_ended", _on_day_ended)


func teardown() -> void:
	EventBus.unsubscribe("clock.day_ended", _on_day_ended)


func _on_day_ended(day) -> void:
	save(day + 1)


func save(next_day: int) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(serialize(next_day, GameState.shop, GameState.regulars))
	f.close()


## 读档，返回加载的天数（0 表示无存档）。
func load_game() -> int:
	if not FileAccess.file_exists(SAVE_PATH):
		return 0
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return 0
	var text := f.get_as_text()
	f.close()
	var data := deserialize(text)
	if data.is_empty():
		return 0
	GameClock.day = data["day"]
	GameState.shop["money"] = data["shop"]["money"]
	GameState.shop["reputation"] = data["shop"]["reputation"]
	GameState.shop["level"] = data["shop"]["level"]
	GameState.shop["upgrades"] = data["shop"]["upgrades"]
	# 只回填熟客的可变字段；名字/最爱等定义保留在代码里，
	# 避免旧存档缺字段或将来加新熟客时被存档覆盖丢定义。
	for saved in data["regulars"]:
		for r in GameState.regulars:
			if r["id"] == saved["id"]:
				r["relationship"] = saved["relationship"]
				r["visits"] = saved["visits"]
				r["lost"] = saved["lost"]
	return data["day"]


## 重置：清存档 + 内存状态回初始。
func reset() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	GameClock.day = 1
	GameClock.game_minute = 0
	GameState.shop["money"] = 100
	GameState.shop["reputation"] = 0
	GameState.shop["level"] = 1
	GameState.shop["upgrades"] = {"mop": 0, "stove": 0, "seat": 0, "ingredient": 0, "decor": 0}
	GameState.shop["ingredients"] = 0
	GameState.shop["holiday"] = false
	GameState.shop["skip_spoilage"] = false
	GameState.forecast_weather_id = ""
	GameState.equipment_broken_ticks = 0
	for s in GameState.seats:
		s["customer_id"] = -1
		s["dirty"] = false
	for r in GameState.regulars:
		r["relationship"] = 0
		r["visits"] = 0
		r["lost"] = false
	GameState.customers.clear()


# ---------- 纯序列化函数（可单测） ----------

## 把状态序列化为 JSON 文本。
## 熟客只存可变字段（relationship/visits/lost），定义字段（name/favorite）以代码为准。
static func serialize(next_day: int, shop: Dictionary, regulars: Array) -> String:
	var saved_regulars: Array = []
	for r in regulars:
		saved_regulars.append({
			"id": r["id"],
			"relationship": r["relationship"],
			"visits": r["visits"],
			"lost": r["lost"],
		})
	var data := {
		"version": SAVE_VERSION,
		"day": next_day,
		"shop": {
			"money": shop["money"],
			"reputation": shop["reputation"],
			"level": shop["level"],
			"upgrades": shop["upgrades"],
		},
		"regulars": saved_regulars,
	}
	return JSON.stringify(data)


## 解析存档文本，返回 {"day", "shop", "regulars"}。
## Godot 的 JSON 解析会把数字统一解成 float，这里逐字段归一化为 int，
## 避免读档后出现「金钱是浮点数」这类隐性 bug。
## 升级键按当前版本补齐（旧存档没有 seat/stove 等新键，缺省 0）；
## 兼容 v1 旧格式（熟客带完整字段）。解析失败或缺关键字段返回空字典。
static func deserialize(text: String) -> Dictionary:
	var data = JSON.parse_string(text)
	if data == null or not (data is Dictionary):
		return {}
	if not data.has("day") or not data.has("shop") or not (data["shop"] is Dictionary):
		return {}
	var shop: Dictionary = data["shop"]
	var upgrades = shop.get("upgrades", {})
	if not (upgrades is Dictionary):
		upgrades = {}
	var result := {
		"day": _to_int(data["day"], 1),
		"shop": {
			"money": _to_int(shop.get("money", 100), 100),
			"reputation": _to_int(shop.get("reputation", 0), 0),
			"level": _to_int(shop.get("level", 1), 1),
			"upgrades": {},
		},
		"regulars": [],
	}
	for k in ["mop", "stove", "seat", "ingredient", "decor"]:
		result["shop"]["upgrades"][k] = _to_int(upgrades.get(k, 0), 0)
	var regulars = data.get("regulars", [])
	if regulars is Array:
		for r in regulars:
			if not (r is Dictionary) or not r.has("id"):
				continue
			result["regulars"].append({
				"id": str(r["id"]),
				"relationship": _to_int(r.get("relationship", 0), 0),
				"visits": _to_int(r.get("visits", 0), 0),
				"lost": bool(r.get("lost", false)),
			})
	return result


static func _to_int(value, fallback: int) -> int:
	if value is int or value is float or value is bool:
		return int(value)
	return fallback
