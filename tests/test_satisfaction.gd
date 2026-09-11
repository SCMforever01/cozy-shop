extends SceneTree
## calc_satisfaction 纯函数单元测试。
## 运行：godot --headless --script res://tests/test_satisfaction.gd

var _failed: int = 0


func _initialize() -> void:
	var cs = load("res://scripts/systems/customer_system.gd")

	# 满耐心 + 好环境 + 好卫生 => 高满意度
	var s_high: float = cs.calc_satisfaction(1.0, 100.0, 100.0)
	_check(s_high > 0.9, "满耐心好环境 => 高满意度（实际 %.3f）" % s_high)

	# 零耐心 => 低满意度
	var s_low: float = cs.calc_satisfaction(0.0, 100.0, 100.0)
	_check(s_low < 0.6, "零耐心 => 低满意度（实际 %.3f）" % s_low)

	# 环境差拖低满意度
	var s_env: float = cs.calc_satisfaction(1.0, 0.0, 100.0)
	_check(s_env < s_high, "环境差拖低满意度")

	# 卫生差拖低满意度
	var s_hyg: float = cs.calc_satisfaction(1.0, 100.0, 0.0)
	_check(s_hyg < s_high, "卫生差拖低满意度")

	# 范围约束 0~1
	var s_clamp: float = cs.calc_satisfaction(1.0, 500.0, 500.0)
	_check(s_clamp <= 1.0 and s_clamp >= 0.0, "满意度被约束在 0~1")

	if _failed == 0:
		print("PASS: calc_satisfaction 全部用例通过")
	else:
		print("FAIL: %d 个用例失败" % _failed)
	quit(_failed)


func _check(cond: bool, name: String) -> void:
	if cond:
		print("  PASS: %s" % name)
	else:
		_failed += 1
		print("  FAIL: %s" % name)
