class_name WeatherSystem
extends System
## 天气系统：每天随机天气，通过 GameState.weather_modifiers 影响客流/卫生/环境。


func setup() -> void:
	EventBus.subscribe("clock.day_started", _on_day_started)


func teardown() -> void:
	EventBus.unsubscribe("clock.day_started", _on_day_started)


func _on_day_started(_day) -> void:
	var weather: Dictionary = Catalog.get_weather()
	var id: String = _roll_weather()
	var w: WeatherType = weather[id]
	GameState.weather_id = id
	GameState.weather_modifiers = {
		"traffic": w.customer_traffic_modifier,
		"hygiene_decay": w.hygiene_decay_modifier,
		"environment": w.environment_modifier,
	}
	GameState.shop["environment"] = 100.0 + w.environment_modifier
	EventBus.emit("weather.changed", id)


## 加权随机天气：晴 50% / 阴 20% / 雨 15% / 暴雨 15%
func _roll_weather() -> String:
	var r := randf()
	if r < 0.50:
		return "sunny"
	if r < 0.70:
		return "overcast"
	if r < 0.85:
		return "rain"
	return "storm"
