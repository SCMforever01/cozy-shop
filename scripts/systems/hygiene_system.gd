class_name HygieneSystem
extends System
## 卫生系统：营业中脏污累积，玩家拖地恢复。
## 这是「决策取舍」支柱的实现（忙时要不要抽空拖地）。


const DECAY_PER_MINUTE: float = 1.8
const MOP_RESTORE: float = 30.0


func setup() -> void:
	EventBus.subscribe("clock.tick", _on_tick)


func teardown() -> void:
	EventBus.unsubscribe("clock.tick", _on_tick)


func _on_tick(_minute) -> void:
	if GameState.shop["day_state"] != "serving":
		return
	var decay: float = DECAY_PER_MINUTE * GameState.weather_modifiers["hygiene_decay"]
	GameState.shop["hygiene"] = maxf(GameState.shop["hygiene"] - decay, 0.0)


func mop() -> void:
	GameState.shop["hygiene"] = minf(GameState.shop["hygiene"] + MOP_RESTORE, 100.0)
