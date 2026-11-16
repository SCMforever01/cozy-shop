class_name ControlsView
extends UIView
## 底部操作台：深色圆角控制台面板 + 主题按钮（开门/拖地/打烊/重置/语言/风格/声音/升级/采购）。
## 纯渲染；点击处理在 scenes/main.gd（几何取自 GameLayout）。


## 由主场景注入：语言按钮要显示当前可切换的目标语言。
var language_system: LanguageSystem
## 由主场景注入：拖地按钮的进度和声音开关状态。
var hygiene: HygieneSystem
var audio: AudioController


func _draw() -> void:
	# 控制台底座：整条按钮区坐在一块深色圆角面板上，按钮更「成套」
	UITheme.panel(self, Rect2(12, GameLayout.H - 212, GameLayout.W - 24, 204), Color(0.17, 0.13, 0.12, 0.55), 18, Color(1, 1, 1, 0.10), 1, 10, Vector2(0, 4))

	# 主操作行
	_draw_button(GameLayout.OPEN_RECT, tr("开门营业"), GameState.shop["day_state"] == "preparing", "accent")
	var mop_label: String = tr("拖地") + " (+%d)" % int(30 + GameState.shop["upgrades"]["mop"] * 10)
	if hygiene.is_mopping():
		mop_label = tr("拖地中…")
	_draw_button(GameLayout.MOP_RECT, mop_label, GameState.shop["day_state"] == "serving", "accent")
	if hygiene.is_mopping():
		UITheme.progress(self, Rect2(GameLayout.MOP_RECT.position + Vector2(8, GameLayout.MOP_RECT.size.y - 9), Vector2(GameLayout.MOP_RECT.size.x - 16, 5)), hygiene.mop_progress(), UITheme.BLUE)
	# 台风天二选一：开门搏一把（默认） vs 台风歇业保库存
	var typhoon_day: bool = GameState.shop["day_state"] == "preparing" and GameState.weather_id == "typhoon"
	_draw_button(GameLayout.CLOSE_RECT, tr("台风歇业") if typhoon_day else tr("提前打烊"), GameState.shop["day_state"] == "serving" or typhoon_day, "green" if typhoon_day else "grey")
	_draw_button(GameLayout.RESET_RECT, tr("重置进度"), true, "grey")
	_draw_button(GameLayout.LANG_RECT, "EN" if not language_system.is_en() else "中文", true, "grey")
	_draw_button(GameLayout.STYLE_RECT, "像素" if GameLayout.use_sprites else "代码", true, "grey")
	_draw_button(GameLayout.SOUND_RECT, tr("声音 开") if audio.is_enabled() else tr("声音 关"), true, "grey")
	# 操作流程提示：居中浮在控制台空区
	var hint := tr("接单 → 上工位 → 取走 → 上菜")
	var hint_w: float = font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 28
	UITheme.badge(self, Rect2(Vector2(540 + (295 - hint_w) / 2.0, GameLayout.H - 34), Vector2(hint_w, 24)), hint, font, Color(0.98, 0.94, 0.86, 0.92), UITheme.INK_SOFT, 15)
	_draw_upgrades()


func _draw_upgrades() -> void:
	if GameState.shop["day_state"] == "closed":
		return
	_draw_buy_button(GameLayout.BUY_INGREDIENTS_RECT, tr("小份 +5 (¥15) 现有%d") % GameState.shop["ingredients"], 15)
	_draw_buy_button(GameLayout.BUY_BULK_RECT, tr("囤货 +15 (¥35) 更划算"), 35)
	if GameState.shop["day_state"] == "preparing":
		_draw_upgrade_button(GameLayout.UPGRADE_MOP_RECT, "mop")
		_draw_upgrade_button(GameLayout.UPGRADE_STOVE_RECT, "stove")
		_draw_upgrade_button(GameLayout.UPGRADE_SEAT_RECT, "seat")
		_draw_upgrade_button(GameLayout.UPGRADE_INGREDIENT_RECT, "ingredient")
		_draw_upgrade_button(GameLayout.UPGRADE_DECOR_RECT, "decor")


func _draw_buy_button(rect: Rect2, label: String, cost: int) -> void:
	var enabled: bool = GameState.shop["money"] >= cost
	_draw_button(rect, label, enabled, "brown", 15)


func _draw_upgrade_button(rect: Rect2, category: String) -> void:
	var info: Dictionary = Catalog.get_upgrades()[category]
	var level: int = GameState.shop["upgrades"][category]
	var enabled: bool = level < info["costs"].size() and GameState.shop["money"] >= info["costs"][level]
	var label: String
	if level >= info["costs"].size():
		label = tr("%s MAX") % tr(info["name"])
	else:
		label = tr("%s Lv%d→%d ¥%d") % [tr(info["name"]), level, level + 1, info["costs"][level]]
	_draw_button(rect, label, enabled, "green" if enabled else "grey", 16)
