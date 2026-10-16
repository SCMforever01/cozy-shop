extends SceneTree
## 座位系统（v2 P2：落座/用餐/留盘/满座排队）单元测试。
## 运行：godot --headless --script res://tests/test_seats.gd

var _failed: int = 0


func _make_customer(id: int) -> Dictionary:
	return {
		"id": id, "name": "客人%d" % id, "recipe_id": "juice", "recipe_name": "果汁",
		"patience": 100.0, "patience_max": 100.0, "state": "waiting",
		"make_progress": 0, "cook": {"station_id": -1, "phase": ""},
		"regular_id": "", "is_critic": false, "celebrating": false,
		"seat_id": -1, "at_door": false, "enter_t": 0.0, "dine_timer": 0.0,
	}


func _initialize() -> void:
	var CS = load("res://scripts/systems/customer_system.gd")
	var GS = root.get_node("GameState")
	if GS == null:
		print("  FAIL: GameState autoload 不可用")
		quit(1)
		return
	var cs = CS.new()
	cs.setup()
	GS.shop["day_state"] = "serving"
	GS.customers.clear()
	for s in GS.seats:
		s["customer_id"] = -1
		s["dirty"] = false

	# 用例 1：前 3 人落座，第 4 人门口排队
	var c1 := _make_customer(1)
	var c2 := _make_customer(2)
	var c3 := _make_customer(3)
	var c4 := _make_customer(4)
	for c in [c1, c2, c3, c4]:
		GS.customers.append(c)
		cs._seat_or_queue(c)
	_check(c1["seat_id"] == 0 and c2["seat_id"] == 1 and c3["seat_id"] == 2, "前三位客人落座")
	_check(c4["at_door"] and c4["seat_id"] == -1, "满座时第四位在门口排队")

	# 用例 2：用餐结束留脏盘
	c1["state"] = "dining"
	c1["dine_timer"] = 0.5
	cs._process(0.6)
	_check(GS.seats[0]["dirty"], "用餐结束桌上留脏盘")
	_check(GS.seats[0]["customer_id"] == -1, "用餐结束座位释放")

	# 用例 3：脏桌不接待下一位（门口的补不进来）
	cs._process(0.2)
	_check(c4["at_door"], "脏桌未收，门口客人进不来")

	# 用例 4：收桌后门口客人自动补位
	cs.clean_seat(0)
	_check(not GS.seats[0]["dirty"], "收桌后桌子干净")
	_check(not c4["at_door"] and c4["seat_id"] == 0, "收桌后门口客人补位坐下")

	# 用例 5：门口等 10 秒没座就走人（小扣口碑）
	var c5 := _make_customer(5)
	c5["at_door"] = true
	c5["door_timer"] = 0.3
	GS.customers.append(c5)
	var rep_before: int = GS.shop["reputation"]
	cs._process(0.5)
	var still_here: bool = false
	for c in GS.customers:
		if c["id"] == 5:
			still_here = true
	_check(not still_here, "门口超时客人离开")
	_check(GS.shop["reputation"] == rep_before - 1, "没座位流失客人小扣口碑")

	if _failed == 0:
		print("PASS: seats 全部用例通过")
	quit(1 if _failed > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: " + msg)
	else:
		_failed += 1
		print("  FAIL: " + msg)
