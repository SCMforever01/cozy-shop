class_name UITheme
extends RefCounted
## UI 主题：统一色板 + 圆角面板/按钮/胶囊条/徽章的绘制助手。
## 用 StyleBoxFlat 实现圆角/边框/阴影（实例缓存复用，避免每帧新建）。
## 所有视图的视觉语言从这里出，保证整套 UI 风格一致。


# ---------- 色板（暖色 cozy 咖啡店） ----------
const INK := Color(0.22, 0.18, 0.16)            ## 主文字深棕
const INK_SOFT := Color(0.42, 0.36, 0.32)       ## 次级文字
const CREAM := Color(0.98, 0.95, 0.88)          ## 米白面板
const CREAM_DIM := Color(0.93, 0.88, 0.78)      ## 米白暗调
const ESPRESSO := Color(0.24, 0.18, 0.16, 0.94) ## 深棕面板
const ESPRESSO_SOFT := Color(0.32, 0.25, 0.22, 0.85)
const ACCENT := Color(0.86, 0.49, 0.25)         ## 焦糖橙（主按钮）
const ACCENT_DARK := Color(0.70, 0.37, 0.17)
const GREEN := Color(0.42, 0.66, 0.38)          ## 抹茶绿（可购/成功）
const GREEN_DARK := Color(0.31, 0.52, 0.28)
const RED := Color(0.83, 0.38, 0.33)            ## 番茄红（危险/糊锅）
const GOLD := Color(0.94, 0.76, 0.32)           ## 暖黄（金钱/提示）
const BLUE := Color(0.40, 0.62, 0.83)           ## 天蓝（进度/烹饪）
const SHADOW := Color(0, 0, 0, 0.28)

static var _boxes: Dictionary = {}


## 取缓存的 StyleBoxFlat。key 由参数拼出。
static func _box(bg: Color, radius: int, border: Color, border_w: int, shadow: int, shadow_ofs: Vector2) -> StyleBoxFlat:
	var key := "%s|%d|%s|%d|%d|%s" % [bg.to_html(), radius, border.to_html(), border_w, shadow, shadow_ofs]
	if not _boxes.has(key):
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg
		sb.set_corner_radius_all(radius)
		if border_w > 0:
			sb.set_border_width_all(border_w)
			sb.border_color = border
		if shadow > 0:
			sb.shadow_color = SHADOW
			sb.shadow_size = shadow
			sb.shadow_offset = shadow_ofs
		sb.content_margin_left = 0
		sb.content_margin_right = 0
		sb.content_margin_top = 0
		sb.content_margin_bottom = 0
		_boxes[key] = sb
	return _boxes[key]


## 圆角面板（可带边框和投影）。
static func panel(canvas: CanvasItem, rect: Rect2, bg: Color, radius: int = 12, border: Color = Color(0, 0, 0, 0), border_w: int = 0, shadow: int = 0, shadow_ofs: Vector2 = Vector2(0, 3)) -> void:
	canvas.draw_style_box(_box(bg, radius, border, border_w, shadow, shadow_ofs), rect)


## 按钮：底色 + 顶部高光条 + 底部暗边，营造立体感。kind: accent/green/grey/brown/red。
static func button(canvas: CanvasItem, rect: Rect2, label: String, font: Font, kind: String, enabled: bool = true, font_size: int = 18) -> void:
	var base: Color
	var edge: Color
	match kind:
		"accent":
			base = ACCENT
			edge = ACCENT_DARK
		"green":
			base = GREEN
			edge = GREEN_DARK
		"red":
			base = RED
			edge = RED.darkened(0.2)
		"brown":
			base = Color(0.55, 0.40, 0.24)
			edge = Color(0.42, 0.29, 0.16)
		_:
			base = Color(0.52, 0.50, 0.52)
			edge = Color(0.38, 0.36, 0.38)
	if not enabled:
		base = Color(0.47, 0.45, 0.45)
		edge = Color(0.35, 0.33, 0.33)
	var r := rect
	canvas.draw_style_box(_box(base, 10, edge, 2, 5, Vector2(0, 3)), r)
	# 顶部高光
	canvas.draw_style_box(_box(Color(1, 1, 1, 0.16), 8, Color(0, 0, 0, 0), 0, 0, Vector2()), Rect2(r.position + Vector2(4, 3), Vector2(r.size.x - 8, r.size.y * 0.42)))
	var text_color := Color.WHITE if enabled else Color(0.95, 0.93, 0.90)
	if enabled:
		text_color = text_color.darkened(0.0)
	# 文字带 1px 暗描边（浅底上也清楚）
	var tp := r.position + Vector2(0, r.size.y * 0.5) + Vector2(0, font.get_ascent(font_size) * 0.5 - 2)
	for ofs in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		canvas.draw_string(font, tp + ofs, label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, font_size, Color(0, 0, 0, 0.35))
	canvas.draw_string(font, tp, label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, font_size, text_color)


## 胶囊进度条（圆角底 + 渐变感填充 + 高光）。
static func progress(canvas: CanvasItem, rect: Rect2, ratio: float, fill: Color, bg: Color = Color(0, 0, 0, 0.42)) -> void:
	canvas.draw_style_box(_box(bg, rect.size.y / 2.0, Color(0, 0, 0, 0), 0, 0, Vector2()), rect)
	var w: float = (rect.size.x - 2.0) * clampf(ratio, 0.0, 1.0)
	if w < 4.0:
		return
	var fill_rect := Rect2(rect.position + Vector2(1, 1), Vector2(w, rect.size.y - 2))
	canvas.draw_style_box(_box(fill, (rect.size.y - 2.0) / 2.0, Color(0, 0, 0, 0), 0, 0, Vector2()), fill_rect)
	canvas.draw_style_box(_box(Color(1, 1, 1, 0.22), (rect.size.y - 2.0) / 2.0, Color(0, 0, 0, 0), 0, 0, Vector2()), Rect2(fill_rect.position + Vector2(2, 1), Vector2(maxf(w - 4, 2), fill_rect.size.y * 0.38)))


## 小徽章（顾客头顶名字/状态用）。
static func badge(canvas: CanvasItem, rect: Rect2, text: String, font: Font, bg: Color, fg: Color, font_size: int = 13) -> void:
	canvas.draw_style_box(_box(bg, 8, Color(0, 0, 0, 0), 0, 3, Vector2(0, 2)), rect)
	canvas.draw_string(font, rect.position + Vector2(0, rect.size.y * 0.5 + font.get_ascent(font_size) * 0.5 - 2), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, fg)


## 带阴影的描边文字（浮在场景上的文字都走它）。
static func label(canvas: CanvasItem, font: Font, pos: Vector2, text: String, size: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	for ofs in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		canvas.draw_string(font, pos + ofs, text, align, width, size, Color(0, 0, 0, 0.45))
	canvas.draw_string(font, pos, text, align, width, size, color)
