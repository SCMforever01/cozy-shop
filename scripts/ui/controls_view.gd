class_name ControlsView
extends UIView
## 底部操作区：开门 / 拖地 / 打烊（台风歇业）/ 重置 / 语言 / 风格 / 声音按钮，
## 开店前的升级（5 类）与采购（小份/囤货）按钮。
## 纯渲染；点击处理在 scenes/main.gd（几何取自 GameLayout）。


## 由主场景注入：语言按钮要显示当前可切换的目标语言。
var language_system: LanguageSystem
## 由主场景注入：拖地按钮的进度和声音开关状态。
var hygiene: HygieneSystem
var audio: AudioController


func _draw() -> void:
	_draw_button(GameLayout.OPEN_RECT, tr("开门营业"), GameState.shop["day_state"] == "preparing")
	# 拖地按钮：动作进行中显示进度
	var mop_label: String = tr("拖地") + " (+%d)" % int(30 + GameState.shop["upgrades"]["mop"] * 10)
	if hygiene.is_mopping():
		mop_label = tr("拖地中…")
	_draw_button(GameLayout.MOP_RECT, mop_label, GameState.shop["day_state"] == "serving")
	if hygiene.is_mopping():
		draw_rect(Rect2(GameLayout.MOP_RECT.position + Vector2(6, GameLayout.MOP_RECT.size.y - 10), Vector2((GameLayout.MOP_RECT.size.x - 12) * hygiene.mop_progress(), 5)), Color(0.4, 0.8, 1.0, 0.9))
	# 台风天二选一：开门搏一把（默认） vs 台风歇业保库存
	var typhoon_day: bool = GameState.shop["day_state"] == "preparing" and GameState.weather_id == "typhoon"
	_draw_button(GameLayout.CLOSE_RECT, tr("台风歇业") if typhoon_day else tr("提前打烊"), GameState.shop["day_state"] == "serving" or typhoon_day)
	_draw_button(GameLayout.RESET_RECT, tr("重置进度"), true)
	_draw_button(GameLayout.LANG_RECT, "EN" if not language_system.is_en() else "中文", true)
	_draw_button(GameLayout.STYLE_RECT, "像素" if GameLayout.use_sprites else "代码", true)
	_draw_button(GameLayout.SOUND_RECT, tr("声音 开") if audio.is_enabled() else tr("声音 关"), true)
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
	var c := Color(0.6, 0.45, 0.2) if enabled else Color(0.42, 0.42, 0.45)
	draw_rect(rect, c)
	draw_rect(rect, Color(0, 0, 0, 0.3), false, 2.0)
	draw_string(font, rect.position + Vector2(10, rect.size.y - 14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)


func _draw_upgrade_button(rect: Rect2, category: String) -> void:
	var info: Dictionary = Catalog.get_upgrades()[category]
	var level: int = GameState.shop["upgrades"][category]
	var enabled: bool = level < info["costs"].size() and GameState.shop["money"] >= info["costs"][level]
	var c := Color(0.33, 0.5, 0.36) if enabled else Color(0.42, 0.42, 0.45)
	draw_rect(rect, c)
	draw_rect(rect, Color(0, 0, 0, 0.3), false, 2.0)
	var label: String
	if level >= info["costs"].size():
		label = tr("%s MAX") % tr(info["name"])
	else:
		label = tr("%s Lv%d→%d ¥%d") % [tr(info["name"]), level, level + 1, info["costs"][level]]
	draw_string(font, rect.position + Vector2(10, rect.size.y - 14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
