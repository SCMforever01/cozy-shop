class_name SeasonSystem
extends System
## 季节系统：每 7 天轮换一个季节（春夏秋冬），应季菜品更受欢迎。


func setup() -> void:
	EventBus.subscribe("clock.day_started", _on_day_started)


func teardown() -> void:
	EventBus.unsubscribe("clock.day_started", _on_day_started)


func _on_day_started(_day) -> void:
	var season: String = Catalog.get_season_for_day(GameClock.day)
	var changed: bool = season != GameState.current_season
	GameState.current_season = season
	if changed:
		EventBus.emit("season.changed", season)
