class_name HygieneSystem
extends System
## 卫生系统（v2）：脏污累积看得见，拖地是有成本的动作。
## 这是「决策取舍」支柱的实现：生意正忙时「锅要糊 vs 地上一摊」只能救一个。
## 拖地占用双手 MOP_TIME 秒，期间做不了菜——不是白嫖按钮。

const DECAY_PER_MINUTE: float = 1.8
const MOP_BASE: float = 30.0
const MOP_TIME: float = 3.0   ## 拖地动作耗时（秒），升级拖把可缩短到 1 秒

var mopping_timer: float = 0.0


func setup() -> void:
	EventBus.subscribe("clock.tick", _on_tick)


func teardown() -> void:
	EventBus.unsubscribe("clock.tick", _on_tick)


func _on_tick(_minute) -> void:
	if GameState.shop["day_state"] != "serving":
		return
	var dirty: int = 0
	for s in GameState.seats:
		if s["dirty"]:
			dirty += 1
	var decay: float = DECAY_PER_MINUTE * GameState.weather_modifiers["hygiene_decay"] * (1.0 + 0.3 * dirty)
	GameState.shop["hygiene"] = maxf(GameState.shop["hygiene"] - decay, 0.0)


func _process(delta: float) -> void:
	if mopping_timer <= 0.0:
		return
	mopping_timer -= delta
	if mopping_timer <= 0.0:
		mopping_timer = 0.0
		_finish_mop()


## 开始拖地动作；返回 false = 正在拖或当前不能拖。
func start_mop() -> bool:
	if mopping_timer > 0.0:
		return false
	if GameState.shop["day_state"] != "serving":
		return false
	mopping_timer = mop_duration()
	EventBus.emit("hygiene.mop_started", {})
	return true


func is_mopping() -> bool:
	return mopping_timer > 0.0


## 拖地动作进度 0~1（按钮上画进度条用）。
func mop_progress() -> float:
	var total: float = mop_duration()
	return clampf(1.0 - mopping_timer / maxf(total, 0.01), 0.0, 1.0)


func mop_duration() -> float:
	return maxf(MOP_TIME - GameState.shop["upgrades"]["mop"] * 0.66, 1.0)


func _finish_mop() -> void:
	var restore: float = MOP_BASE + GameState.shop["upgrades"]["mop"] * 10.0
	GameState.shop["hygiene"] = minf(GameState.shop["hygiene"] + restore, 100.0)
	EventBus.emit("hygiene.mopped", {})


## 地面污渍数量（渲染用）：越脏越多，最多 8 处。
func dirt_spots() -> int:
	return clampi(int((100.0 - GameState.shop["hygiene"]) / 12.0), 0, 8)
