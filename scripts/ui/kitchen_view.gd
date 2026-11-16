class_name KitchenView
extends UIView
## 厨房视图：工位卡片（备菜台/灶台/装盘台）+ 待处理的菜（等工位 / 待上菜）。
## 纯渲染；点击处理在 scenes/main.gd（几何取自 GameLayout）。


## 由主场景注入：要读工位实时状态。
var kitchen: KitchenSystem
var _icons: Dictionary = {}


func _draw() -> void:
	UITheme.label(self, font, Vector2(GameLayout.W * 0.72 + 40, 110), tr("厨房"), 24, Color(0.98, 0.92, 0.82))
	UITheme.label(self, font, Vector2(GameLayout.W * 0.72 + 40, 134), tr("点菜推进一步 · 灶台做好趁热取走，晚了会糊锅"), 13, Color(0.82, 0.76, 0.70))
	for i in range(kitchen.stations.size()):
		_draw_station(kitchen.stations[i], GameLayout.station_pos(i))
	# 待处理的菜：等工位的 / 做完待上菜的（在工位上的菜由工位卡片绘制）
	var waiting := GameLayout.waiting_dishes(GameState.customers)
	for i in range(waiting.size()):
		_draw_waiting_dish(waiting[i], GameLayout.waiting_pos(i))


func _draw_station(s: Dictionary, pos: Vector2) -> void:
	var rect := Rect2(pos + Vector2(-78, -62), Vector2(156, 128))
	# 状态光晕（烹饪蓝 / 完成绿 / 清理橙）
	var glow: Color = Color(0, 0, 0, 0)
	match s["phase"]:
		"cooking":
			glow = Color(0.35, 0.75, 0.95, 0.22)
		"done":
			glow = Color(0.35, 0.9, 0.45, 0.10 + 0.10 * absf(sin(_t * 5.0)))
		"blocked":
			glow = Color(0.95, 0.55, 0.25, 0.18)
	if glow.a > 0.0:
		UITheme.panel(self, rect.grow(7), glow, 18)
	# 玻璃卡片：深棕 + 亮边 + 投影
	UITheme.panel(self, rect, Color(0.19, 0.15, 0.14, 0.93), 14, Color(1, 1, 1, 0.12), 1, 8, Vector2(0, 4))
	UITheme.label(self, font, rect.position + Vector2(12, 24), tr(s["name"]), 15, Color(1.0, 0.93, 0.82))
	# 工位设备图标（左上角）
	if _icons.is_empty():
		for k in ["prep", "stove", "plate"]:
			_icons[k] = load("res://assets/sprites/icon_%s.png" % k)
	draw_texture_rect(_icons.get(s["kind"]) as Texture2D, Rect2(rect.position + Vector2(10, 30), Vector2(22, 22)), false)
	match s["phase"]:
		"":
			UITheme.label(self, font, rect.position + Vector2(12, 72), tr("空闲"), 14, Color(0.58, 0.58, 0.64))
		"blocked":
			UITheme.label(self, font, rect.position + Vector2(12, 56), tr("清理中…"), 14, UITheme.GOLD)
			_draw_bar_thin(rect.position + Vector2(12, 72), 132, 10, 1.0 - s["timer"] / 3.0, UITheme.GOLD)
		"cooking", "done":
			var c := GameState.get_customer_by_id(s["customer_id"])
			if c.is_empty():
				return
			var recipe := Catalog.get_recipe_by_id(c["recipe_id"])
			var step: Dictionary = recipe.steps[c["make_progress"]]
			# 食物放在小圆托盘上
			draw_circle(rect.position + Vector2(36, 76), 17, Color(0, 0, 0, 0.25))
			draw_circle(rect.position + Vector2(36, 76), 15, Color(0.92, 0.88, 0.80))
			_draw_food(rect.position + Vector2(36, 76), 11, c["recipe_id"])
			UITheme.label(self, font, rect.position + Vector2(70, 52), tr(step["name"]), 14, Color(0.97, 0.92, 0.84))
			if s["phase"] == "cooking":
				_draw_bar_thin(rect.position + Vector2(70, 62), 76, 9, 1.0 - s["timer"] / maxf(step["sec"], 0.01), UITheme.BLUE)
				UITheme.label(self, font, rect.position + Vector2(70, 92), tr("制作中…"), 14, Color(0.70, 0.78, 0.88))
			else:
				var pulse := 0.6 + 0.4 * absf(sin(_t * 5.0))
				UITheme.label(self, font, rect.position + Vector2(70, 78), tr("✓ 点我取走"), 14, Color(0.45, 0.95, 0.55, pulse))
				if s["burn_timer"] > 0.0:
					_draw_bar_thin(rect.position + Vector2(70, 88), 76, 8, s["burn_timer"] / KitchenSystem.BURN_GRACE, UITheme.RED)
					UITheme.badge(self, Rect2(rect.position + Vector2(10, 100), Vector2(88, 18)), tr("快糊了！"), font, UITheme.RED.darkened(0.1), Color.WHITE, 12)


func _draw_waiting_dish(c: Dictionary, pos: Vector2) -> void:
	if c["state"] == "ready":
		var pulse := 1.0 + 0.1 * sin(_t * 6.0)
		draw_arc(pos, 31 * pulse, 0, TAU, 24, Color(0.3, 0.9, 0.4, 0.55), 3.0)
		UITheme.panel(self, Rect2(pos - Vector2(25, 25), Vector2(50, 50)), Color(0.97, 0.96, 0.92), 25, Color(0, 0, 0, 0.2), 1, 5, Vector2(0, 3))
		_draw_food(pos, 15, c["recipe_id"])
		UITheme.badge(self, Rect2(pos + Vector2(-30, 28), Vector2(60, 18)), tr("✓ 上菜"), font, UITheme.GREEN.darkened(0.15), Color.WHITE, 12)
	else:
		UITheme.panel(self, Rect2(pos - Vector2(25, 25), Vector2(50, 50)), Color(0.28, 0.24, 0.24, 0.92), 25, Color(0, 0, 0, 0.25), 1, 5, Vector2(0, 3))
		_draw_food(pos, 15, c["recipe_id"])
		# 标注这道菜下一步该去的工位（备菜/灶台/装盘），对应关系一目了然
		var recipe := Catalog.get_recipe_by_id(c["recipe_id"])
		var target := tr("工位")
		if c["make_progress"] < recipe.steps.size():
			match recipe.steps[c["make_progress"]]["station"]:
				"prep":
					target = tr("备菜")
				"stove":
					target = tr("灶台")
				"plate":
					target = tr("装盘")
		UITheme.badge(self, Rect2(pos + Vector2(-36, 28), Vector2(72, 18)), tr("→%s") % target, font, Color(0.42, 0.36, 0.30), Color(1, 0.95, 0.85), 12)
