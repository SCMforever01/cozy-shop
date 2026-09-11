extends SceneTree
## EventBus 独立单元测试。
## 运行：godot --headless --script res://tests/test_event_bus.gd
##
## 注意：GDScript lambda 按值捕获，计数要用 Array/Dictionary 这类引用类型。

var _failed: int = 0


func _initialize() -> void:
	var bus = load("res://autoload/event_bus.gd").new()

	# 用例 1：订阅后能收到广播
	var received: Array = []
	var cb = func(p): received.append(p)
	bus.subscribe("test.event", cb)
	bus.emit("test.event", 42)
	_check(received.size() == 1 and received[0] == 42, "订阅后收到广播")

	# 用例 2：取消订阅后不再收到
	bus.unsubscribe("test.event", cb)
	bus.emit("test.event", 99)
	_check(received.size() == 1, "取消订阅后不再收到")

	# 用例 3：无监听者的事件安全（不报错）
	bus.emit("no.listeners", null)
	_check(true, "无监听者事件安全")

	# 用例 4：多个监听者都收到（用 Array 计数，因 lambda 按值捕获）
	var counters: Array = [0, 0]
	bus.subscribe("multi", func(_p): counters[0] += 1)
	bus.subscribe("multi", func(_p): counters[1] += 1)
	bus.emit("multi", null)
	_check(counters[0] == 1 and counters[1] == 1, "多监听者都收到")

	if _failed == 0:
		print("PASS: EventBus 全部用例通过")
	else:
		print("FAIL: %d 个用例失败" % _failed)

	bus.free()
	quit(_failed)


func _check(cond: bool, name: String) -> void:
	if cond:
		print("  PASS: %s" % name)
	else:
		_failed += 1
		print("  FAIL: %s" % name)
