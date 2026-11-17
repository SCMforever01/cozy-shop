class_name ShopView
extends UIView
## 店铺主视图：地板/背景、污渍、装修、太阳、餐桌、顾客、点单气泡。
## 纯渲染 + 入场动画，游戏逻辑全在 systems（本层只读 GameState）。


## 顾客身体配色（纯色模式下普通顾客轮换；熟客 / 评论家另有专属色）。
const CUSTOMER_COLORS := [
	Color(0.45, 0.70, 0.90),
	Color(0.95, 0.65, 0.75),
	Color(0.60, 0.80, 0.55),
	Color(0.90, 0.75, 0.50),
	Color(0.70, 0.60, 0.90),
]

var _entered_at: Dictionary = {}  # customer_id -> 入场时间（做缩放入场动画）
## 顾客最近绘制位置（供 +¥ 飘字跟随付钱客人；由 _animate 每帧刷新）
static var last_customer_pos: Dictionary = {}
var _rain: Array = []             # {x, y, speed} 雨滴（画在场景上、UI 之下）
var _customer_textures: Dictionary = {}
var _decor_textures: Dictionary = {}
var _bg_texture: Texture2D
var _table_tex: Texture2D


func _ready() -> void:
	EventBus.subscribe("weather.changed", _on_weather_changed)
	_bg_texture = load("res://assets/sprites/shop_bg.png")
	for key in ["laozhang", "xiaowang", "lijie", "critic", "g0", "g1", "g2", "g3", "g4", "g5"]:
		_customer_textures[key] = load("res://assets/sprites/customer_%s.png" % key)
	for key in ["plant_a", "plant_b", "picture"]:
		_decor_textures[key] = load("res://assets/sprites/decor_%s.png" % key)


func _exit_tree() -> void:
	EventBus.unsubscribe("weather.changed", _on_weather_changed)


## 窗户玻璃区域（游戏坐标）：雨只落在窗外，室内不再"下雨"。
const WINDOW_RECTS := [Rect2(140, 36, 72, 56), Rect2(360, 36, 72, 56)]


func _on_weather_changed(weather_id: String) -> void:
	if weather_id == "rain" or weather_id == "storm" or weather_id == "typhoon":
		_spawn_rain()
	else:
		_rain.clear()


func _spawn_rain() -> void:
	_rain.clear()
	for i in range(24):
		var win: Rect2 = WINDOW_RECTS[i % 2]
		_rain.append({
			"x": win.position.x + randf() * win.size.x,
			"y": win.position.y + randf() * win.size.y,
			"speed": 90.0 + randf() * 70.0,
			"win": i % 2,
		})


func _animate(_delta: float) -> void:
	for d in _rain:
		d["y"] += d["speed"] * _delta
		var win: Rect2 = WINDOW_RECTS[d["win"]]
		if d["y"] > win.end.y:
			d["y"] = win.position.y
			d["x"] = win.position.x + randf() * win.size.x
	# 记录新顾客入场时间；离场后清理
	for c in GameState.customers:
		if not _entered_at.has(c["id"]):
			_entered_at[c["id"]] = _t
		last_customer_pos[c["id"]] = GameLayout.customer_draw_pos(GameState.customers, c)
	var alive := {}
	for c in GameState.customers:
		alive[c["id"]] = true
	for id in _entered_at.keys():
		if not alive.has(id):
			_entered_at.erase(id)
	for id in last_customer_pos.keys():
		if not alive.has(id):
			last_customer_pos.erase(id)


func _draw() -> void:
	_draw_floor()
	_draw_dirt()
	_draw_decor()
	_draw_sun()
	_draw_customers()
	_draw_tables()
	# 窗外雨（只在窗玻璃范围内）
	for d in _rain:
		draw_line(Vector2(d["x"], d["y"]), Vector2(d["x"] - 1, d["y"] + 7), Color(0.55, 0.72, 0.95, 0.75), 1.5)
	_weather_tint()


func _draw_floor() -> void:
	if GameLayout.use_sprites and _bg_texture != null:
		draw_texture_rect(_bg_texture, Rect2(0, 0, GameLayout.W, GameLayout.H), false)
	else:
		draw_rect(Rect2(0, GameLayout.HUD_H, GameLayout.W, GameLayout.H - GameLayout.HUD_H), Color(0.96, 0.94, 0.88))
		draw_rect(Rect2(GameLayout.W * 0.72, GameLayout.HUD_H, GameLayout.W * 0.28, GameLayout.H - GameLayout.HUD_H), Color(0.83, 0.76, 0.67))
		draw_line(Vector2(GameLayout.W * 0.72, GameLayout.HUD_H), Vector2(GameLayout.W * 0.72, GameLayout.H), Color(0.55, 0.45, 0.35), 4.0)
	# 厨房区遮罩（让右侧工作区更沉、和客席区分开）
	draw_rect(Rect2(GameLayout.W * 0.72, GameLayout.HUD_H, GameLayout.W * 0.28, GameLayout.H - GameLayout.HUD_H), Color(0.10, 0.08, 0.10, 0.18))



func _draw_dirt() -> void:
	var spots: int = GameState.dirt_spots()
	for i in range(spots):
		var p: Vector2 = GameLayout.DIRT_SPOTS[i]
		draw_circle(p, 17.0, Color(0.42, 0.3, 0.16, 0.26))
		draw_circle(p + Vector2(11, 7), 9.0, Color(0.42, 0.3, 0.16, 0.22))
		draw_circle(p + Vector2(-9, 9), 7.0, Color(0.38, 0.26, 0.13, 0.22))


## 装修效果可见化（v2 P2）：每级升级立刻看得见。
func _draw_decor() -> void:
	var level: int = GameState.shop["upgrades"]["decor"]
	if level >= 1:
		# Lv1 绿植点缀
		_draw_decor_tex("plant_a", Vector2(110, 478), 3)
		_draw_decor_tex("plant_b", Vector2(872, 210), 3)
	if level >= 2:
		# Lv2 墙面挂画
		_draw_decor_tex("picture", Vector2(352, 62), 3)
		_draw_decor_tex("picture", Vector2(652, 62), 3)
	if level >= 3:
		# Lv3 灯光氛围：暖色光晕
		draw_circle(Vector2(352, 110), 120, Color(1.0, 0.85, 0.55, 0.10))
		draw_circle(Vector2(652, 110), 120, Color(1.0, 0.85, 0.55, 0.10))
		draw_circle(Vector2(435, 330), 150, Color(1.0, 0.85, 0.55, 0.07))


func _draw_decor_tex(key: String, pos: Vector2, scale: int) -> void:
	var tex: Texture2D = _decor_textures.get(key) as Texture2D
	if tex == null:
		return
	var s := 16.0 * scale
	draw_texture_rect(tex, Rect2(pos.x - s / 2, pos.y - s / 2, s, s), false)


## 天气氛围：窗户暖光柱（晴/阴）+ 全屏色调（雨蓝、台风暗紫）。
func _weather_tint() -> void:
	var full := Rect2(0, 0, GameLayout.W, GameLayout.H)
	match GameState.weather_id:
		"sunny":
			_draw_window_light(140, 212)
			_draw_window_light(360, 432)
		"overcast":
			draw_rect(full, Color(0.55, 0.55, 0.62, 0.08))
		"rain":
			draw_rect(full, Color(0.42, 0.50, 0.72, 0.11))
		"storm":
			draw_rect(full, Color(0.33, 0.38, 0.64, 0.17))
		"typhoon":
			draw_rect(full, Color(0.26, 0.28, 0.46, 0.23))


## 从窗户斜射到地板的暖光柱。
func _draw_window_light(x0: float, x1: float) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(x0, 92), Vector2(x1, 92), Vector2(x1 + 120, 420), Vector2(x0 + 120, 420),
	]), Color(1.0, 0.87, 0.55, 0.10))


func _draw_sun() -> void:
	if GameState.weather_id != "sunny":
		return
	# 位置在客席区上空（不压厨房提示文字），像素风方块射线
	var c := Vector2(830, 96)
	draw_circle(c, 30, Color(1.0, 0.85, 0.3))
	draw_circle(c, 22, Color(1.0, 0.92, 0.55))
	for i in range(8):
		var a := i * TAU / 8.0
		var rp := c + Vector2(cos(a), sin(a)) * 42
		draw_rect(Rect2(rp - Vector2(4, 4), Vector2(8, 8)), Color(1.0, 0.8, 0.25))


# ---------- 顾客 ----------

func _draw_customers() -> void:
	# 气泡防重叠：先算好每个气泡的位置（重叠就上移避让），再统一绘制
	var n := GameState.customers.size()
	var ofs: Array = []
	ofs.resize(n)
	var placed: Array = []  # 已放置的气泡矩形
	for i in range(n):
		var c = GameState.customers[i]
		var anchor: Vector2 = GameLayout.customer_draw_pos(GameState.customers, c) + Vector2(48, -32)
		var rect := Rect2(anchor, Vector2(_bubble_width(c), 34.0))
		for _k in range(6):
			var hit := false
			for pr in placed:
				if rect.grow(5.0).intersects(pr):
					rect = Rect2(rect.position - Vector2(0, 38.0), rect.size)
					hit = true
					break
			if not hit:
				break
		placed.append(rect)
		ofs[i] = rect.position - anchor
	for i in range(n):
		var c: Dictionary = GameState.customers[i]
		_draw_customer(c, GameLayout.customer_draw_pos(GameState.customers, c), i, ofs[i])
	_draw_door_aggregate()
	# 第二遍：点单气泡统一画在最上层（高峰时不被倒计时芯片/名牌盖住）
	for i in range(n):
		var c2: Dictionary = GameState.customers[i]
		if c2.get("at_door", false) and GameLayout.door_index(GameState.customers, c2) > 0:
			continue
		_draw_bubble(GameLayout.customer_draw_pos(GameState.customers, c2) + Vector2(48, -32), c2, ofs[i])


func _customer_texture(c: Dictionary) -> Texture2D:
	if c.get("is_critic", false):
		return _customer_textures.get("critic") as Texture2D
	if c["regular_id"] != "" and _customer_textures.has(c["regular_id"]):
		return _customer_textures[c["regular_id"]] as Texture2D
	return _customer_textures.get("g%d" % (int(c["id"]) % 6)) as Texture2D


func _draw_customer(c: Dictionary, pos: Vector2, idx: int, bubble_ofs: Vector2 = Vector2.ZERO) -> void:
	# 待机浮动：轻微上下摆 + 左右摇，让画面活起来
	pos += Vector2(sin(_t * 2.0 + idx * 1.7) * 1.2, sin(_t * 3.1 + idx * 2.3) * 1.6)
	var radius := 32.0
	var mood := clampf(c["patience"] / c["patience_max"], 0.0, 1.0)
	# 生气（耐心 <30%）：身体发抖
	if mood < 0.3:
		pos.x += sin(_t * 28.0) * 1.8
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
	var sprite_mode := GameLayout.use_sprites and tex != null
	if sprite_mode:
		var s := r * 1.9
		draw_circle(pos + Vector2(0, radius * 0.66), radius * 0.62, Color(0, 0, 0, 0.14))
		draw_texture_rect(tex, Rect2(pos.x - s / 2, pos.y - s / 2, s, s), false)
		# 心情角标（小圆徽章）
		var badge_pos := pos + Vector2(radius * 0.72, -radius * 0.72)
		UITheme.panel(self, Rect2(badge_pos - Vector2(9, 9), Vector2(18, 18)), Color(1, 1, 1, 0.92), 9, Color(0, 0, 0, 0.15), 1)
		if mood > 0.5:
			draw_arc(badge_pos, 5.5 * scale, PI + 0.2, TAU - 0.2, 8, UITheme.GREEN.darkened(0.15), 2.0)
		else:
			draw_arc(badge_pos, 5.5 * scale, 0.2, PI - 0.2, 8, UITheme.RED, 2.0)
	else:
		draw_circle(pos + Vector2(0, radius - 4), radius, Color(0, 0, 0, 0.14))
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

	# 生气怒纹（耐心告急）
	if mood < 0.3:
		for k in range(3):
			var vx := pos.x - 14.0 + k * 14.0
			draw_line(Vector2(vx, pos.y - 62), Vector2(vx + 5, pos.y - 70), UITheme.RED, 2.5)
	# 用餐中的爱心（好吃！）
	if c["state"] == "dining":
		var hy: float = pos.y - 52.0 - fmod(_t * 18.0 + idx * 7.0, 14.0)
		var hx2 := pos.x + 16.0 + sin(_t * 3.0 + idx) * 3.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(hx2, hy + 5), Vector2(hx2 - 5, hy), Vector2(hx2 - 3, hy - 4),
			Vector2(hx2, hy - 2), Vector2(hx2 + 3, hy - 4), Vector2(hx2 + 5, hy),
		]), Color(1.0, 0.55, 0.62, 0.9))

	# 生日帽
	if c.get("celebrating", false):
		draw_colored_polygon(PackedVector2Array([
			pos + Vector2(0, -radius - 8),
			pos + Vector2(-14, -radius + 6),
			pos + Vector2(14, -radius + 6),
		]), UITheme.RED)
		draw_circle(pos + Vector2(0, -radius - 10), 4, UITheme.GOLD)

	# 名牌徽章（熟客 / 评论家）
	if c["regular_id"] != "" or c.get("is_critic", false):
		var is_regular: bool = c["regular_id"] != ""
		var name_dy: float = -31.0 if sprite_mode else -52.0
		var name: String = tr(c["name"])
		var nw: float = font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 14
		UITheme.badge(self, Rect2(pos + Vector2(-nw / 2, name_dy), Vector2(nw, 18)), name, font,
			Color(0.42, 0.28, 0.16, 0.92) if is_regular else Color(0.32, 0.22, 0.42, 0.92),
			Color(1.0, 0.88, 0.55) if is_regular else Color(0.90, 0.78, 1.0), 13)

	# 头顶耐心条（胶囊）
	var bar_w := radius * 2.0
	var bar_dy: float = -52.0 if sprite_mode else -72.0
	UITheme.progress(self, Rect2(pos + Vector2(-radius, bar_dy), Vector2(bar_w, 8)), mood, _patience_color(mood))

	# 门口等座倒计时：秒数徽章挂在耐心条右端（跟条走，最紧急信息最显眼）
	if c.get("at_door", false):
		UITheme.badge(self, Rect2(pos + Vector2(radius + 4, bar_dy - 3 + (idx % 2) * 10.0), Vector2(34, 15)), "%ds" % ceili(c["door_timer"]), font, Color(0.45, 0.32, 0.10, 0.92), UITheme.GOLD, 11)

	# 等位客人不画逐人徽章（聚合气泡由 _draw_customers 统一画）；点单气泡最后统一画


## 等位聚合气泡：队首一枚「等座 N 人（最快 Xs）」，替代逐人徽章（高峰不再叠压）。
func _draw_door_aggregate() -> void:
	var waiting: Array = []
	for c in GameState.customers:
		if c.get("at_door", false):
			waiting.append(c)
	if waiting.is_empty():
		return
	var fastest := 999.0
	for c in waiting:
		fastest = minf(fastest, c["door_timer"])
	var text: String = tr("等座 %d 人（最快 %ds）") % [waiting.size(), ceili(fastest)]
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 26.0
	var anchor: Vector2 = GameLayout.door_queue_pos(0) + Vector2(0, -86)
	UITheme.panel(self, Rect2(anchor, Vector2(w, 26)), UITheme.CREAM, 9, Color(0.35, 0.27, 0.20, 0.4), 1, 5, Vector2(0, 3))
	UITheme.label(self, font, anchor + Vector2(13, 18), text, 14, UITheme.INK)


## 气泡完整文本（内容随状态变化）。
func _bubble_text(c: Dictionary) -> String:
	var progress := ""
	if c["state"] == "dining":
		progress = tr("（好吃！）")
	elif c.get("at_door", false):
		progress = tr("（等座位…）")
	elif c["state"] == "waiting":
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
	return tr(c["recipe_name"]) + progress


## 气泡宽度（与 _draw_bubble 口径一致，供防重叠布局用）。
func _bubble_width(c: Dictionary) -> float:
	return maxf(150.0, font.get_string_size(_bubble_text(c), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 52.0)


## 点单气泡：米白圆角卡片 + 投影 + 小尾巴 + 食物图标框。
func _draw_bubble(pos: Vector2, c: Dictionary, extra_ofs: Vector2 = Vector2.ZERO) -> void:
	pos += extra_ofs
	var text: String = _bubble_text(c)
	var bw: float = _bubble_width(c)
	var bh := 38.0
	# 小尾巴（指向顾客）
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(2, 12), pos + Vector2(2, 26), pos + Vector2(-12, 16),
	]), UITheme.CREAM)
	UITheme.panel(self, Rect2(pos, Vector2(bw, bh)), UITheme.CREAM, 11, Color(0.35, 0.27, 0.20, 0.35), 1, 6, Vector2(0, 3))
	# 食物图标框
	UITheme.panel(self, Rect2(pos + Vector2(7, 5), Vector2(28, 28)), Color(1, 1, 1, 0.75), 8)
	_draw_food(pos + Vector2(21, 19), 9, c["recipe_id"])
	UITheme.label(self, font, pos + Vector2(42, 25), text, 15, UITheme.INK)
	# 可操作气泡带按键提示（空格=分诊键，一键代劳）
	if _is_actionable(c):
		var cap := Rect2(pos + Vector2(bw - 46, bh + 2), Vector2(42, 17))
		UITheme.panel(self, cap, Color(0.28, 0.23, 0.20, 0.92), 5, Color(1, 1, 1, 0.18), 1)
		UITheme.label(self, font, cap.position + Vector2(6, 13), tr("空格"), 11, Color(0.95, 0.90, 0.78))


## 气泡是否对应可按空格推进的操作。
func _is_actionable(c: Dictionary) -> bool:
	if c["state"] == "waiting":
		return not c.get("at_door", false)
	if c["state"] == "being_served":
		return c["cook"]["phase"] != "cooking"
	return c["state"] == "ready"


# ---------- 餐桌 ----------

## 餐桌：生成的桌椅组合贴图 + 用餐/脏盘状态。
func _draw_tables() -> void:
	if _table_tex == null:
		_table_tex = load("res://assets/sprites/table_set.png")
	for i in range(GameState.seat_capacity()):
		var seat: Dictionary = GameState.seats[i]
		var p: Vector2 = GameLayout.SEAT_POS[i]
		# 桌椅组合（含阴影），中心对齐座位点
		draw_texture_rect(_table_tex, Rect2(p + Vector2(-120, -40), Vector2(240, 100)), false)
		# 盘子状态：用餐中 / 脏盘待收
		var diner := _seat_diner(seat)
		if seat["dirty"]:
			draw_circle(p + Vector2(0, 8), 17, Color(0.78, 0.78, 0.75))
			draw_circle(p + Vector2(0, 8), 11, Color(0.64, 0.62, 0.57))
			draw_circle(p + Vector2(4, 6), 4, Color(0.45, 0.32, 0.18, 0.8))
			UITheme.badge(self, Rect2(p + Vector2(-38, -48), Vector2(76, 20)), tr("点收桌"), font, UITheme.ACCENT.darkened(0.15), Color.WHITE, 13)
		elif not diner.is_empty():
			var ratio: float = clampf(diner["dine_timer"] / 8.0, 0.0, 1.0)
			draw_circle(p + Vector2(0, 8), 17, Color(0.93, 0.93, 0.89))
			draw_circle(p + Vector2(0, 8), 11, Color(0.86, 0.73, 0.51))
			draw_circle(p + Vector2(0, 8), 11 * (1.0 - ratio), Color(0.93, 0.93, 0.89))


func _seat_diner(seat: Dictionary) -> Dictionary:
	if seat["customer_id"] < 0:
		return {}
	for c in GameState.customers:
		if c["id"] == seat["customer_id"] and c["state"] == "dining":
			return c
	return {}
