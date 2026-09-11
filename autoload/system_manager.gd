extends Node
## 系统管理器：统一注册/注销系统，维护其生命周期。
##
## 加新机制 = 写一个 System 子类 + 调用 register()，不改已有代码。

var _systems: Array[System] = []


## 注册一个系统：加入场景树（启用 _process）并调用 setup()。
func register(system: System) -> void:
	if _systems.has(system):
		return
	_systems.append(system)
	add_child(system)
	system.setup()


## 注销一个系统。
func unregister(system: System) -> void:
	if not _systems.has(system):
		return
	system.teardown()
	remove_child(system)
	_systems.erase(system)


func get_systems() -> Array[System]:
	return _systems
