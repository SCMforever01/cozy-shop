extends Node
## 全局事件总线：系统之间零耦合通信的唯一通道。
##
## 用法：
##   订阅：EventBus.subscribe("weather.changed", _on_weather_changed)
##   广播：EventBus.emit("weather.changed", "rain")
##
## 约定：
##   - 事件名用点分命名（如 "customer.entered"），加新事件无需改动本文件。
##   - 监听者统一接收【一个】参数 payload（不需要时也请声明一个参数）。

# 事件名 -> Array[Callable]
var _listeners: Dictionary = {}


## 订阅某事件。listener 会以 payload 作为唯一参数被调用。
func subscribe(event_name: String, listener: Callable) -> void:
	if not _listeners.has(event_name):
		_listeners[event_name] = []
	var list: Array = _listeners[event_name]
	if not list.has(listener):
		list.append(listener)


## 取消订阅。
func unsubscribe(event_name: String, listener: Callable) -> void:
	if not _listeners.has(event_name):
		return
	_listeners[event_name].erase(listener)


## 广播事件。payload 可选，会传给每个监听者。
func emit(event_name: String, payload = null) -> void:
	if not _listeners.has(event_name):
		return
	# duplicate() 防止监听者在回调里增删监听者导致迭代异常
	for listener in _listeners[event_name].duplicate():
		listener.call(payload)
