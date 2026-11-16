extends Node2D
## 主场景：装配层。
## 职责只有三件事——注册系统、组装 UI 视图、把点击路由到系统。
## 游戏逻辑在 scripts/systems/（只写 GameState），渲染在 scripts/ui/ 各视图，
## 布局几何在 GameLayout（绘制与命中检测共用一份）。


var _shop_system: ShopSystem
var _weather_system: WeatherSystem
var _hygiene_system: HygieneSystem
var _customer_system: CustomerSystem
var _kitchen_system: KitchenSystem
var _event_system: EventSystem
var _save_system: SaveSystem
var _season_system: SeasonSystem
var _language_system: LanguageSystem

var _controls_view: ControlsView
var _fx_view: FxView
var _tutorial_view: TutorialView
var _audio: AudioController


func _ready() -> void:
	# 像素素材统一最近邻缩放（防糊）
	texture_filter = TEXTURE_FILTER_NEAREST
	_register_systems()
	_build_views()

	var autoplay := "--autoplay" in OS.get_cmdline_user_args()
	if autoplay:
		# 演示/冒烟：整体 10 倍速（时钟与真实秒机制同步加速，见 GameClock.speed_multiplier）
		GameClock.speed_multiplier = 10.0
		var auto := AutoPlay.new()
		auto.shop_system = _shop_system
		auto.hygiene_system = _hygiene_system
		auto.customer_system = _customer_system
		auto.kitchen_system = _kitchen_system
		add_child(auto)

	# 读档（autoplay 测试模式跳过，保证从第 1 天开始）
	var loaded_day: int = 0 if autoplay else _save_system.load_game()
	EventBus.emit("clock.day_started", GameClock.day)
	if loaded_day > 0:
		_fx_view.spawn_floater(tr("已读档，继续第 %d 天") % loaded_day, Color(0.6, 0.8, 1.0))
	elif not autoplay:
		_tutorial_view.step = 0


func _register_systems() -> void:
	_shop_system = ShopSystem.new()
	_weather_system = WeatherSystem.new()
	_hygiene_system = HygieneSystem.new()
	_customer_system = CustomerSystem.new()
	_kitchen_system = KitchenSystem.new()
	_event_system = EventSystem.new()
	_save_system = SaveSystem.new()
	_season_system = SeasonSystem.new()
	_language_system = LanguageSystem.new()
	for s in [_shop_system, _weather_system, _hygiene_system, _customer_system, _kitchen_system,
			_event_system, _save_system, _season_system, _language_system]:
		SystemManager.register(s)


func _build_views() -> void:
	var shop_view := ShopView.new()
	var hud_view := HudView.new()
	var kitchen_view := KitchenView.new()
	_controls_view = ControlsView.new()
	_fx_view = FxView.new()
	_tutorial_view = TutorialView.new()
	_audio = AudioController.new()

	kitchen_view.kitchen = _kitchen_system
	_controls_view.language_system = _language_system
	_controls_view.hygiene = _hygiene_system
	_controls_view.audio = _audio
	_audio.kitchen = _kitchen_system

	# 绘制顺序 = 添加顺序：店铺 → HUD → 厨房 → 按钮 → 特效 → 引导遮罩（音频无渲染）
	for v in [shop_view, hud_view, kitchen_view, _controls_view, _fx_view, _tutorial_view, _audio]:
		add_child(v)


# ---------- 输入 ----------

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(event.position)


func _handle_click(pos: Vector2) -> void:
	_audio.play_sfx("tap", -10.0)

	# 新手引导是模态的，只响应引导按钮
	if _tutorial_view.is_active():
		if GameLayout.TUTORIAL_NEXT_RECT.has_point(pos):
			_tutorial_view.advance()
		elif GameLayout.TUTORIAL_SKIP_RECT.has_point(pos):
			_tutorial_view.skip()
		return

	# 全局按钮
	if GameLayout.RESET_RECT.has_point(pos):
		_on_reset()
		return
	if GameLayout.LANG_RECT.has_point(pos):
		_language_system.toggle()
		return
	if GameLayout.STYLE_RECT.has_point(pos):
		GameLayout.use_sprites = not GameLayout.use_sprites
		return
	if GameLayout.SOUND_RECT.has_point(pos):
		_audio.toggle()
		return

	# 经营按钮
	if GameState.shop["day_state"] != "closed" and GameLayout.BUY_INGREDIENTS_RECT.has_point(pos):
		_shop_system.buy_ingredients(5, 15)
		return
	if GameState.shop["day_state"] != "closed" and GameLayout.BUY_BULK_RECT.has_point(pos):
		_shop_system.buy_ingredients(15, 35)
		return
	if GameState.shop["day_state"] == "preparing":
		if GameLayout.UPGRADE_MOP_RECT.has_point(pos):
			_shop_system.buy_upgrade("mop")
			return
		if GameLayout.UPGRADE_STOVE_RECT.has_point(pos):
			_shop_system.buy_upgrade("stove")
			return
		if GameLayout.UPGRADE_SEAT_RECT.has_point(pos):
			_shop_system.buy_upgrade("seat")
			return
		if GameLayout.UPGRADE_INGREDIENT_RECT.has_point(pos):
			_shop_system.buy_upgrade("ingredient")
			return
		if GameLayout.UPGRADE_DECOR_RECT.has_point(pos):
			_shop_system.buy_upgrade("decor")
			return
	if GameLayout.OPEN_RECT.has_point(pos) and GameState.shop["day_state"] == "preparing":
		_shop_system.open_shop()
		return
	if GameLayout.MOP_RECT.has_point(pos) and GameState.shop["day_state"] == "serving":
		_hygiene_system.start_mop()
		return
	if GameLayout.CLOSE_RECT.has_point(pos) and GameState.shop["day_state"] == "serving":
		GameClock.end_day_now()
		return
	# 台风天二选一：歇业保库存（当天食材不过期，不白耗）
	if GameLayout.CLOSE_RECT.has_point(pos) and GameState.shop["day_state"] == "preparing" and GameState.weather_id == "typhoon":
		GameState.shop["skip_spoilage"] = true
		_fx_view.spawn_floater(tr("台风歇业，库存保住了"), Color(0.55, 0.75, 0.95))
		GameClock.end_day_now()
		return

	# 拖地占用双手：动作没做完不能做菜/接单（「锅要糊 vs 地上一摊」的取舍）
	if _hygiene_system.is_mopping():
		_fx_view.spawn_floater(tr("正在拖地…"), Color(0.55, 0.7, 0.9))
		return

	# 厨房工位：点卡片 = 派菜上工位 / 取走成品
	for i in range(_kitchen_system.stations.size() - 1, -1, -1):
		var s: Dictionary = _kitchen_system.stations[i]
		if GameLayout.station_hit_rect(i).has_point(pos):
			if s["customer_id"] >= 0:
				_kitchen_system.tap_dish(s["customer_id"])
			else:
				_kitchen_system.tap_station(s["id"])
			return

	# 待处理的菜：等工位的 / 做完待上菜的
	var waiting := GameLayout.waiting_dishes(GameState.customers)
	for i in range(waiting.size() - 1, -1, -1):
		var c = waiting[i]
		if GameLayout.waiting_hit_rect(i).has_point(pos):
			if c["state"] == "ready":
				_customer_system.serve(c["id"])
			else:
				_kitchen_system.tap_dish(c["id"])
			return

	# 脏桌：点桌子收掉脏盘（不收不能接待下一位）
	for i in range(GameState.seats.size()):
		var seat: Dictionary = GameState.seats[i]
		if seat["dirty"] and GameLayout.seat_hit_rect(i).has_point(pos):
			_customer_system.clean_seat(i)
			return

	# 客人：点击接单（门口等座的先占座，点不了单）
	for i in range(GameState.customers.size() - 1, -1, -1):
		var c = GameState.customers[i]
		if GameLayout.customer_hit_rect(GameState.customers, c).has_point(pos):
			if c.get("at_door", false):
				_fx_view.spawn_floater(tr("等座位中…"), Color(0.85, 0.75, 0.5))
			elif c["state"] == "waiting" and c["enter_t"] <= 0.0:
				_customer_system.take_order(c["id"])
			return


func _on_reset() -> void:
	_save_system.reset()
	EventBus.emit("clock.day_started", GameClock.day)
	_fx_view.spawn_floater(tr("进度已重置"), Color(0.8, 0.5, 0.5))
