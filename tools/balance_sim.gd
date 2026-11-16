extends SceneTree
## 平衡模拟器：bot 按「手速」自动经营 N 天，输出数值统计（JSON）。
## 手速 = 两次操作扫描之间的反应延迟（游戏秒）：1=手快 / 3=普通 / 6=手慢。
## 同一随机种子下不同参数的结果可直接对比，用于数值迭代的数据支撑。
##
## 运行：
##   godot --headless --script res://tools/balance_sim.gd -- --days=30 --delay=3 --speed=60 --seed=42 --tag=baseline
##
## 参数：days=模拟天数 delay=bot 反应延迟（游戏秒） speed=时间倍速
##       seed=随机种子 tag=输出标签

var days_target: int = 30
var bot_delay: float = 3.0
var speed: float = 60.0
var rand_seed: int = 42
var tag: String = "run"

var _bus: Node
var _gs: Node
var _gc: Node
var _systems: Dictionary = {}  # name -> System 实例
var _acc_game_sec: float = 0.0
var _day: int = 1
var _done: bool = false

var _stats := {
	"revenue_by_day": [],   # 每天净营收
	"arrivals": 0,
	"served": 0,
	"burnt": 0,
	"angry_left": 0,
	"no_seat_left": 0,
	"spoiled_total": 0,
	"spoiled_events": 0,
	"mop_count": 0,
	"reputation_end": 0,
}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--days="):
			days_target = int(arg.get_slice("=", 1))
		elif arg.begins_with("--delay="):
			bot_delay = float(arg.get_slice("=", 1))
		elif arg.begins_with("--speed="):
			speed = float(arg.get_slice("=", 1))
		elif arg.begins_with("--seed="):
			rand_seed = int(arg.get_slice("=", 1))
		elif arg.begins_with("--tag="):
			tag = arg.get_slice("=", 1)
	seed(rand_seed)

	_bus = root.get_node("EventBus")
	_gs = root.get_node("GameState")
	_gc = root.get_node("GameClock")
	var sm := root.get_node("SystemManager")
	# 注册玩法系统（不注册 save/language：模拟不碰存档、不需要翻译）
	for name in ["shop_system", "weather_system", "hygiene_system", "customer_system",
			"kitchen_system", "event_system", "season_system"]:
		var s = load("res://scripts/systems/%s.gd" % name).new()
		_systems[name] = s
		sm.register(s)

	_bus.subscribe("day.summary", func(p):
		_stats["revenue_by_day"].append(p["earned"])
		_stats["reputation_end"] = p["reputation"]
		if _stats["revenue_by_day"].size() >= days_target:
			_finish())
	_bus.subscribe("customer.served", func(_p): _stats["served"] += 1)
	_bus.subscribe("customer.entered", func(_p): _stats["arrivals"] += 1)
	_bus.subscribe("kitchen.burnt", func(_p): _stats["burnt"] += 1)
	_bus.subscribe("customer.left_angry", func(_p): _stats["angry_left"] += 1)
	_bus.subscribe("customer.left_no_seat", func(_p): _stats["no_seat_left"] += 1)
	_bus.subscribe("ingredients.spoiled", func(p):
		_stats["spoiled_events"] += 1
		_stats["spoiled_total"] += int(p["amount"]))
	_bus.subscribe("hygiene.mop_started", func(_p): _stats["mop_count"] += 1)
	_bus.subscribe("clock.day_started", func(d): _day = int(d))

	_gc.speed_multiplier = speed
	_bus.emit("clock.day_started", _gc.day)
	print("[sim] tag=%s days=%d delay=%.1f speed=%.0f seed=%d" % [tag, days_target, bot_delay, speed, rand_seed])


func _process(delta: float) -> bool:
	if _done:
		return false
	# 真实秒 -> 游戏秒（与系统内计时同一口径）
	_acc_game_sec += delta * speed
	while _acc_game_sec >= bot_delay:
		_acc_game_sec -= bot_delay
		_bot_sweep()
	return false


## 一轮操作扫描（= 玩家抬头看一眼店里能点完的所有事）。
func _bot_sweep() -> void:
	if _gs.shop["ingredients"] < 10 and _gs.shop["money"] >= 35:
		_buy(15, 35)
	if _gs.shop["day_state"] == "preparing":
		_buy(15, 35)
		_gs.shop["day_state"] = "serving"
	if _gs.shop["day_state"] != "serving":
		return
	if _gs.shop["hygiene"] < 40.0:
		_mop()
	for seat in _gs.seats:
		if seat["dirty"]:
			_clean(seat["id"])
	for c in _gs.customers.duplicate():
		match c["state"]:
			"waiting":
				_take_order(c["id"])
			"being_served":
				_tap_dish(c["id"])
			"ready":
				_serve(c["id"])


func _buy(amount: int, cost: int) -> void:
	_systems["shop_system"].buy_ingredients(amount, cost)


func _mop() -> void:
	_systems["hygiene_system"].start_mop()


func _clean(seat_id: int) -> void:
	_systems["customer_system"].clean_seat(seat_id)


func _take_order(id: int) -> void:
	_systems["customer_system"].take_order(id)


func _tap_dish(id: int) -> void:
	_systems["kitchen_system"].tap_dish(id)


func _serve(id: int) -> void:
	_systems["customer_system"].serve(id)


func _finish() -> void:
	_done = true
	var rev: Array = _stats["revenue_by_day"]
	var total := 0
	for v in rev:
		total += v
	_stats["revenue_avg"] = int(float(total) / maxf(rev.size(), 1))
	print("[sim] RESULT tag=%s %s" % [tag, JSON.stringify(_stats)])
	quit(0)
