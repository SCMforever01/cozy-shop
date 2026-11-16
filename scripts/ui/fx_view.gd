class_name FxView
extends UIView
## 特效与提示层：飘字、雨滴、事件提示。
## 事件提示用数据表驱动（TOASTS）：加一条事件提示 = 加一行数据。
## 特殊逻辑（天气切雨、顾客入场、厨房受阻、季节变化）用具名方法单独处理。


## 事件 -> 飘字提示：fmt 为翻译键，args 为 payload 字段名（字符串值自动 tr，数值自动取整）。
const TOASTS := [
	{"event": "customer.served", "fmt": "+¥%d", "args": ["earned"], "color": Color(0.2, 0.8, 0.3)},
	{"event": "customer.left_angry", "fmt": "差评 -1", "args": [], "color": Color(0.9, 0.3, 0.3)},
	{"event": "customer.left_no_seat", "fmt": "没座位，客人走了", "args": [], "color": Color(0.85, 0.55, 0.4)},
	{"event": "day.summary", "fmt": "第%d天营收¥%d", "args": ["day", "earned"], "color": Color(0.95, 0.85, 0.25)},
	{"event": "regular.lost", "fmt": "%s不来了…", "args": ["name"], "color": Color(0.85, 0.4, 0.6)},
	{"event": "regular.celebrate", "fmt": "%s今天生日，特别开心！", "args": ["name"], "color": Color(1.0, 0.6, 0.8)},
	{"event": "regular.gift", "fmt": "%s送你一份礼物(+¥50)！", "args": ["name"], "color": Color(1.0, 0.8, 0.4)},
	{"event": "regular.brings_friend", "fmt": "%s介绍了个朋友来！", "args": ["name"], "color": Color(0.6, 0.9, 0.6)},
	{"event": "event.food_critic", "fmt": "美食评论家来了！", "args": [], "color": Color(0.75, 0.45, 0.95)},
	{"event": "event.rush_hour", "fmt": "客流高峰！", "args": [], "color": Color(0.95, 0.55, 0.2)},
	{"event": "event.inspect_fail", "fmt": "卫生检查不合格！罚款¥%d", "args": ["fine"], "color": Color(0.9, 0.3, 0.3)},
	{"event": "event.inspect_pass", "fmt": "卫生检查合格 ✓", "args": [], "color": Color(0.3, 0.8, 0.4)},
	{"event": "event.equipment_failure", "fmt": "设备故障！暂时不能做菜", "args": [], "color": Color(0.6, 0.5, 0.5)},
	{"event": "event.holiday", "fmt": "节日促销！今日菜品加价30%", "args": [], "color": Color(1.0, 0.75, 0.3)},
	{"event": "kitchen.burnt", "fmt": "糊了！食材报废，客人气走了", "args": [], "color": Color(0.9, 0.3, 0.25)},
	{"event": "dish.ready", "fmt": "✓ 可以上菜了", "args": [], "color": Color(0.3, 0.85, 0.4)},
	{"event": "ingredients.spoiled", "fmt": "食材过期，浪费 %d 份", "args": ["amount"], "color": Color(0.85, 0.6, 0.3)},
	{"event": "ingredients.empty", "fmt": "食材不足！开店前采购", "args": [], "color": Color(0.9, 0.4, 0.2)},
	{"event": "upgrade.bought", "fmt": "%s升级到 Lv%d！", "args": ["name", "level"], "color": Color(0.4, 0.8, 0.9)},
]

const FLOATER_LIFETIME := 1.2

var _floaters: Array = []  # {text, pos, age, color}
var _bound: Array = []     # {event, callable}，退出时取消订阅用


func _ready() -> void:
	for entry in TOASTS:
		var cb := _make_toast_handler(entry)
		EventBus.subscribe(entry["event"], cb)
		_bound.append({"event": entry["event"], "callable": cb})
	EventBus.subscribe("weather.changed", _on_weather_changed)
	EventBus.subscribe("customer.entered", _on_customer_entered)
	EventBus.subscribe("season.changed", _on_season_changed)
	EventBus.subscribe("kitchen.blocked", _on_kitchen_blocked)


func _exit_tree() -> void:
	for b in _bound:
		EventBus.unsubscribe(b["event"], b["callable"])
	EventBus.unsubscribe("weather.changed", _on_weather_changed)
	EventBus.unsubscribe("customer.entered", _on_customer_entered)
	EventBus.unsubscribe("season.changed", _on_season_changed)
	EventBus.unsubscribe("kitchen.blocked", _on_kitchen_blocked)


## 生成一条飘字提示（其他层也调用它，如「已读档」「进度已重置」）。
func spawn_floater(text: String, color: Color) -> void:
	print(text)
	_floaters.append({"text": text, "pos": Vector2(GameLayout.W * 0.5, GameLayout.H * 0.45), "age": 0.0, "color": color})


# ---------- 数据表驱动的提示 ----------

func _make_toast_handler(entry: Dictionary) -> Callable:
	return func(payload):
		var args: Array = []
		for key in entry["args"]:
			var v = payload[key]
			if v is String:
				v = tr(v)
			elif v is float:
				v = int(v)
			args.append(v)
		var text: String = tr(entry["fmt"])
		if args.size() > 0:
			text = text % args
		spawn_floater(text, entry["color"])


# ---------- 特殊提示（带条件 / 带副作用） ----------

func _on_weather_changed(weather_id: String) -> void:
	if weather_id == "typhoon":
		spawn_floater(tr("台风来袭！建议歇业"), Color(0.9, 0.4, 0.4))
	elif weather_id == "storm":
		spawn_floater(tr("暴雨来袭"), Color(0.5, 0.6, 0.9))


func _on_customer_entered(p) -> void:
	if p["name"] != "客人" and p["name"] != "美食评论家":
		if p.get("celebrating", false):
			spawn_floater(tr("%s今天生日！") % tr(p["name"]), Color(1.0, 0.6, 0.8))
		else:
			spawn_floater(tr("%s来了！") % tr(p["name"]), Color(1.0, 0.85, 0.4))


func _on_season_changed(season) -> void:
	spawn_floater(tr("进入%s天") % tr(Catalog.get_season_name(season)), Color(0.7, 0.8, 1.0))


func _on_kitchen_blocked(p) -> void:
	var text: String = tr("工位被占满了！") if str(p.get("reason", "")) == "occupied" else tr("设备故障中…")
	spawn_floater(text, Color(0.7, 0.5, 0.4))


# ---------- 动画与绘制 ----------

func _animate(delta: float) -> void:
	for f in _floaters:
		f["age"] += delta
		f["pos"].y -= 45.0 * delta
	_floaters = _floaters.filter(func(f): return f["age"] < FLOATER_LIFETIME)


func _draw() -> void:
	for f in _floaters:
		var alpha := clampf(1.0 - f["age"] / FLOATER_LIFETIME, 0.0, 1.0)
		var c: Color = f["color"]
		c.a = alpha
		UITheme.label(self, font, f["pos"], f["text"], 24, c, HORIZONTAL_ALIGNMENT_CENTER)
