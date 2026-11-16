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
var _customer_textures: Dictionary = {}
var _decor_textures: Dictionary = {}
var _bg_texture: Texture2D


func _ready() -> void:
	_bg_texture = load("res://assets/sprites/shop_bg.png")
	for key in ["laozhang", "xiaowang", "lijie", "critic", "g0", "g1", "g2", "g3", "g4", "g5"]:
		_customer_textures[key] = load("res://assets/sprites/customer_%s.png" % key)
	for key in ["plant_a", "plant_b", "picture"]:
		_decor_textures[key] = load("res://assets/sprites/decor_%s.png" % key)


func _animate(_delta: float) -> void:
	# 记录新顾客入场时间；离场后清理
	for c in GameState.customers:
		if not _entered_at.has(c["id"]):
			_entered_at[c["id"]] = _t
	var alive := {}
	for c in GameState.customers:
		alive[c["id"]] = true
	for id in _entered_at.keys():
		if not alive.has(id):
			_entered_at.erase(id)


func _draw() -> void:
	_draw_floor()
	_draw_dirt()
	_draw_decor()
	_draw_sun()
	_draw_customers()
	_draw_tables()


func _draw_floor() -> void:
	if GameLayout.use_sprites and _bg_texture != null:
		draw_texture_rect(_bg_texture, Rect2(0, 0, GameLayout.W, GameLayout.H), false)
	else:
		draw_rect(Rect2(0, GameLayout.HUD_H, GameLayout.W, GameLayout.H - GameLayout.HUD_H), Color(0.96, 0.94, 0.88))
		draw_rect(Rect2(GameLayout.W * 0.72, GameLayout.HUD_H, GameLayout.W * 0.28, GameLayout.H - GameLayout.HUD_H), Color(0.83, 0.76, 0.67))
		draw_line(Vector2(GameLayout.W * 0.72, GameLayout.HUD_H), Vector2(GameLayout.W * 0.72, GameLayout.H), Color(0.55, 0.45, 0.35), 4.0)
	# 底部操作提示：居中放在「提前打烊」与「声音」按钮之间的空档，不被按钮遮挡
	var hint := tr("接单 → 上工位 → 取走 → 上菜")
	var hint_w: float = font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(font, Vector2(540.0 + maxf(0.0, (295.0 - hint_w) / 2.0), GameLayout.H - 14), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.4, 0.35, 0.3))


func _draw_dirt() -> void:
	var spots: int = GameState.dirt_spots()
	for i in range(spots):
		var p: Vector2 = GameLayout.DIRT_SPOTS[i]
		draw_circle(p, 17.0, Color(0.42, 0.3, 0.16, 0.32))
		draw_circle(p + Vector2(11, 7), 9.0, Color(0.42, 0.3, 0.16, 0.28))
		draw_circle(p + Vector2(-9, 9), 7.0, Color(0.38, 0.26, 0.13, 0.28))


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


func _draw_sun() -> void:
	if GameState.weather_id != "sunny":
		return
	var c := Vector2(GameLayout.W - 90, 110)
	draw_circle(c, 36, Color(1.0, 0.85, 0.3))
	for i in range(8):
		var a := i * TAU / 8.0
		draw_line(c + Vector2(cos(a), sin(a)) * 46, c + Vector2(cos(a), sin(a)) * 58, Color(1.0, 0.8, 0.25), 3.0)


# ---------- 顾客 ----------

func _draw_customers() -> void:
	for i in range(GameState.customers.size()):
		var c = GameState.customers[i]
		_draw_customer(c, GameLayout.customer_draw_pos(GameState.customers, c), i)


func _customer_texture(c: Dictionary) -> Texture2D:
	if c.get("is_critic", false):
		return _customer_textures.get("critic") as Texture2D
	if c["regular_id"] != "" and _customer_textures.has(c["regular_id"]):
		return _customer_textures[c["regular_id"]] as Texture2D
	return _customer_textures.get("g%d" % (int(c["id"]) % 6)) as Texture2D


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
	var sprite_mode := GameLayout.use_sprites and tex != null
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
		draw_string(font, pos + Vector2(-radius, name_dy), tr(c["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, name_color)

	# 头顶耐心条
	var bar_w := radius * 2.0
	var bar_dy: float = -56.0 if sprite_mode else -54.0
	var bar_pos := pos + Vector2(-radius, bar_dy)
	draw_rect(Rect2(bar_pos, Vector2(bar_w, 8)), Color(0, 0, 0, 0.4))
	draw_rect(Rect2(bar_pos, Vector2(bar_w * mood, 8)), _patience_color(mood))

	# 门口等座倒计时：橙色递减条 + 秒数（让玩家看到谁快走了，优先处理）
	if c.get("at_door", false):
		var ratio: float = clampf(c["door_timer"] / CustomerSystem.DOOR_WAIT, 0.0, 1.0)
		var dt_pos := pos + Vector2(-radius, bar_dy + 12)
		draw_rect(Rect2(dt_pos, Vector2(bar_w, 6)), Color(0, 0, 0, 0.4))
		draw_rect(Rect2(dt_pos, Vector2(bar_w * ratio, 6)), Color(0.95, 0.6, 0.2))
		draw_string(font, dt_pos + Vector2(bar_w + 6, 7), "%ds" % ceili(c["door_timer"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.7, 0.3))

	# 点单气泡
	_draw_bubble(pos + Vector2(radius + 16, -radius), c)


func _draw_bubble(pos: Vector2, c: Dictionary) -> void:
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
	var text: String = tr(c["recipe_name"]) + progress

	# 宽度按文字实际宽度自适应（如「奶茶（点我上工位）」不溢出）
	var bw: float = maxf(128.0, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 34.0)
	var bh := 34.0
	draw_rect(Rect2(pos, Vector2(bw, bh)), Color(1, 1, 1, 0.93))
	draw_rect(Rect2(pos, Vector2(bw, bh)), Color(0.6, 0.55, 0.5), false, 1.5)
	_draw_food(pos + Vector2(13, bh / 2), 7, c["recipe_id"])
	draw_string(font, pos + Vector2(28, bh - 11), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.1, 0.1, 0.1))


# ---------- 餐桌 ----------

## 餐桌：桌椅 + 用餐/脏盘状态（桌子画在顾客前面，像坐在桌后）。
func _draw_tables() -> void:
	for i in range(GameState.seat_capacity()):
		var seat: Dictionary = GameState.seats[i]
		var p: Vector2 = GameLayout.SEAT_POS[i]
		var level: int = GameState.shop["upgrades"]["decor"]
		var top: Color = Color(0.72, 0.52, 0.32) if level == 0 else Color(0.86, 0.72, 0.52)
		if level >= 3:
			top = Color(0.92, 0.80, 0.62)
		# 椅子
		draw_rect(Rect2(p + Vector2(-118, -34), Vector2(30, 46)), Color(0.45, 0.32, 0.20), false, 0.0)
		draw_rect(Rect2(p + Vector2(88, -34), Vector2(30, 46)), Color(0.45, 0.32, 0.20), false, 0.0)
		# 桌面
		draw_rect(Rect2(p + Vector2(-80, -18), Vector2(160, 52)), Color(0.35, 0.24, 0.14))
		draw_rect(Rect2(p + Vector2(-76, -14), Vector2(152, 44)), top)
		# 桌腿
		draw_rect(Rect2(p + Vector2(-60, 34), Vector2(12, 22)), Color(0.35, 0.24, 0.14))
		draw_rect(Rect2(p + Vector2(48, 34), Vector2(12, 22)), Color(0.35, 0.24, 0.14))
		# 盘子状态：用餐中 / 脏盘待收
		var diner := _seat_diner(seat)
		if seat["dirty"]:
			draw_circle(p + Vector2(0, 8), 17, Color(0.75, 0.75, 0.72))
			draw_circle(p + Vector2(0, 8), 11, Color(0.62, 0.60, 0.55))
			draw_circle(p + Vector2(4, 6), 4, Color(0.45, 0.32, 0.18, 0.8))
			draw_string(font, p + Vector2(-32, -26), tr("点收桌"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.6, 0.3))
		elif not diner.is_empty():
			var ratio: float = clampf(diner["dine_timer"] / 8.0, 0.0, 1.0)
			draw_circle(p + Vector2(0, 8), 17, Color(0.92, 0.92, 0.88))
			draw_circle(p + Vector2(0, 8), 11, Color(0.85, 0.72, 0.5))
			draw_circle(p + Vector2(0, 8), 11 * ratio, Color(0.92, 0.92, 0.88))


func _seat_diner(seat: Dictionary) -> Dictionary:
	if seat["customer_id"] < 0:
		return {}
	for c in GameState.customers:
		if c["id"] == seat["customer_id"] and c["state"] == "dining":
			return c
	return {}
