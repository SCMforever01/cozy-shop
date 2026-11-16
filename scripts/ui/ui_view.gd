class_name UIView
extends Node2D
## UI 视图基类：持有字体，提供按钮 / 条形 / 食物等共享绘制辅助。
## 视觉语言统一走 UITheme（圆角面板/阴影/胶囊条），各子视图只负责自己那层的构图。


## 像素字体（fusion-pixel 子集，覆盖游戏全部用字）；缺字回退 NotoSansSC。
const FONT_PATH := "res://assets/fonts/fusion_pixel.ttf"
const FALLBACK_FONT_PATH := "res://assets/fonts/NotoSansSC-Static.ttf"

var font: Font = preload(FONT_PATH)


func _init() -> void:
	var ff := font as FontFile
	if ff != null and ff.fallbacks.is_empty():
		ff.fallbacks = [load(FALLBACK_FONT_PATH)]
## 动画时钟（秒），子类画脉冲/蒸汽等效果直接用。
var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	_animate(delta)
	queue_redraw()


## 子类可覆写：每帧更新动画状态。
func _animate(_delta: float) -> void:
	pass


## 主题按钮。kind: accent/green/brown/red/grey。
func _draw_button(rect: Rect2, text: String, enabled: bool, kind: String = "accent", font_size: int = 18) -> void:
	UITheme.button(self, rect, text, font, kind, enabled, font_size)


## 数值条（卫生 / 环境）：胶囊进度条 + 描边标签。
func _draw_bar(pos: Vector2, width: float, value: float, label: String) -> void:
	UITheme.label(self, font, pos + Vector2(0, 2), label, 13, Color(0.92, 0.88, 0.82))
	UITheme.progress(self, Rect2(pos + Vector2(44, -11), Vector2(width, 12)), value / 100.0, _value_color(value))


## 细进度条（工位卡里用）。
func _draw_bar_thin(pos: Vector2, w: float, h: float, ratio: float, color: Color) -> void:
	UITheme.progress(self, Rect2(pos, Vector2(w, h)), ratio, color)


func _value_color(v: float) -> Color:
	if v > 70.0:
		return UITheme.GREEN
	if v > 40.0:
		return UITheme.GOLD
	return UITheme.RED


func _patience_color(mood: float) -> Color:
	if mood > 0.6:
		return UITheme.GREEN
	if mood > 0.3:
		return UITheme.GOLD
	return UITheme.RED


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
