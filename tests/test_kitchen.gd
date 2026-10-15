extends SceneTree
## 厨房工位系统（v2）单元测试。
## 运行：godot --headless --script res://tests/test_kitchen.gd

var _failed: int = 0


func _initialize() -> void:
	var KitchenSystemClass = load("res://scripts/systems/kitchen_system.gd")
	var HygieneSystemClass = load("res://scripts/systems/hygiene_system.gd")
	var GS = root.get_node("GameState")  # --script 模式拿不到自动加载全局名，动态取
	if GS == null:
		print("  FAIL: GameState autoload 不可用")
		quit(1)
		return
	var ks = KitchenSystemClass.new()
	ks.setup()
	GS.shop["day_state"] = "serving"
	GS.equipment_broken_ticks = 0
	GS.customers.clear()

	# 构造客人：果汁 = 切水果(prep 3s) → 榨汁(stove 4s)
	var c: Dictionary = {
		"id": 1, "name": "客人", "recipe_id": "juice", "recipe_name": "果汁",
		"patience": 100.0, "patience_max": 100.0, "state": "being_served",
		"make_progress": 0, "cook": {"station_id": -1, "phase": "queued"},
		"regular_id": "", "is_critic": false, "celebrating": false,
	}
	GS.customers.append(c)

	# 用例 1：点菜 → 上备菜台（station 0）
	_check(ks.tap_dish(1), "点菜能派上备菜台")
	_check(ks.stations[0]["customer_id"] == 1 and c["cook"]["phase"] == "cooking", "备菜台被占用且状态为 cooking")

	# 用例 2：备菜 3 秒自动完成，等待取走
	for i in range(35):
		ks._process(0.1)
	_check(c["cook"]["phase"] == "done", "备菜完成后等待取走")
	_check(ks.stations[0]["burn_timer"] == 0.0, "备菜台没有糊锅倒计时")

	# 用例 3：取走 → 进入下一步
	ks.tap_dish(1)
	_check(c["make_progress"] == 1 and c["cook"]["phase"] == "queued", "取走后进入下一步等待")

	# 用例 4：派上灶台 A → 烹饪完成 → 开始糊锅倒计时
	_check(ks.tap_dish(1), "能派上灶台")
	_check(ks.stations[1]["customer_id"] == 1, "灶台 A 开始烹饪")
	for i in range(45):
		ks._process(0.1)
	_check(c["cook"]["phase"] == "done" and ks.stations[1]["burn_timer"] > 0.0, "灶台完成后进入糊锅倒计时")

	# 用例 5：倒计时结束 → 糊锅 + 灶台被清理占用
	for i in range(85):
		ks._process(0.1)
	_check(c["cook"]["phase"] == "burnt", "宽限期后糊锅")
	_check(ks.stations[1]["phase"] == "blocked" and ks.stations[1]["timer"] > 0.0, "糊锅后台面被清理占用")

	# 用例 6：清理结束工位释放
	for i in range(35):
		ks._process(0.1)
	_check(ks.stations[1]["phase"] == "", "清理结束工位恢复空闲")

	# 用例 7：拖地是有成本的动作（3 秒占用，期间计时）
	var hy = HygieneSystemClass.new()
	GS.shop["hygiene"] = 50.0
	_check(hy.start_mop(), "能开始拖地")
	_check(hy.is_mopping(), "拖地占用双手")
	_check(not hy.start_mop(), "拖地中不能重复开始")
	for i in range(15):
		hy._process(0.3)
	_check(not hy.is_mopping(), "3 秒后拖地完成")
	_check(GS.shop["hygiene"] > 50.0, "拖完地卫生恢复")

	if _failed == 0:
		print("PASS: kitchen 全部用例通过")
	quit(1 if _failed > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: " + msg)
	else:
		_failed += 1
		print("  FAIL: " + msg)
