extends SceneTree
## 平衡模拟器：bot 按「手速」自动经营 N 天，输出数值统计（JSON）。
## 手速 = 两次操作扫描之间的反应延迟（游戏秒）：1=手快 / 3=普通 / 6=手慢。
## 同一随机种子下不同参数的结果可直接对比，用于数值迭代的数据支撑。
##
## 运行：
##   godot --headless --script res://tools/balance_sim.gd -- --days=30 --delay=3 --speed=60 --seed=42 --tag=baseline --policy=seat-first
##
## 参数：days=模拟天数 delay=bot 反应延迟（游戏秒） speed=时间倍速
##       seed=随机种子 tag=输出标签
##       policy=升级策略 none / seat-first（先座位扩建后买最便宜）/ hoard-seat（攒钱先买座位，隔离定价因素）
##       actions=每轮扫描最多处理几件事（注意力容量，限制吞吐）
##       miss=每轮对「已做好待取走」的锅看漏的概率（注意力被占住 → 可测糊锅率）

var days_target: int = 30
var bot_delay: float = 3.0
var speed: float = 60.0
var rand_seed: int = 42
var tag: String = "run"
var policy: String = "none"
var max_actions: int = 999
var miss_prob: float = 0.0

var _bus: Node
var _gs: Node
var _gc: Node
var _catalog = load("res://data/catalog.gd")
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
	"upgrades_bought": [],   # [day, category]
	"gross_income": 0,      # 服务毛收入（revenue_by_day 是含采购/升级的净额）
	"money_end": 0,
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
		elif arg.begins_with("--policy="):
			policy = arg.get_slice("=", 1)
		elif arg.begins_with("--actions="):
			max_actions = int(arg.get_slice("=", 1))
		elif arg.begins_with("--miss="):
			miss_prob = float(arg.get_slice("=", 1))
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
	_bus.subscribe("customer.served", func(p):
		_stats["served"] += 1
		_stats["gross_income"] += int(p["earned"]))
	_bus.subscribe("customer.entered", func(_p): _stats["arrivals"] += 1)
	_bus.subscribe("kitchen.burnt", func(_p): _stats["burnt"] += 1)
	_bus.subscribe("customer.left_angry", func(_p): _stats["angry_left"] += 1)
	_bus.subscribe("customer.left_no_seat", func(_p): _stats["no_seat_left"] += 1)
	_bus.subscribe("ingredients.spoiled", func(p):
		_stats["spoiled_events"] += 1
		_stats["spoiled_total"] += int(p["amount"]))
	_bus.subscribe("hygiene.mop_started", func(_p): _stats["mop_count"] += 1)
	_bus.subscribe("upgrade.bought", func(p): _stats["upgrades_bought"].append([_day, p["category"]]))
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
	if policy != "none":
		_buy_upgrades()
	if _gs.shop["day_state"] == "preparing":
		_buy(15, 35)
		_gs.shop["day_state"] = "serving"
	if _gs.shop["day_state"] != "serving":
		return
	if _gs.shop["hygiene"] < 40.0:
		_mop()
	var budget := max_actions
	# 优先级即玩家分诊顺序：收桌 > 上菜 > 取走（防糊锅）> 接单 > 派工位
	for seat in _gs.seats:
		if budget <= 0:
			return
		if seat["dirty"]:
			_clean(seat["id"])
			budget -= 1
	for c in _gs.customers.duplicate():
		if budget <= 0:
			return
		if c["state"] == "ready":
			_serve(c["id"])
			budget -= 1
	for c in _gs.customers.duplicate():
		if budget <= 0:
			return
		if c["state"] == "being_served" and c["cook"]["phase"] == "done":
			if miss_prob > 0.0 and randf() < miss_prob:
				continue  # 看漏了这口锅（注意力被别处占住）
			_tap_dish(c["id"])  # 取走（灶台在烧）
			budget -= 1
	for c in _gs.customers.duplicate():
		if budget <= 0:
			return
		if c["state"] == "waiting":
			_take_order(c["id"])
			budget -= 1
	for c in _gs.customers.duplicate():
		if budget <= 0:
			return
		if c["state"] == "being_served" and c["cook"]["phase"] == "queued":
			_tap_dish(c["id"])  # 派工位
			budget -= 1


func _buy(amount: int, cost: int) -> void:
	_systems["shop_system"].buy_ingredients(amount, cost)


## 升级策略（policy）：
##   seat-first —— 先买座位扩建（门口走人是最大漏损），之后买「买得起的最便宜」
##   none       —— 不买升级（基线）
## 统一保留 ¥100 现金流买食材。
func _buy_upgrades() -> void:
	var shop: Dictionary = _gs.shop
	var up: Dictionary = shop["upgrades"]
	if up["seat"] == 0:
		if policy == "hoard-seat" and shop["money"] - _catalog.get_upgrades()["seat"]["costs"][0] >= 35:
			_systems["shop_system"].buy_upgrade("seat")
			return
		if policy == "seat-first" and shop["money"] >= 400:
			_systems["shop_system"].buy_upgrade("seat")
			return
		if policy == "hoard-seat":
			return  # 攒钱期间不买别的
	var best := ""
	var best_cost := 1 << 30
	for k in up:
		var costs: Array = _catalog.get_upgrades()[k]["costs"]
		var lvl: int = up[k]
		if lvl < costs.size() and costs[lvl] < best_cost and shop["money"] - costs[lvl] >= 100:
			best = k
			best_cost = costs[lvl]
	if best != "":
		_systems["shop_system"].buy_upgrade(best)


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
	_stats["money_end"] = _gs.shop["money"]
	print("[sim] RESULT tag=%s %s" % [tag, JSON.stringify(_stats)])
	quit(0)
