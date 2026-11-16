class_name KitchenView
extends UIView
## 厨房视图：工位卡片（备菜台/灶台/装盘台）+ 待处理的菜（等工位 / 待上菜）。
## 纯渲染；点击处理在 scenes/main.gd（几何取自 GameLayout）。


## 由主场景注入：要读工位实时状态。
var kitchen: KitchenSystem


func _draw() -> void:
	draw_string(font, Vector2(GameLayout.W * 0.72 + 40, 110), tr("厨房"), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.45, 0.35, 0.25))
	draw_string(font, Vector2(GameLayout.W * 0.72 + 40, 134), tr("点菜推进一步 · 灶台做好趁热取走，晚了会糊锅"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.55, 0.5, 0.45))
	for i in range(kitchen.stations.size()):
		_draw_station(kitchen.stations[i], GameLayout.station_pos(i))
	# 待处理的菜：等工位的 / 做完待上菜的（在工位上的菜由工位卡片绘制）
	var waiting := GameLayout.waiting_dishes(GameState.customers)
	for i in range(waiting.size()):
		_draw_waiting_dish(waiting[i], GameLayout.waiting_pos(i))


func _draw_station(s: Dictionary, pos: Vector2) -> void:
	var rect := Rect2(pos + Vector2(-78, -62), Vector2(156, 128))
	draw_rect(rect, Color(0.16, 0.15, 0.2, 0.88))
	draw_rect(rect, Color(0.55, 0.5, 0.42, 0.9), false, 2.0)
	draw_string(font, rect.position + Vector2(12, 24), tr(s["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.95, 0.85))
	match s["phase"]:
		"":
			draw_string(font, rect.position + Vector2(12, 72), tr("空闲"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.58, 0.58, 0.64))
		"blocked":
			draw_string(font, rect.position + Vector2(12, 56), tr("清理中…"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.5, 0.3))
			_draw_bar_bg(rect.position + Vector2(12, 72), 132, 10)
			_draw_bar_fill(rect.position + Vector2(12, 72), 132, 10, 1.0 - s["timer"] / 3.0, Color(0.9, 0.5, 0.3))
		"cooking", "done":
			var c := GameState.get_customer_by_id(s["customer_id"])
			if c.is_empty():
				return
			var dish_color: Color = _dish_color(c["recipe_id"])
			var recipe := Catalog.get_recipe_by_id(c["recipe_id"])
			var step: Dictionary = recipe.steps[c["make_progress"]]
			_draw_food(rect.position + Vector2(36, 76), 21, c["recipe_id"], dish_color)
			draw_string(font, rect.position + Vector2(70, 52), tr(step["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.9, 0.8))
			if s["phase"] == "cooking":
				_draw_bar_bg(rect.position + Vector2(70, 62), 76, 9)
				var prog: float = 1.0 - s["timer"] / maxf(step["sec"], 0.01)
				_draw_bar_fill(rect.position + Vector2(70, 62), 76, 9, prog, Color(0.35, 0.75, 0.95))
				draw_string(font, rect.position + Vector2(70, 92), tr("制作中…"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.75, 0.85))
			else:
				var pulse := 0.6 + 0.4 * absf(sin(_t * 5.0))
				draw_string(font, rect.position + Vector2(70, 78), tr("✓ 点我取走"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.3, 0.9, 0.4, pulse))
				if s["burn_timer"] > 0.0:
					_draw_bar_bg(rect.position + Vector2(70, 88), 76, 8)
					_draw_bar_fill(rect.position + Vector2(70, 88), 76, 8, s["burn_timer"] / KitchenSystem.BURN_GRACE, Color(0.9, 0.25, 0.2))
					draw_string(font, rect.position + Vector2(12, 108), tr("快糊了！"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.35, 0.25, pulse))


func _draw_waiting_dish(c: Dictionary, pos: Vector2) -> void:
	var dish_color: Color = _dish_color(c["recipe_id"])
	if c["state"] == "ready":
		var pulse := 1.0 + 0.1 * sin(_t * 6.0)
		draw_arc(pos, 31 * pulse, 0, TAU, 24, Color(0.3, 0.9, 0.4, 0.6), 3.0)
		draw_circle(pos, 25, Color(0.96, 0.96, 0.96, 0.95))
		_draw_food(pos, 17, c["recipe_id"], dish_color)
		draw_string(font, pos + Vector2(-26, 46), tr("✓ 上菜"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.2, 0.75, 0.35))
	else:
		draw_circle(pos, 25, Color(0.22, 0.22, 0.28, 0.92))
		_draw_food(pos, 17, c["recipe_id"], dish_color)
		draw_string(font, pos + Vector2(-26, 46), tr("上工位"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.8, 0.7))


## 菜的纯色兜底（代码风格模式用）。
func _dish_color(dish_id: String) -> Color:
	var recipe := Catalog.get_recipe_by_id(dish_id)
	return recipe.fallback_color if recipe != null else Color.WHITE
