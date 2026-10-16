extends Node2D
## 主场景：2D 可视化渲染 + 鼠标交互。
## 游戏逻辑全部在系统里（只改 GameState），本层只负责「画出来」和「处理点击」。


var _shop_system: ShopSystem
var _weather_system: WeatherSystem
var _hygiene_system: HygieneSystem
var _customer_system: CustomerSystem
var _kitchen_system: KitchenSystem
var _event_system: EventSystem
var _save_system: SaveSystem
var _season_system: SeasonSystem
var _language_system: LanguageSystem

var _font: Font
var _autoplay: bool = false

var _t: float = 0.0
var _floaters: Array = []       # {text, pos, age, color}
var _rain: Array = []           # {x, y, speed}
var _entered_at: Dictionary = {}  # customer_id -> 入场时间

const W := 1280.0
const H := 720.0
const HUD_H := 64.0

var _open_rect := Rect2(40, H - 68, 150, 48)
var _mop_rect := Rect2(210, H - 68, 150, 48)
var _close_rect := Rect2(380, H - 68, 150, 48)
var _upgrade_mop_rect := Rect2(40, H - 132, 230, 44)
var _upgrade_ingredient_rect := Rect2(290, H - 132, 230, 44)
var _upgrade_decor_rect := Rect2(540, H - 132, 230, 44)
var _buy_ingredients_rect := Rect2(40, H - 196, 230, 44)
var _reset_rect := Rect2(W - 110, H - 68, 100, 48)
var _lang_rect := Rect2(W - 220, H - 68, 100, 48)
var _style_rect := Rect2(W - 330, H - 68, 100, 48)
var _use_sprites: bool = true
var _food_textures: Dictionary = {}
var _customer_textures: Dictionary = {}
var _bg_texture: Texture2D
var _tutorial_step: int = -1
var _tutorial_rect := Rect2(W * 0.15, H * 0.28, W * 0.7, H * 0.4)
var _tutorial_next_rect := Rect2(W * 0.58, H * 0.62, 150, 46)
var _tutorial_skip_rect := Rect2(W * 0.30, H * 0.62, 150, 46)

const TUTORIAL: Array = [
	"欢迎开店！点下方「开门营业」开始营业",
	"客人进店点单，点客人「接单」",
	"点厨房里的菜上工位，步骤自动计时；灶台做好趁热取走，晚了糊锅",
	"做完变发光盘子，点它「上菜」收钱",
	"地面变脏点「拖地」（要花 3 秒，期间做不了菜），脏店客人没耐心",
	"每天结束自动存档，开店前点绿色按钮升级设备",
]

const DISH_COLORS := {
	"milk_tea": Color(0.75, 0.55, 0.35),
	"coffee": Color(0.45, 0.30, 0.20),
	"sandwich": Color(0.92, 0.72, 0.30),
	"juice": Color(1.00, 0.60, 0.20),
	"burger": Color(0.60, 0.38, 0.18),
	"cake": Color(0.95, 0.62, 0.75),
	"salad": Color(0.50, 0.80, 0.40),
	"soup": Color(0.90, 0.60, 0.30),
	"ice_cream": Color(0.95, 0.85, 0.90),
	"pizza": Color(0.85, 0.50, 0.30),
}
const CUSTOMER_COLORS := [
	Color(0.45, 0.70, 0.90),
	Color(0.95, 0.65, 0.75),
	Color(0.60, 0.80, 0.55),
	Color(0.90, 0.75, 0.50),
	Color(0.70, 0.60, 0.90),
]
## 地面污渍的固定位置（越脏出现越多，最多 8 处）
const DIRT_SPOTS := [
	Vector2(430, 610), Vector2(700, 540), Vector2(150, 560), Vector2(600, 260),
	Vector2(840, 420), Vector2(120, 380), Vector2(520, 430), Vector2(760, 640),
]


func _ready() -> void:
	_setup_font()
	_load_sprites()
	_shop_system = ShopSystem.new()
	_weather_system = WeatherSystem.new()
	_hygiene_system = HygieneSystem.new()
	_customer_system = CustomerSystem.new()
	_kitchen_system = KitchenSystem.new()
	_event_system = EventSystem.new()
	_save_system = SaveSystem.new()
	_season_system = SeasonSystem.new()
	_language_system = LanguageSystem.new()
	SystemManager.register(_shop_system)
	SystemManager.register(_weather_system)
	SystemManager.register(_hygiene_system)
	SystemManager.register(_customer_system)
	SystemManager.register(_kitchen_system)
	SystemManager.register(_event_system)
	SystemManager.register(_save_system)
	SystemManager.register(_season_system)
	SystemManager.register(_language_system)
	_subscribe_events()

	_autoplay = "--autoplay" in OS.get_cmdline_user_args()
	if _autoplay:
		GameClock.seconds_per_minute = 0.1

	# 读档（autoplay 测试模式跳过，保证从第 1 天开始）
	var loaded_day: int = 0 if _autoplay else _save_system.load()
	EventBus.emit("clock.day_started", GameClock.day)
	if loaded_day > 0:
		_spawn_floater(tr("已读档，继续第 %d 天") % loaded_day, Color(0.6, 0.8, 1.0))
	elif not _autoplay:
		_tutorial_step = 0


func _setup_font() -> void:
	_font = load("res://assets/fonts/NotoSansSC-Static.ttf")


func _load_sprites() -> void:
	for id in ["milk_tea", "coffee", "juice", "sandwich", "burger", "cake", "salad", "soup", "ice_cream", "pizza"]:
		_food_textures[id] = load("res://assets/sprites/food_%s.png" % id)
	_bg_texture = load("res://assets/sprites/shop_bg.png")
	for key in ["laozhang", "xiaowang", "lijie", "critic", "g0", "g1", "g2", "g3", "g4", "g5"]:
		_customer_textures[key] = load("res://assets/sprites/customer_%s.png" % key)


func _customer_texture(c: Dictionary) -> Texture2D:
	if c.get("is_critic", false):
		return _customer_textures.get("critic") as Texture2D
	if c["regular_id"] != "" and _customer_textures.has(c["regular_id"]):
		return _customer_textures[c["regular_id"]] as Texture2D
	return _customer_textures.get("g%d" % (int(c["id"]) % 6)) as Texture2D


func _draw_food(pos: Vector2, radius: float, dish_id: String, dish_color: Color) -> void:
	if _use_sprites and _food_textures.has(dish_id):
		var tex: Texture2D = _food_textures[dish_id]
		var size := radius * 2.2
		draw_texture_rect(tex, Rect2(pos.x - radius * 1.1, pos.y - radius * 1.1, size, size), false)
	else:
		draw_circle(pos, radius, dish_color)


func _subscribe_events() -> void:
	EventBus.subscribe("customer.entered", _on_customer_entered)
	EventBus.subscribe("customer.served", func(p): _spawn_floater("+¥%d" % p["earned"], Color(0.2, 0.8, 0.3)))
	EventBus.subscribe("customer.left_angry", func(_p): _spawn_floater(tr("差评 -1"), Color(0.9, 0.3, 0.3)))
	EventBus.subscribe("weather.changed", _on_weather_changed)
	EventBus.subscribe("regular.lost", func(p): _spawn_floater(tr("%s不来了…") % tr(p["name"]), Color(0.85, 0.4, 0.6)))
	EventBus.subscribe("day.summary", _on_day_summary)
	EventBus.subscribe("event.food_critic", func(_p): _spawn_floater(tr("美食评论家来了！"), Color(0.75, 0.45, 0.95)))
	EventBus.subscribe("kitchen.burnt", func(_p): _spawn_floater(tr("糊了！食材报废，客人气走了"), Color(0.9, 0.3, 0.25)))
	EventBus.subscribe("dish.ready", func(_p): _spawn_floater(tr("✓ 可以上菜了"), Color(0.3, 0.85, 0.4)))
	EventBus.subscribe("kitchen.blocked", func(p): _spawn_floater(tr("工位被占满了！") if str(p.get("reason", "")) == "occupied" else tr("设备故障中…"), Color(0.7, 0.5, 0.4)))
	EventBus.subscribe("event.rush_hour", func(_p): _spawn_floater(tr("客流高峰！"), Color(0.95, 0.55, 0.2)))
	EventBus.subscribe("event.inspect_fail", func(p): _spawn_floater(tr("卫生检查不合格！罚款¥%d") % p["fine"], Color(0.9, 0.3, 0.3)))
	EventBus.subscribe("event.inspect_pass", func(_p): _spawn_floater(tr("卫生检查合格 ✓"), Color(0.3, 0.8, 0.4)))
	EventBus.subscribe("event.equipment_failure", func(_p): _spawn_floater(tr("设备故障！暂时不能做菜"), Color(0.6, 0.5, 0.5)))
	EventBus.subscribe("event.holiday", func(_p): _spawn_floater(tr("节日促销！今日菜品加价30%"), Color(1.0, 0.75, 0.3)))
	EventBus.subscribe("regular.celebrate", func(p): _spawn_floater(tr("%s今天生日，特别开心！") % tr(p["name"]), Color(1.0, 0.6, 0.8)))
	EventBus.subscribe("regular.gift", func(p): _spawn_floater(tr("%s送你一份礼物(+¥50)！") % tr(p["name"]), Color(1.0, 0.8, 0.4)))
	EventBus.subscribe("regular.brings_friend", func(p): _spawn_floater(tr("%s介绍了个朋友来！") % tr(p["name"]), Color(0.6, 0.9, 0.6)))
	EventBus.subscribe("upgrade.bought", func(p): _spawn_floater(tr("%s升级到 Lv%d！") % [tr(p["name"]), p["level"]], Color(0.4, 0.8, 0.9)))
	EventBus.subscribe("ingredients.empty", func(_p): _spawn_floater(tr("食材不足！开店前采购"), Color(0.9, 0.4, 0.2)))
	EventBus.subscribe("season.changed", func(season): _spawn_floater(tr("进入%s天") % tr(Catalog.get_season_name(season)), Color(0.7, 0.8, 1.0)))


func _on_weather_changed(weather_id: String) -> void:
	if weather_id == "rain" or weather_id == "storm" or weather_id == "typhoon":
		_spawn_rain()
	else:
		_rain.clear()
	if weather_id == "typhoon":
		_spawn_floater(tr("台风来袭！建议歇业"), Color(0.9, 0.4, 0.4))
	elif weather_id == "storm":
		_spawn_floater(tr("暴雨来袭"), Color(0.5, 0.6, 0.9))


func _on_customer_entered(p) -> void:
	if p["name"] != "客人" and p["name"] != "美食评论家":
		if p.get("celebrating", false):
			_spawn_floater(tr("%s今天生日！") % tr(p["name"]), Color(1.0, 0.6, 0.8))
		else:
			_spawn_floater(tr("%s来了！") % tr(p["name"]), Color(1.0, 0.85, 0.4))


func _on_day_summary(summary: Dictionary) -> void:
	_spawn_floater(tr("第%d天营收¥%d") % [summary["day"], summary["earned"]], Color(0.95, 0.85, 0.25))


# ---------- 动画状态 ----------

func _spawn_floater(text: String, color: Color) -> void:
	print(text)
	_floaters.append({"text": text, "pos": Vector2(W * 0.5, H * 0.45), "age": 0.0, "color": color})


func _spawn_rain() -> void:
	_rain.clear()
	for i in range(90):
		_rain.append({"x": randf() * W, "y": randf() * H, "speed": 320.0 + randf() * 240.0})


func _process(delta: float) -> void:
	_t += delta

	for f in _floaters:
		f["age"] += delta
		f["pos"].y -= 45.0 * delta
	_floaters = _floaters.filter(func(f): return f["age"] < 1.2)

	for d in _rain:
		d["y"] += d["speed"] * delta
		if d["y"] > H:
			d["y"] = -10.0
			d["x"] = randf() * W

	for c in GameState.customers:
		if not _entered_at.has(c["id"]):
			_entered_at[c["id"]] = _t
	var alive := {}
	for c in GameState.customers:
		alive[c["id"]] = true
	for id in _entered_at.keys():
		if not alive.has(id):
			_entered_at.erase(id)

	if _autoplay:
		_autoplay_tick()
	queue_redraw()


# ---------- 绘制 ----------

func _draw() -> void:
	_draw_floor()
	_draw_dirt()
	_draw_sun()
	_draw_hud()
	_draw_customers()
	_draw_kitchen()
	_draw_buttons()
	_draw_upgrades()
	_draw_rain()
	_draw_floaters()
	_draw_tutorial()


func _draw_floor() -> void:
	if _use_sprites and _bg_texture != null:
		draw_texture_rect(_bg_texture, Rect2(0, 0, W, H), false)
	else:
		draw_rect(Rect2(0, HUD_H, W, H - HUD_H), Color(0.96, 0.94, 0.88))
		draw_rect(Rect2(W * 0.72, HUD_H, W * 0.28, H - HUD_H), Color(0.83, 0.76, 0.67))
		draw_line(Vector2(W * 0.72, HUD_H), Vector2(W * 0.72, H), Color(0.55, 0.45, 0.35), 4.0)
	# 底部操作提示
	draw_string(_font, Vector2(560, H - 14), tr("点客人接单 → 点锅做菜 → 点盘子上菜 · 点按钮拖地/开门/打烊"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.4, 0.35, 0.3))


func _draw_sun() -> void:
	if GameState.weather_id != "sunny":
		return
	var c := Vector2(W - 90, 110)
	draw_circle(c, 36, Color(1.0, 0.85, 0.3))
	for i in range(8):
		var a := i * TAU / 8.0
		draw_line(c + Vector2(cos(a), sin(a)) * 46, c + Vector2(cos(a), sin(a)) * 58, Color(1.0, 0.8, 0.25), 3.0)


func _draw_hud() -> void:
	draw_rect(Rect2(0, 0, W, HUD_H), Color(0.17, 0.17, 0.23))
	var forecast := ""
	if GameState.forecast_weather_id != "":
		forecast = tr(" 明日:%s") % tr(Catalog.get_weather()[GameState.forecast_weather_id].display_name)
	var line := tr("第%d天  8:%02d  %s·天气:%s%s  ¥%d  食材:%d  %s") % [
		GameClock.day, GameClock.game_minute, tr(Catalog.get_season_name(GameState.current_season)),
		_weather_text(), forecast,
		GameState.shop["money"], GameState.shop["ingredients"], _state_text(GameState.shop["day_state"]),
	]
	draw_string(_font, Vector2(16, 36), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	_draw_bar(Vector2(16, 58), 170, GameState.shop["hygiene"], tr("卫生"))
	_draw_bar(Vector2(280, 58), 170, GameState.shop["environment"], tr("环境"))
	draw_string(_font, Vector2(560, 36), tr("熟客:%s") % _regular_status(), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.7, 0.8))


func _draw_bar(pos: Vector2, width: float, value: float, label: String) -> void:
	draw_string(_font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	var bar_rect := Rect2(pos + Vector2(40, -13), Vector2(width, 12))
	draw_rect(bar_rect, Color(0.3, 0.3, 0.35))
	draw_rect(Rect2(bar_rect.position, Vector2(width * clampf(value / 100.0, 0.0, 1.0), 12)), _value_color(value))


func _draw_customers() -> void:
	for i in range(GameState.customers.size()):
		_draw_customer(GameState.customers[i], _customer_pos(i), i)


func _customer_pos(i: int) -> Vector2:
	return Vector2(250, 140 + i * 82)


func _draw_customer(c: Dictionary, pos: Vector2, idx: int) -> void:
	var radius := 32.0
	var mood := clampf(c["patience"] / c["patience_max"], 0.0, 1.0)
	var body: Color = CUSTOMER_COLORS[idx % CUSTOMER_COLORS.size()]
	if c["regular_id"] != "":
		body = Color(0.95, 0.55, 0.3)
	if c.get("is_critic", false):
		body = Color(0.55, 0.30, 0.70)

	# 入场缩放
	var scale := 1.0
	if _entered_at.has(c["id"]):
		scale = clampf((_t - _entered_at[c["id"]]) / 0.25, 0.3, 1.0)
	var r := radius * scale

	# 影子 + 身体
	var tex: Texture2D = _customer_texture(c)
	var sprite_mode := _use_sprites and tex != null
	if sprite_mode:
		var s := r * 1.5
		draw_circle(pos + Vector2(0, radius * 0.66), radius * 0.62, Color(0, 0, 0, 0.12))
		draw_texture_rect(tex, Rect2(pos.x - s / 2, pos.y - s / 2, s, s), false)
		# 心情角标
		var badge := pos + Vector2(radius * 0.8, -radius * 0.9)
		if mood > 0.5:
			draw_arc(badge, 8.0 * scale, PI + 0.2, TAU - 0.2, 8, Color(0.2, 0.75, 0.35), 2.0)
		else:
			draw_arc(badge, 8.0 * scale, 0.2, PI - 0.2, 8, Color(0.85, 0.25, 0.2), 2.0)
	else:
		draw_circle(pos + Vector2(0, radius - 4), radius, Color(0, 0, 0, 0.12))
		draw_circle(pos, r, body)
		draw_arc(pos, r, 0, TAU, 32, Color(0, 0, 0, 0.25), 2.0)

		# 眼睛
		draw_circle(pos + Vector2(-11 * scale, -8 * scale), 3.5 * scale, Color(0.1, 0.1, 0.1))
		draw_circle(pos + Vector2(11 * scale, -8 * scale), 3.5 * scale, Color(0.1, 0.1, 0.1))

		# 嘴（心情）
		if mood > 0.5:
			draw_arc(pos + Vector2(0, 4), 10 * scale, PI + 0.15, TAU - 0.15, 12, Color(0.1, 0.1, 0.1), 2.0)
		else:
			draw_arc(pos + Vector2(0, 12), 10 * scale, 0.15, PI - 0.15, 12, Color(0.1, 0.1, 0.1), 2.0)

	# 生日帽
	if c.get("celebrating", false):
		draw_colored_polygon(PackedVector2Array([
			pos + Vector2(0, -radius - 8),
			pos + Vector2(-14, -radius + 6),
			pos + Vector2(14, -radius + 6),
		]), Color(0.9, 0.3, 0.55))
		draw_circle(pos + Vector2(0, -radius - 10), 4, Color(1.0, 0.9, 0.3))

	# 名牌（熟客 / 评论家）
	if c["regular_id"] != "" or c.get("is_critic", false):
		var name_color := Color(1.0, 0.9, 0.5) if c["regular_id"] != "" else Color(0.85, 0.7, 1.0)
		var name_dy: float = -26.0 if sprite_mode else -66.0
		draw_string(_font, pos + Vector2(-radius, name_dy), tr(c["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, name_color)

	# 头顶耐心条
	var bar_w := radius * 2.0
	var bar_dy: float = -56.0 if sprite_mode else -54.0
	var bar_pos := pos + Vector2(-radius, bar_dy)
	draw_rect(Rect2(bar_pos, Vector2(bar_w, 8)), Color(0, 0, 0, 0.4))
	draw_rect(Rect2(bar_pos, Vector2(bar_w * mood, 8)), _patience_color(mood))

	# 点单气泡
	_draw_bubble(pos + Vector2(radius + 16, -radius), c)


func _draw_bubble(pos: Vector2, c: Dictionary) -> void:
	var recipe := Catalog.get_recipe_by_id(c["recipe_id"])
	var dish_color: Color = DISH_COLORS.get(c["recipe_id"], Color.WHITE)
	var progress := ""
	if c["state"] == "waiting":
		progress = tr("（点我接单）")
	elif c["state"] == "being_served":
		match c["cook"]["phase"]:
			"queued":
				progress = tr("（点我上工位）")
			"cooking":
				progress = tr(" 制作中…")
			"done":
				progress = tr("（点我取走）")
	elif c["state"] == "ready":
		progress = tr("（点我上菜）")
	var text: String = tr(c["recipe_name"]) + progress

	var bw := 128.0
	var bh := 34.0
	draw_rect(Rect2(pos, Vector2(bw, bh)), Color(1, 1, 1, 0.93))
	draw_rect(Rect2(pos, Vector2(bw, bh)), Color(0.6, 0.55, 0.5), false, 1.5)
	_draw_food(pos + Vector2(13, bh / 2), 7, c["recipe_id"], dish_color)
	draw_string(_font, pos + Vector2(28, bh - 11), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.1, 0.1, 0.1))


func _draw_kitchen() -> void:
	draw_string(_font, Vector2(W * 0.72 + 40, 110), tr("厨房"), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.45, 0.35, 0.25))
	draw_string(_font, Vector2(W * 0.72 + 40, 134), tr("点菜推进一步 · 灶台做好趁热取走，晚了会糊锅"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.55, 0.5, 0.45))
	for i in range(_kitchen_system.stations.size()):
		_draw_station(_kitchen_system.stations[i], _station_pos(i))
	# 待处理的菜：等工位的 / 做完待上菜的（在工位上的菜由工位卡片绘制）
	var slot := 0
	for c in GameState.customers:
		if c["state"] != "being_served" and c["state"] != "ready":
			continue
		if c["cook"]["station_id"] >= 0:
			continue
		_draw_waiting_dish(c, _waiting_pos(slot))
		slot += 1


func _station_pos(i: int) -> Vector2:
	return Vector2(1015 + (i % 2) * 170, 265 + (i / 2) * 180)


func _waiting_pos(i: int) -> Vector2:
	return Vector2(985 + i * 72, 615)


func _customer_by_id(cid: int) -> Dictionary:
	for c in GameState.customers:
		if c["id"] == cid:
			return c
	return {}


func _draw_station(s: Dictionary, pos: Vector2) -> void:
	var rect := Rect2(pos + Vector2(-78, -62), Vector2(156, 128))
	draw_rect(rect, Color(0.16, 0.15, 0.2, 0.88))
	draw_rect(rect, Color(0.55, 0.5, 0.42, 0.9), false, 2.0)
	draw_string(_font, rect.position + Vector2(12, 24), tr(s["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.95, 0.85))
	match s["phase"]:
		"":
			draw_string(_font, rect.position + Vector2(12, 72), tr("空闲"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.58, 0.58, 0.64))
		"blocked":
			draw_string(_font, rect.position + Vector2(12, 56), tr("清理中…"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.5, 0.3))
			_draw_bar_bg(rect.position + Vector2(12, 72), 132, 10)
			_draw_bar_fill(rect.position + Vector2(12, 72), 132, 10, 1.0 - s["timer"] / 3.0, Color(0.9, 0.5, 0.3))
		"cooking", "done":
			var c := _customer_by_id(s["customer_id"])
			if c.is_empty():
				return
			var dish_color: Color = DISH_COLORS.get(c["recipe_id"], Color.WHITE)
			var recipe := Catalog.get_recipe_by_id(c["recipe_id"])
			var step: Dictionary = recipe.steps[c["make_progress"]]
			_draw_food(rect.position + Vector2(36, 76), 21, c["recipe_id"], dish_color)
			draw_string(_font, rect.position + Vector2(70, 52), tr(step["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.9, 0.8))
			if s["phase"] == "cooking":
				_draw_bar_bg(rect.position + Vector2(70, 62), 76, 9)
				var prog: float = 1.0 - s["timer"] / maxf(step["sec"], 0.01)
				_draw_bar_fill(rect.position + Vector2(70, 62), 76, 9, prog, Color(0.35, 0.75, 0.95))
				draw_string(_font, rect.position + Vector2(70, 92), tr("制作中…"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 0.75, 0.85))
			else:
				var pulse := 0.6 + 0.4 * absf(sin(_t * 5.0))
				draw_string(_font, rect.position + Vector2(70, 78), tr("✓ 点我取走"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.3, 0.9, 0.4, pulse))
				if s["burn_timer"] > 0.0:
					_draw_bar_bg(rect.position + Vector2(70, 88), 76, 8)
					_draw_bar_fill(rect.position + Vector2(70, 88), 76, 8, s["burn_timer"] / KitchenSystem.BURN_GRACE, Color(0.9, 0.25, 0.2))
					draw_string(_font, rect.position + Vector2(12, 108), tr("快糊了！"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.35, 0.25, pulse))


func _draw_waiting_dish(c: Dictionary, pos: Vector2) -> void:
	var dish_color: Color = DISH_COLORS.get(c["recipe_id"], Color.WHITE)
	if c["state"] == "ready":
		var pulse := 1.0 + 0.1 * sin(_t * 6.0)
		draw_arc(pos, 31 * pulse, 0, TAU, 24, Color(0.3, 0.9, 0.4, 0.6), 3.0)
		draw_circle(pos, 25, Color(0.96, 0.96, 0.96, 0.95))
		_draw_food(pos, 17, c["recipe_id"], dish_color)
		draw_string(_font, pos + Vector2(-26, 46), tr("✓ 上菜"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.2, 0.75, 0.35))
	else:
		draw_circle(pos, 25, Color(0.22, 0.22, 0.28, 0.92))
		_draw_food(pos, 17, c["recipe_id"], dish_color)
		draw_string(_font, pos + Vector2(-26, 46), tr("上工位"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.8, 0.7))


func _draw_bar_bg(pos: Vector2, w: float, h: float) -> void:
	draw_rect(Rect2(pos, Vector2(w, h)), Color(0, 0, 0, 0.45))


func _draw_bar_fill(pos: Vector2, w: float, h: float, ratio: float, color: Color) -> void:
	draw_rect(Rect2(pos, Vector2(w * clampf(ratio, 0.0, 1.0), h)), color)


func _draw_dirt() -> void:
	var n: int = _hygiene_system.dirt_spots()
	for i in range(n):
		var p: Vector2 = DIRT_SPOTS[i]
		draw_circle(p, 17.0, Color(0.42, 0.3, 0.16, 0.32))
		draw_circle(p + Vector2(11, 7), 9.0, Color(0.42, 0.3, 0.16, 0.28))
		draw_circle(p + Vector2(-9, 9), 7.0, Color(0.38, 0.26, 0.13, 0.28))


func _draw_buttons() -> void:
	_draw_button(_open_rect, tr("开门营业"), GameState.shop["day_state"] == "preparing")
	var mop_label: String = tr("拖地") + " (+%d)" % int(30 + GameState.shop["upgrades"]["mop"] * 10)
	if _hygiene_system.is_mopping():
		mop_label = tr("拖地中…")
	_draw_button(_mop_rect, mop_label, GameState.shop["day_state"] == "serving")
	if _hygiene_system.is_mopping():
		draw_rect(Rect2(_mop_rect.position + Vector2(6, _mop_rect.size.y - 10), Vector2((_mop_rect.size.x - 12) * _hygiene_system.mop_progress(), 5)), Color(0.4, 0.8, 1.0, 0.9))
	_draw_button(_close_rect, tr("提前打烊"), GameState.shop["day_state"] == "serving")
	_draw_button(_reset_rect, tr("重置进度"), true)
	_draw_button(_lang_rect, "EN" if not _language_system.is_en() else "中文", true)
	_draw_button(_style_rect, "像素" if _use_sprites else "代码", true)


func _draw_upgrades() -> void:
	if GameState.shop["day_state"] == "closed":
		return
	_draw_buy_ingredients_button()
	if GameState.shop["day_state"] == "preparing":
		_draw_upgrade_button(_upgrade_mop_rect, "mop")
		_draw_upgrade_button(_upgrade_ingredient_rect, "ingredient")
		_draw_upgrade_button(_upgrade_decor_rect, "decor")


func _draw_buy_ingredients_button() -> void:
	var enabled: bool = GameState.shop["money"] >= 15
	var c := Color(0.6, 0.45, 0.2) if enabled else Color(0.42, 0.42, 0.45)
	draw_rect(_buy_ingredients_rect, c)
	draw_rect(_buy_ingredients_rect, Color(0, 0, 0, 0.3), false, 2.0)
	var label := tr("采购食材 +5 (¥15) [现有%d]") % GameState.shop["ingredients"]
	draw_string(_font, _buy_ingredients_rect.position + Vector2(10, _buy_ingredients_rect.size.y - 14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


func _draw_upgrade_button(rect: Rect2, category: String) -> void:
	var info: Dictionary = Catalog.get_upgrades()[category]
	var level: int = GameState.shop["upgrades"][category]
	var enabled: bool = level < 3 and GameState.shop["money"] >= info["costs"][level]
	var c := Color(0.33, 0.5, 0.36) if enabled else Color(0.42, 0.42, 0.45)
	draw_rect(rect, c)
	draw_rect(rect, Color(0, 0, 0, 0.3), false, 2.0)
	var label: String
	if level >= 3:
		label = tr("%s MAX") % tr(info["name"])
	else:
		label = tr("%s Lv%d→%d ¥%d") % [tr(info["name"]), level, level + 1, info["costs"][level]]
	draw_string(_font, rect.position + Vector2(10, rect.size.y - 14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


func _draw_button(rect: Rect2, text: String, enabled: bool) -> void:
	var c := Color(0.33, 0.55, 0.85) if enabled else Color(0.42, 0.42, 0.45)
	draw_rect(rect, c)
	draw_rect(rect, Color(0, 0, 0, 0.3), false, 2.0)
	draw_string(_font, rect.position + Vector2(12, rect.size.y - 14), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE if enabled else Color(0.72, 0.72, 0.75))


func _draw_floaters() -> void:
	for f in _floaters:
		var alpha := clampf(1.0 - f["age"] / 1.2, 0.0, 1.0)
		var c: Color = f["color"]
		c.a = alpha
		draw_string(_font, f["pos"], f["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, 24, c)


func _draw_rain() -> void:
	for d in _rain:
		draw_line(Vector2(d["x"], d["y"]), Vector2(d["x"] - 2, d["y"] + 12), Color(0.4, 0.6, 0.9, 0.5), 1.5)


# ---------- 输入 ----------

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(event.position)


func _draw_tutorial() -> void:
	if _tutorial_step < 0:
		return
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.6))
	draw_rect(_tutorial_rect, Color(0.16, 0.16, 0.22))
	draw_rect(_tutorial_rect, Color(0.8, 0.8, 0.9), false, 2.0)
	draw_string(_font, _tutorial_rect.position + Vector2(30, 42), tr("新手引导 (%d/%d)") % [_tutorial_step + 1, TUTORIAL.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.9, 0.4))
	draw_string(_font, _tutorial_rect.position + Vector2(30, 96), tr(TUTORIAL[_tutorial_step]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	_draw_button(_tutorial_next_rect, tr("下一步"), true)
	_draw_button(_tutorial_skip_rect, tr("跳过"), true)


func _handle_click(pos: Vector2) -> void:
	if _tutorial_step >= 0:
		if _tutorial_next_rect.has_point(pos):
			_tutorial_step += 1
			if _tutorial_step >= TUTORIAL.size():
				_tutorial_step = -1
		elif _tutorial_skip_rect.has_point(pos):
			_tutorial_step = -1
		return
	if _reset_rect.has_point(pos):
		_on_reset()
		return
	if _lang_rect.has_point(pos):
		_language_system.toggle()
		return
	if _style_rect.has_point(pos):
		_use_sprites = not _use_sprites
		return
	if GameState.shop["day_state"] != "closed" and _buy_ingredients_rect.has_point(pos):
		_shop_system.buy_ingredients()
		return
	if GameState.shop["day_state"] == "preparing":
		if _upgrade_mop_rect.has_point(pos):
			_shop_system.buy_upgrade("mop")
			return
		if _upgrade_ingredient_rect.has_point(pos):
			_shop_system.buy_upgrade("ingredient")
			return
		if _upgrade_decor_rect.has_point(pos):
			_shop_system.buy_upgrade("decor")
			return
	if _open_rect.has_point(pos) and GameState.shop["day_state"] == "preparing":
		_shop_system.open_shop()
		return
	if _mop_rect.has_point(pos) and GameState.shop["day_state"] == "serving":
		_hygiene_system.start_mop()
		return
	if _close_rect.has_point(pos) and GameState.shop["day_state"] == "serving":
		GameClock.end_day_now()
		return

	# 拖地占用双手：动作没做完不能做菜/接单（「锅要糊 vs 地上一摊」的取舍）
	if _hygiene_system.is_mopping():
		_spawn_floater(tr("正在拖地…"), Color(0.55, 0.7, 0.9))
		return

	# 厨房工位：点卡片 = 派菜上工位 / 取走成品
	for i in range(_kitchen_system.stations.size() - 1, -1, -1):
		var s: Dictionary = _kitchen_system.stations[i]
		var sp := _station_pos(i)
		if Rect2(sp.x - 78, sp.y - 62, 156, 128).has_point(pos):
			if s["customer_id"] >= 0:
				_kitchen_system.tap_dish(s["customer_id"])
			else:
				_kitchen_system.tap_station(s["id"])
			return

	# 待处理的菜：等工位的 / 做完待上菜的
	var slot := 0
	for c in GameState.customers:
		if c["state"] != "being_served" and c["state"] != "ready":
			continue
		if c["cook"]["station_id"] >= 0:
			continue
		var wp := _waiting_pos(slot)
		slot += 1
		if Rect2(wp.x - 30, wp.y - 30, 60, 80).has_point(pos):
			if c["state"] == "ready":
				_customer_system.serve(c["id"])
			else:
				_kitchen_system.tap_dish(c["id"])
			return

	# 客人：点击接单
	for i in range(GameState.customers.size() - 1, -1, -1):
		var c = GameState.customers[i]
		var p := _customer_pos(i)
		if Rect2(p.x - 45, p.y - 70, 250, 110).has_point(pos):
			if c["state"] == "waiting":
				_customer_system.take_order(c["id"])
			return


func _on_reset() -> void:
	_save_system.reset()
	EventBus.emit("clock.day_started", GameClock.day)
	_spawn_floater(tr("进度已重置"), Color(0.8, 0.5, 0.5))


# ---------- 自动演示 ----------

func _autoplay_tick() -> void:
	match GameState.shop["day_state"]:
		"preparing":
			for i in range(10):
				_shop_system.buy_ingredients()
			_shop_system.open_shop()
		"serving":
			if GameState.shop["hygiene"] < 40.0:
				_hygiene_system.start_mop()
			for c in GameState.customers.duplicate():
				match c["state"]:
					"waiting":
						_customer_system.take_order(c["id"])
					"being_served":
						_kitchen_system.tap_dish(c["id"])
					"ready":
						_customer_system.serve(c["id"])


# ---------- 文本辅助 ----------

func _state_text(s: String) -> String:
	match s:
		"preparing":
			return tr("准备中")
		"serving":
			return tr("营业中")
		"closed":
			return tr("已打烊")
	return s


func _weather_text() -> String:
	return tr(Catalog.get_weather()[GameState.weather_id].display_name)


func _regular_status() -> String:
	var parts: Array = []
	for r in GameState.regulars:
		var s: String = tr(r["name"])
		if r["lost"]:
			s += tr("(流失)")
		elif r["relationship"] >= 2:
			s += "❤"
		elif r["relationship"] < 0:
			s += tr("(疏远)")
		parts.append(s)
	return "、".join(parts) if not parts.is_empty() else tr("无")


func _value_color(v: float) -> Color:
	if v > 70.0:
		return Color(0.3, 0.8, 0.4)
	if v > 40.0:
		return Color(0.9, 0.8, 0.2)
	return Color(0.9, 0.3, 0.3)


func _patience_color(mood: float) -> Color:
	if mood > 0.6:
		return Color(0.3, 0.8, 0.4)
	if mood > 0.3:
		return Color(0.9, 0.8, 0.2)
	return Color(0.9, 0.25, 0.25)
