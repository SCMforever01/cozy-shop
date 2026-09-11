class_name System
extends Node
## 系统基类：所有机制的父类。
##
## 生命周期约定（子类覆写这些方法，不要覆写 _ready / _exit_tree）：
##   setup()     —— 注册后执行一次，在这里订阅事件
##   _process()  —— 每帧更新（Godot 内置，可选）
##   teardown()  —— 注销前清理，在这里取消订阅


func setup() -> void:
	pass


func teardown() -> void:
	pass
