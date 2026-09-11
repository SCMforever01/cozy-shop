class_name SaveSystem
extends System
## 存档系统：每天结束自动存档，启动时自动读档。
## web 端 user:// 走 IndexedDB 持久化，原生端走真实文件。


const SAVE_PATH := "user://save.json"


func setup() -> void:
	EventBus.subscribe("clock.day_ended", _on_day_ended)


func teardown() -> void:
	EventBus.unsubscribe("clock.day_ended", _on_day_ended)


func _on_day_ended(day) -> void:
	save(day + 1)


func save(next_day: int) -> void:
	var data := {
		"day": next_day,
		"shop": {
			"money": GameState.shop["money"],
			"reputation": GameState.shop["reputation"],
			"level": GameState.shop["level"],
			"upgrades": GameState.shop["upgrades"],
		},
		"regulars": GameState.regulars,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()


## 读档，返回加载的天数（0 表示无存档）。
func load() -> int:
	if not FileAccess.file_exists(SAVE_PATH):
		return 0
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return 0
	var text := f.get_as_text()
	f.close()
	var data = JSON.parse_string(text)
	if data == null:
		return 0
	GameClock.day = int(data["day"])
	GameState.shop["money"] = int(data["shop"]["money"])
	GameState.shop["reputation"] = int(data["shop"]["reputation"])
	GameState.shop["level"] = int(data["shop"]["level"])
	GameState.shop["upgrades"] = data["shop"]["upgrades"]
	GameState.regulars = data["regulars"]
	return int(data["day"])


## 重置：清存档 + 内存状态回初始。
func reset() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	GameClock.day = 1
	GameClock.game_minute = 0
	GameState.shop["money"] = 100
	GameState.shop["reputation"] = 0
	GameState.shop["level"] = 1
	GameState.shop["upgrades"] = {"mop": 0, "ingredient": 0, "decor": 0}
	for r in GameState.regulars:
		r["relationship"] = 0
		r["visits"] = 0
		r["lost"] = false
	GameState.customers.clear()
