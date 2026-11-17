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
var _taps: Array = []      # 点击反馈：{pos, age} 扩散圆环
var _summary: Dictionary = {}   # 日结面板：{day, earned, served, burnt, angry, spoiled, age}
var _day_stats := {"served": 0, "burnt": 0, "angry": 0, "spoiled": 0}
var _warned_closing: bool = false
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
	EventBus.subscribe("day.summary", _on_day_summary)
	# 日结面板统计
	EventBus.subscribe("customer.served", func(_p): _day_stats["served"] += 1)
	EventBus.subscribe("kitchen.burnt", func(_p): _day_stats["burnt"] += 1)
	EventBus.subscribe("customer.left_angry", func(_p): _day_stats["angry"] += 1)
	EventBus.subscribe("customer.left_no_seat", func(_p): _day_stats["angry"] += 1)
	EventBus.subscribe("ingredients.spoiled", func(_p): _day_stats["spoiled"] += 1)
	EventBus.subscribe("clock.tick", _on_tick)


func _exit_tree() -> void:
	for b in _bound:
		EventBus.unsubscribe(b["event"], b["callable"])
	EventBus.unsubscribe("weather.changed", _on_weather_changed)
	EventBus.unsubscribe("customer.entered", _on_customer_entered)
	EventBus.unsubscribe("season.changed", _on_season_changed)
	EventBus.unsubscribe("kitchen.blocked", _on_kitchen_blocked)


## 点击反馈：在点击处画一圈扩散涟漪（任何点击都有即时响应感）。
func spawn_tap(pos: Vector2) -> void:
	_taps.append({"pos": pos, "age": 0.0})


## 生成一条飘字提示（其他层也调用它，如「已读档」「进度已重置」）。
func spawn_floater(text: String, color: Color) -> void:
	print(text)
	_floaters.append({"text": text, "pos": Vector2(GameLayout.W * 0.5, GameLayout.H * 0.45), "age": 0.0, "color": color})


## 日结面板是否显示中（输入层据此把点击/按键当"继续"）。
func is_summary_active() -> bool:
	return not _summary.is_empty()


## 水平居中画一行文本（宽卡片内居中，避免长行溢出）。
func _center_text(y: float, text: String, size: int, color: Color) -> void:
	var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	UITheme.label(self, font, Vector2(GameLayout.W * 0.5 - tw / 2.0, y), text, size, color)


## 关闭日结面板（点击/按键继续）。
func dismiss_summary() -> void:
	_summary = {}


## 日结面板卡片（居中弹窗，停留至点击/按键继续）。
func _draw_summary_panel() -> void:
	if _summary.is_empty():
		return
	var cx := GameLayout.W * 0.5
	var cy := GameLayout.H * 0.42
	var w := 440.0
	var h := 190.0
	var alpha: float = clampf(_summary["age"] * 4.0, 0.0, 1.0)
	UITheme.panel(self, Rect2(cx - w / 2 - 6, cy - h / 2 - 6, w + 12, h + 12), Color(0, 0, 0, 0.35 * alpha), 18)
	UITheme.panel(self, Rect2(cx - w / 2, cy - h / 2, w, h), Color(0.98, 0.94, 0.86, 0.97 * alpha), 16, Color(0.35, 0.25, 0.16, 0.5), 2)
	var earned: int = _summary["earned"]
	_center_text(cy - h / 2 + 36, tr("第 %d 天 · 营业结算") % _summary["day"], 22, UITheme.INK)
	_center_text(cy - 18, tr("营收 ¥%d") % earned, 26, UITheme.GREEN if earned >= 0 else UITheme.RED)
	_center_text(cy + 22, tr("服务 %d 单 · 糊锅 %d 次 · 气走/流失 %d 位") % [_summary["served"], _summary["burnt"], _summary["angry"]], 16, UITheme.INK_SOFT)
	_center_text(cy + 52, tr("食材浪费 %d 份 · 口碑 %d") % [_summary["spoiled"], GameState.shop["reputation"]], 16, UITheme.INK_SOFT)
	_center_text(cy + 82, tr("点击 / 按任意键继续"), 14, Color(0.55, 0.48, 0.40))


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


## 日结面板：把当天成果摆到脸上（营收/服务/糊锅/气走/浪费）。
func _on_day_summary(p) -> void:
	_summary = {"day": p["day"], "earned": p["earned"], "age": 0.0,
		"served": _day_stats["served"], "burnt": _day_stats["burnt"],
		"angry": _day_stats["angry"], "spoiled": _day_stats["spoiled"]}
	_day_stats = {"served": 0, "burnt": 0, "angry": 0, "spoiled": 0}
	_warned_closing = false


func _on_season_changed(season) -> void:
	spawn_floater(tr("进入%s天") % tr(Catalog.get_season_name(season)), Color(0.7, 0.8, 1.0))


## 打烊预警：最后 10 分钟提示一次（防"直接跨日"惊吓）。
func _on_tick(minute) -> void:
	if not _warned_closing and int(minute) >= GameClock.minutes_per_day - 10:
		_warned_closing = true
		spawn_floater(tr("快打烊了！还有 10 分钟"), Color(1.0, 0.8, 0.4))


func _on_kitchen_blocked(p) -> void:
	var text: String = tr("工位被占满了！") if str(p.get("reason", "")) == "occupied" else tr("设备故障中…")
	spawn_floater(text, Color(0.7, 0.5, 0.4))


# ---------- 动画与绘制 ----------

func _animate(delta: float) -> void:
	for f in _floaters:
		f["age"] += delta
		f["pos"].y -= 45.0 * delta
	_floaters = _floaters.filter(func(f): return f["age"] < FLOATER_LIFETIME)
	for t in _taps:
		t["age"] += delta
	_taps = _taps.filter(func(t): return t["age"] < 0.35)
	if not _summary.is_empty():
		_summary["age"] += delta


func _draw() -> void:
	_draw_summary_panel()
	# 点击涟漪（扩散圆环）
	for t in _taps:
		var k: float = t["age"] / 0.35
		var r: float = 10.0 + 26.0 * k
		draw_arc(t["pos"], r, 0, TAU, 24, Color(1, 1, 1, 0.55 * (1.0 - k)), 2.5)
	for f in _floaters:
		var alpha := clampf(1.0 - f["age"] / FLOATER_LIFETIME, 0.0, 1.0)
		var c: Color = f["color"]
		c.a = alpha
		# 出现瞬间弹一下（scale 1.25 -> 1.0）；奶油底板保证任何背景上可读
		var pop := 1.0 + 0.25 * maxf(0.0, 1.0 - f["age"] / 0.18)
		var tw: float = font.get_string_size(f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 26.0
		draw_set_transform(f["pos"], 0.0, Vector2(pop, pop))
		UITheme.panel(self, Rect2(Vector2(-tw / 2.0, -22.0), Vector2(tw, 34.0)), Color(0.98, 0.94, 0.86, 0.92 * alpha), 9, Color(0.3, 0.22, 0.14, 0.5), 1)
		UITheme.label(self, font, Vector2.ZERO, f["text"], 24, c, HORIZONTAL_ALIGNMENT_CENTER)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
