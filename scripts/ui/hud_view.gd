class_name HudView
extends UIView
## 顶部 HUD：日期 / 时间 / 季节 / 天气（含雨天加价）/ 金钱 / 食材 / 营业状态 / 卫生环境条 / 熟客状态。


func _draw() -> void:
	var w := GameLayout.W
	draw_rect(Rect2(0, 0, w, GameLayout.HUD_H), Color(0.17, 0.17, 0.23))
	var forecast := ""
	if GameState.forecast_weather_id != "":
		forecast = tr(" 明日:%s") % tr(Catalog.get_weather()[GameState.forecast_weather_id].display_name)
	var line := tr("第%d天  8:%02d  %s·天气:%s%s  ¥%d  食材:%d  %s") % [
		GameClock.day, GameClock.game_minute, tr(Catalog.get_season_name(GameState.current_season)),
		_weather_text(), forecast,
		GameState.shop["money"], GameState.shop["ingredients"], _state_text(GameState.shop["day_state"]),
	]
	draw_string(font, Vector2(16, 36), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	_draw_bar(Vector2(16, 58), 170, GameState.shop["hygiene"], tr("卫生"))
	_draw_bar(Vector2(280, 58), 170, GameState.shop["environment"], tr("环境"))
	# 熟客状态：按主行实际宽度摆放（台风天溢价等长文案时不重叠），且不出右边界
	var reg_text: String = tr("熟客:%s") % _regular_status()
	var line_w: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var reg_w: float = font.get_string_size(reg_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var reg_x: float = clampf(16.0 + line_w + 24.0, 560.0, GameLayout.W - 16.0 - reg_w)
	draw_string(font, Vector2(reg_x, 36), reg_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.7, 0.8))


func _state_text(s: String) -> String:
	match s:
		"preparing":
			return tr("准备中")
		"serving":
			return tr("营业中")
		"closed":
			return tr("已打烊")
	return s


## 天气文本：雨天/台风有单价加成时标注出来（客人少但愿意多付钱）。
func _weather_text() -> String:
	var w: WeatherType = Catalog.get_weather()[GameState.weather_id]
	var premium: float = GameState.weather_modifiers.get("price", 1.0)
	if premium > 1.0:
		return "%s(单价+%d%%)" % [tr(w.display_name), roundi((premium - 1.0) * 100.0)]
	return tr(w.display_name)


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
