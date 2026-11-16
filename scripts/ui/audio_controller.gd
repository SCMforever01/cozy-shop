class_name AudioController
extends Node
## 音频控制层：把游戏事件映射到音效（SFX_EVENTS 数据表），并驱动氛围声（雨声 / 煎炒声）。
## 加一条音效映射 = 加一行数据。底层播放由 AudioManager 负责。


## 事件 -> 音效：key 为 AudioManager.SFX 的键，volume 为音量（dB）。
## only 为可选过滤：payload 与之相等才播（如 weather.changed 只在台风时播）。
## match 为可选字段过滤：payload 字段等于 value 才播（如按熟客名触发专属语音）。
## chance 为可选触发概率（0~1，如上菜满意语音只在部分时候播）。
const SFX_EVENTS := [
	{"event": "customer.entered", "key": "door", "volume": -6.0},
	{"event": "customer.served", "key": "coin", "volume": 0.0},
	{"event": "customer.left_angry", "key": "deny", "volume": -4.0},
	{"event": "customer.left_no_seat", "key": "deny", "volume": -4.0},
	{"event": "kitchen.burnt", "key": "burn", "volume": -2.0},
	{"event": "dish.step_done", "key": "pickup", "volume": -6.0},
	{"event": "dish.ready", "key": "accept", "volume": -4.0},
	{"event": "upgrade.bought", "key": "upgrade", "volume": -4.0},
	{"event": "hygiene.mopped", "key": "mop", "volume": -8.0},
	{"event": "day.summary", "key": "summary", "volume": -6.0},
	{"event": "clock.day_started", "key": "open", "volume": -10.0},
	{"event": "weather.changed", "key": "typhoon", "volume": -2.0, "only": "typhoon"},
	# 角色语音（Breeze TTS）
	{"event": "shop.opened", "key": "voice_welcome", "volume": -2.0},
	{"event": "customer.entered", "key": "voice_laozhang", "volume": -3.0, "match": {"key": "name", "value": "老张"}},
	{"event": "customer.entered", "key": "voice_xiaowang", "volume": -3.0, "match": {"key": "name", "value": "小王"}},
	{"event": "customer.entered", "key": "voice_lijie", "volume": -3.0, "match": {"key": "name", "value": "李姐"}},
	{"event": "customer.entered", "key": "voice_critic", "volume": -3.0, "match": {"key": "name", "value": "美食评论家"}},
	{"event": "regular.celebrate", "key": "voice_birthday", "volume": -2.0},
	{"event": "customer.served", "key": "voice_thanks", "volume": -4.0, "chance": 0.3},
	{"event": "customer.left_angry", "key": "voice_angry", "volume": -3.0, "chance": 0.5},
	# 反应 / 拟声类音效
	{"event": "order.taken", "key": "voice_ok", "volume": -4.0, "chance": 0.6},
	{"event": "customer.served", "key": "voice_serve", "volume": -3.0, "chance": 0.7},
	{"event": "dish.ready", "key": "voice_ding", "volume": -4.0, "chance": 0.5},
	{"event": "kitchen.burnt", "key": "voice_burn", "volume": -2.0},
	{"event": "hygiene.mopped", "key": "voice_mop", "volume": -4.0, "chance": 0.5},
	{"event": "day.summary", "key": "voice_bye", "volume": -3.0},
	{"event": "customer.left_no_seat", "key": "voice_noseat", "volume": -4.0, "chance": 0.6},
	{"event": "customer.dined", "key": "voice_yummy", "volume": -4.0, "chance": 0.4},
]

var audio: AudioManager
## 由主场景注入：煎炒声要看灶台有没有菜在做。
var kitchen: KitchenSystem

var _bound: Array = []  # {event, callable}


func _ready() -> void:
	audio = AudioManager.new()
	add_child(audio)
	for entry in SFX_EVENTS:
		var cb := _make_sfx_handler(entry)
		EventBus.subscribe(entry["event"], cb)
		_bound.append({"event": entry["event"], "callable": cb})


func _exit_tree() -> void:
	for b in _bound:
		EventBus.unsubscribe(b["event"], b["callable"])


func _process(_delta: float) -> void:
	# 氛围声：雨声（天气）/ 煎炒声（灶台开工）
	audio.set_rain(GameState.weather_id in ["rain", "storm", "typhoon"])
	var cooking := false
	for s in kitchen.stations:
		if s["phase"] == "cooking":
			cooking = true
			break
	audio.set_sizzle(cooking)


func toggle() -> void:
	audio.toggle()


func is_enabled() -> bool:
	return audio.enabled


## 直接播一个音效（如点击声）。
func play_sfx(key: String, volume_db: float = 0.0) -> void:
	audio.play_sfx(key, volume_db)


func _make_sfx_handler(entry: Dictionary) -> Callable:
	return func(payload):
		if entry.has("only") and str(payload) != str(entry["only"]):
			return
		if entry.has("match"):
			var m: Dictionary = entry["match"]
			if not (payload is Dictionary) or str(payload.get(m["key"], "")) != str(m["value"]):
				return
		if entry.has("chance") and randf() > entry["chance"]:
			return
		audio.play_sfx(entry["key"], entry["volume"])
