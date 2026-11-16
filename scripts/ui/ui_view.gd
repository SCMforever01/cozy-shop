class_name UIView
extends Node2D
## UI 视图基类：持有字体，提供按钮 / 条形 / 颜色等共享绘制辅助。
## 每个子视图只负责自己那一层的绘制（覆写 _draw）和动画（覆写 _animate），
## 主场景按添加顺序控制图层叠放。


const FONT_PATH := "res://assets/fonts/NotoSansSC-Static.ttf"

var font: Font = preload(FONT_PATH)
## 动画时钟（秒），子类画脉冲/蒸汽等效果直接用。
var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	_animate(delta)
	queue_redraw()


## 子类可覆写：每帧更新动画状态。
func _animate(_delta: float) -> void:
	pass


## 通用按钮：蓝底可点 / 灰底禁用。
func _draw_button(rect: Rect2, text: String, enabled: bool) -> void:
	var c := Color(0.33, 0.55, 0.85) if enabled else Color(0.42, 0.42, 0.45)
	draw_rect(rect, c)
	draw_rect(rect, Color(0, 0, 0, 0.3), false, 2.0)
	draw_string(font, rect.position + Vector2(12, rect.size.y - 14), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE if enabled else Color(0.72, 0.72, 0.75))


## 数值条（卫生 / 环境），带标签，按数值变色。
func _draw_bar(pos: Vector2, width: float, value: float, label: String) -> void:
	draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	var bar_rect := Rect2(pos + Vector2(40, -13), Vector2(width, 12))
	draw_rect(bar_rect, Color(0.3, 0.3, 0.35))
	draw_rect(Rect2(bar_rect.position, Vector2(width * clampf(value / 100.0, 0.0, 1.0), 12)), _value_color(value))


## 无标签进度条（工位卡片里的小进度）。
func _draw_bar_bg(pos: Vector2, w: float, h: float) -> void:
	draw_rect(Rect2(pos, Vector2(w, h)), Color(0, 0, 0, 0.45))


func _draw_bar_fill(pos: Vector2, w: float, h: float, ratio: float, color: Color) -> void:
	draw_rect(Rect2(pos, Vector2(w * clampf(ratio, 0.0, 1.0), h)), color)


## 画一个食物：像素风格用贴图，代码风格用纯色圆形。
## 兜底色取自 Recipe.fallback_color（内容数据），color_override 可覆盖（如「变熟」渐变）。
func _draw_food(pos: Vector2, radius: float, dish_id: String, color_override: Color = Color(0, 0, 0, 0)) -> void:
	var textures := _food_tex()
	if GameLayout.use_sprites and textures.has(dish_id):
		var tex: Texture2D = textures[dish_id]
		var size := radius * 2.2
		draw_texture_rect(tex, Rect2(pos.x - radius * 1.1, pos.y - radius * 1.1, size, size), false)
	else:
		var recipe := Catalog.get_recipe_by_id(dish_id)
		var fallback: Color = recipe.fallback_color if recipe != null else Color.WHITE
		var c := fallback if color_override.a == 0.0 else color_override
		draw_circle(pos, radius, c)


var _food_textures: Dictionary = {}


## 食物贴图懒加载（各视图共用，只加载一次）。
func _food_tex() -> Dictionary:
	if _food_textures.is_empty():
		for id in ["milk_tea", "coffee", "juice", "sandwich", "burger", "cake", "salad", "soup", "ice_cream", "pizza"]:
			_food_textures[id] = load("res://assets/sprites/food_%s.png" % id)
	return _food_textures


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
