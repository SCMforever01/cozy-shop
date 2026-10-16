class_name KitchenSystem
extends System
## 厨房工位系统（v2 压力感核心）：做菜不再是点击推进，而是工位自动计时。
## - 点一下菜 = 让它进入下一步（上工位 / 取走 / 上菜），但每步花真实时间
## - 灶台步骤做完有宽限期，不取走就糊锅：食材报废 + 客人气走 + 灶台被清理占用
## - 工位并行 = 「先救哪口锅」的取舍

const BURN_GRACE := 10.0    ## 灶台做完不取走的糊锅宽限（秒）
const CLEAN_TIME := 3.0     ## 糊锅后台面清理占用（秒）

## 工位表：kind 与菜谱步骤的 station 对应
const STATIONS := [
	{"id": 0, "kind": "prep", "name": "备菜台"},
	{"id": 1, "kind": "stove", "name": "灶台A"},
	{"id": 2, "kind": "stove", "name": "灶台B"},
	{"id": 3, "kind": "plate", "name": "装盘台"},
]

## 每个工位的实时状态
## {id, kind, name, customer_id: int(-1=空), phase: ""|"cooking"|"done"|"blocked", timer, burn_timer}
var stations: Array = []


func setup() -> void:
	_reset_stations()
	EventBus.subscribe("clock.day_started", _on_day_started)
	EventBus.subscribe("customer.left_angry", _on_customer_left)


func teardown() -> void:
	EventBus.unsubscribe("clock.day_started", _on_day_started)
	EventBus.unsubscribe("customer.left_angry", _on_customer_left)


func _on_day_started(_day) -> void:
	_reset_stations()


func _on_customer_left(p) -> void:
	# 客人中途离开（等不及/糊锅）时清空其占用的工位
	var cid: int = p.get("id", -1)
	for s in stations:
		if s["customer_id"] == cid:
			_free_station(s)


func _reset_stations() -> void:
	stations.clear()
	for def in STATIONS:
		stations.append({
			"id": def["id"], "kind": def["kind"], "name": def["name"],
			"customer_id": -1, "phase": "", "timer": 0.0, "burn_timer": 0.0,
		})


func _process(delta: float) -> void:
	if GameState.shop["day_state"] != "serving":
		return
	if GameState.equipment_broken_ticks > 0:
		return  # 设备故障：计时冻结（含糊锅倒计时，故障是惩罚不是灾难）
	for s in stations:
		match s["phase"]:
			"cooking":
				s["timer"] -= delta
				if s["timer"] <= 0.0:
					s["timer"] = 0.0
					s["phase"] = "done"
					var c := _find_customer(s["customer_id"])
					if not c.is_empty():
						c["cook"]["phase"] = "done"
					if s["kind"] == "stove":
						s["burn_timer"] = BURN_GRACE
			"done":
				if s["burn_timer"] > 0.0:
					s["burn_timer"] -= delta
					if s["burn_timer"] <= 0.0:
						_burn(s)
			"blocked":
				s["timer"] -= delta
				if s["timer"] <= 0.0:
					_free_station(s)


## 点空工位：把最前面等这类工位的菜自动派上来（少一次无意义点击）。
func tap_station(station_id: int) -> bool:
	var s: Dictionary = stations[station_id]
	if s["phase"] != "":
		return false
	for c in GameState.customers:
		if c["state"] == "being_served" and c["cook"]["phase"] == "queued":
			var recipe: Recipe = Catalog.get_recipe_by_id(c["recipe_id"])
			if recipe.steps[c["make_progress"]]["station"] == s["kind"]:
				return _dispatch(c)
	return false


## 点一下菜：等待中→上工位；做完了→取走进下一步；成品→上菜（由 customer_system.serve 处理）。
## 返回 true 表示本次点击推进了流程。
func tap_dish(customer_id: int) -> bool:
	var c := _find_customer(customer_id)
	if c.is_empty():
		return false
	if c["state"] != "being_served":
		return false
	var cook: Dictionary = c["cook"]
	match cook["phase"]:
		"queued":
			return _dispatch(c)
		"done":
			_pickup(c)
			return true
	return false


func _dispatch(c: Dictionary) -> bool:
	if GameState.equipment_broken_ticks > 0:
		EventBus.emit("kitchen.blocked", {"reason": "broken"})
		return false
	var recipe: Recipe = Catalog.get_recipe_by_id(c["recipe_id"])
	var step: Dictionary = recipe.steps[c["make_progress"]]
	for s in stations:
		if s["kind"] == step["station"] and s["phase"] == "":
			s["customer_id"] = c["id"]
			s["phase"] = "cooking"
			s["timer"] = step["sec"]
			s["burn_timer"] = 0.0
			c["cook"] = {"station_id": s["id"], "phase": "cooking"}
			return true
	EventBus.emit("kitchen.blocked", {"reason": "occupied"})
	return false


func _pickup(c: Dictionary) -> void:
	var cook: Dictionary = c["cook"]
	var s: Dictionary = stations[cook["station_id"]]
	_free_station(s)
	c["make_progress"] += 1
	var recipe: Recipe = Catalog.get_recipe_by_id(c["recipe_id"])
	if c["make_progress"] >= recipe.steps.size():
		c["cook"] = {"station_id": -1, "phase": "ready"}
		c["state"] = "ready"
		EventBus.emit("dish.ready", {"id": c["id"], "name": c["name"]})
	else:
		c["cook"] = {"station_id": -1, "phase": "queued"}
		EventBus.emit("dish.step_done", {"id": c["id"], "step": c["make_progress"]})


func _burn(s: Dictionary) -> void:
	var c := _find_customer(s["customer_id"])
	var cid: int = s["customer_id"]
	s["customer_id"] = -1
	s["phase"] = "blocked"
	s["timer"] = CLEAN_TIME
	s["burn_timer"] = 0.0
	if not c.is_empty():
		c["cook"] = {"station_id": -1, "phase": "burnt"}
	EventBus.emit("kitchen.burnt", {"id": cid})


func _free_station(s: Dictionary) -> void:
	s["customer_id"] = -1
	s["phase"] = ""
	s["timer"] = 0.0
	s["burn_timer"] = 0.0


func _find_customer(customer_id: int) -> Dictionary:
	for c in GameState.customers:
		if c["id"] == customer_id:
			return c
	return {}
