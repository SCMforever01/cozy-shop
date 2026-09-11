class_name WeatherSystem
extends System
## 天气系统：每天随机天气 + 明日天气预报。
## 通过 GameState.weather_modifiers 影响客流/卫生/环境；预报让玩家能提前决策（如台风歇业）。


func setup() -> void:
	EventBus.subscribe("clock.day_started", _on_day_started)


func teardown() -> void:
	EventBus.unsubscribe("clock.day_started", _on_day_started)


func _on_day_started(_day) -> void:
	# 昨天预报的天气就是今天；没有预报（第一天）则随机
	if GameState.forecast_weather_id == "":
		GameState.weather_id = _roll_weather()
	else:
		GameState.weather_id = GameState.forecast_weather_id
	# 滚动明天的预报
	GameState.forecast_weather_id = _roll_weather()
	_apply_weather(GameState.weather_id)


func _apply_weather(id: String) -> void:
	var weather: Dictionary = Catalog.get_weather()
	var w: WeatherType = weather[id]
	GameState.weather_id = id
	GameState.weather_modifiers = {
		"traffic": w.customer_traffic_modifier,
		"hygiene_decay": w.hygiene_decay_modifier,
		"environment": w.environment_modifier,
	}
	GameState.shop["environment"] = 100.0 + w.environment_modifier + GameState.shop["upgrades"]["decor"] * 10.0
	EventBus.emit("weather.changed", id)


## 加权随机天气：晴 45% / 阴 20% / 雨 15% / 暴雨 15% / 台风 5%
func _roll_weather() -> String:
	var r := randf()
	if r < 0.45:
		return "sunny"
	if r < 0.65:
		return "overcast"
	if r < 0.80:
		return "rain"
	if r < 0.95:
		return "storm"
	return "typhoon"
