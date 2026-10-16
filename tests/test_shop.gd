extends SceneTree
## P3 决策感：采购取舍（囤货/过期）与升级取舍（等级上限/座位扩建）单元测试。
## 运行：godot --headless --script res://tests/test_shop.gd

var _failed: int = 0


func _initialize() -> void:
	var SS = load("res://scripts/systems/shop_system.gd")
	var GS = root.get_node("GameState")
	if GS == null:
		print("  FAIL: GameState autoload 不可用")
		quit(1)
		return
	var ss = SS.new()
	ss.setup()
	GS.shop["day_state"] = "preparing"
	GS.shop["money"] = 100
	GS.shop["ingredients"] = 0
	GS.shop["skip_spoilage"] = false

	# 用例 1：采购小份 / 囤货大份 / 余额不足不买
	ss.buy_ingredients(5, 15)
	_check(GS.shop["ingredients"] == 5 and GS.shop["money"] == 85, "小份采购 +5 ¥15")
	ss.buy_ingredients(15, 35)
	_check(GS.shop["ingredients"] == 20 and GS.shop["money"] == 50, "囤货大份 +15 ¥35")
	ss.buy_ingredients(15, 35)
	_check(GS.shop["ingredients"] == 35 and GS.shop["money"] == 15, "余额够时继续囤货")
	ss.buy_ingredients(15, 35)
	_check(GS.shop["ingredients"] == 35 and GS.shop["money"] == 15, "余额不足不采购")

	# 用例 2：当天结束食材过期 20%
	ss._on_day_ended(1)
	_check(GS.shop["ingredients"] == 28, "食材过期损耗 20%（35→28）")

	# 用例 3：台风歇业豁免过期（保库存）
	GS.shop["skip_spoilage"] = true
	ss._on_day_ended(2)
	_check(GS.shop["ingredients"] == 28, "歇业当天食材不过期")
	_check(not GS.shop["skip_spoilage"], "豁免标记已清除")

	# 用例 4：升级等级以 costs 长度为上限；座位扩建生效
	GS.shop["money"] = 1000
	ss.buy_upgrade("seat")
	_check(GS.shop["upgrades"]["seat"] == 1 and GS.seat_capacity() == 4, "座位扩建后 4 桌")
	ss.buy_upgrade("seat")
	_check(GS.shop["upgrades"]["seat"] == 1, "座位扩建只有一级")

	# 用例 5：快灶台 2 级封顶
	ss.buy_upgrade("stove")
	ss.buy_upgrade("stove")
	ss.buy_upgrade("stove")
	_check(GS.shop["upgrades"]["stove"] == 2, "快灶台 2 级封顶")

	if _failed == 0:
		print("PASS: shop 全部用例通过")
	quit(1 if _failed > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: " + msg)
	else:
		_failed += 1
		print("  FAIL: " + msg)
