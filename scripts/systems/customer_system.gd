class_name CustomerSystem
extends System
## 顾客系统：生成、耐心衰减、满意度、熟客关系、评论家。
## 这是「多线程心流」和「情感羁绊」两根乐趣支柱的实现。


## 每游戏分钟生成顾客的基础概率（受天气客流系数影响）。
const SPAWN_PROB_PER_MINUTE: float = 0.22
## 每游戏分钟耐心衰减量（受卫生惩罚放大）。
const PATIENCE_DECAY_PER_MINUTE: float = 3.0

var _next_id: int = 0
var _spawned_today: Dictionary = {}  # regular_id -> bool


func setup() -> void:
	EventBus.subscribe("clock.tick", _on_tick)
	EventBus.subscribe("clock.day_started", _on_day_started)
	EventBus.subscribe("event.food_critic", _on_food_critic)
	EventBus.subscribe("event.rush_hour", _on_rush_hour)


func teardown() -> void:
	EventBus.unsubscribe("clock.tick", _on_tick)
	EventBus.unsubscribe("clock.day_started", _on_day_started)
	EventBus.unsubscribe("event.food_critic", _on_food_critic)
	EventBus.unsubscribe("event.rush_hour", _on_rush_hour)


func _on_day_started(_day) -> void:
	_spawned_today.clear()
	GameState.customers.clear()
	# 熟客缓慢恢复（可挽回：不再犯错，关系慢慢回暖）
	for r in GameState.regulars:
		if r["relationship"] < 0:
			r["relationship"] += 1
		if r["relationship"] > -2:
			r["lost"] = false


func _on_tick(_minute) -> void:
	if GameState.shop["day_state"] != "serving":
		return
	_try_spawn()
	_decay_patience()


# ---------- 生成 ----------

func _try_spawn() -> void:
	var traffic: float = GameState.weather_modifiers["traffic"]
	var day_factor: float = minf(1.0 + (GameClock.day - 1) * 0.04, 1.8)
	if randf() < SPAWN_PROB_PER_MINUTE * traffic * day_factor:
		_spawn_customer(_random_recipe(), "客人", "")

	# 熟客：每天至多一次，关系越好越常来
	for r in GameState.regulars:
		if _spawned_today.get(r["id"], false) or r["lost"]:
			continue
		var rel: int = r["relationship"]
		var prob: float = 0.10 + 0.05 * maxi(rel, 0)
		if rel < 0:
			prob = 0.03
		if randf() < prob:
			_spawned_today[r["id"]] = true
			_spawn_customer(Catalog.get_recipe_by_id(r["favorite"]), r["name"], r["id"])


func _random_recipe() -> Recipe:
	var recipes: Array = Catalog.get_unlocked_recipes(GameState.shop["reputation"])
	return recipes[randi() % recipes.size()]


func _spawn_customer(recipe: Recipe, name: String, regular_id: String) -> void:
	var patience_base: float = 140.0 if regular_id != "" else 100.0
	var customer: Dictionary = {
		"id": _next_id,
		"name": name,
		"recipe_id": recipe.id,
		"recipe_name": recipe.display_name,
		"patience": patience_base,
		"patience_max": patience_base,
		"state": "waiting",
		"make_progress": 0,
		"regular_id": regular_id,
		"is_critic": false,
	}
	_next_id += 1
	GameState.customers.append(customer)
	EventBus.emit("customer.entered", {"name": name, "recipe_name": recipe.display_name})


func _on_food_critic(_p) -> void:
	_spawn_critic()


func _on_rush_hour(_p) -> void:
	for i in range(3):
		_spawn_customer(_random_recipe(), "客人", "")


func _spawn_critic() -> void:
	var recipe: Recipe = _random_recipe()
	var customer: Dictionary = {
		"id": _next_id,
		"name": "美食评论家",
		"recipe_id": recipe.id,
		"recipe_name": recipe.display_name,
		"patience": 120.0,
		"patience_max": 120.0,
		"state": "waiting",
		"make_progress": 0,
		"regular_id": "",
		"is_critic": true,
	}
	_next_id += 1
	GameState.customers.append(customer)
	EventBus.emit("customer.entered", {"name": "美食评论家", "recipe_name": recipe.display_name})


# ---------- 耐心 ----------

func _decay_patience() -> void:
	var penalty: float = _hygiene_penalty()
	for c in GameState.customers.duplicate():
		c["patience"] -= PATIENCE_DECAY_PER_MINUTE * penalty
		if c["patience"] <= 0.0:
			_angry_leave(c)


func _hygiene_penalty() -> float:
	var hygiene: float = GameState.shop["hygiene"]
	if hygiene < 40.0:
		return 2.0
	if hygiene < 70.0:
		return 1.5
	return 1.0


func _angry_leave(c: Dictionary) -> void:
	GameState.customers.erase(c)
	GameState.shop["reputation"] -= 1
	if c["regular_id"] != "":
		var r: Dictionary = _find_regular(c["regular_id"])
		if not r.is_empty():
			r["relationship"] -= 1
			if r["relationship"] <= -2:
				r["lost"] = true
				EventBus.emit("regular.lost", {"name": r["name"]})
	EventBus.emit("customer.left_angry", {"name": c["name"]})


# ---------- 制作流程 ----------

func take_order(customer_id: int) -> void:
	var c: Dictionary = _find(customer_id)
	if c.is_empty() or c["state"] != "waiting":
		return
	c["state"] = "being_served"


func make_step(customer_id: int) -> void:
	if GameState.equipment_broken_ticks > 0:
		return
	var c: Dictionary = _find(customer_id)
	if c.is_empty() or c["state"] != "being_served":
		return
	var recipe: Recipe = Catalog.get_recipe_by_id(c["recipe_id"])
	c["make_progress"] += 1
	if c["make_progress"] >= recipe.steps.size():
		c["state"] = "ready"


func serve(customer_id: int) -> void:
	var c: Dictionary = _find(customer_id)
	if c.is_empty() or c["state"] != "ready":
		return
	var recipe: Recipe = Catalog.get_recipe_by_id(c["recipe_id"])
	var patience_ratio: float = c["patience"] / c["patience_max"]
	var satisfaction: float = calc_satisfaction(patience_ratio, GameState.shop["environment"], GameState.shop["hygiene"])
	var tip: int = int(recipe.price * satisfaction)
	var earned: int = recipe.price + tip
	GameState.shop["money"] += earned
	if c.get("is_critic", false):
		if satisfaction >= 0.7:
			GameState.shop["reputation"] += 3
		else:
			GameState.shop["reputation"] -= 1
	else:
		GameState.shop["reputation"] += 1

	if c["regular_id"] != "":
		var r: Dictionary = _find_regular(c["regular_id"])
		if not r.is_empty():
			r["visits"] += 1
			if satisfaction >= 0.6:
				r["relationship"] += 1
			r["relationship"] = clampi(r["relationship"], -3, 5)
			if r["lost"]:
				r["lost"] = false

	GameState.customers.erase(c)
	EventBus.emit("customer.served", {"name": c["name"], "earned": earned})


func _find(customer_id: int) -> Dictionary:
	for c in GameState.customers:
		if c["id"] == customer_id:
			return c
	return {}


func _find_regular(regular_id: String) -> Dictionary:
	for r in GameState.regulars:
		if r["id"] == regular_id:
			return r
	return {}


## 满意度纯函数：便于单测。
static func calc_satisfaction(patience_ratio: float, environment: float, hygiene: float) -> float:
	var s: float = 0.7 * patience_ratio
	s += 0.15 * (hygiene / 100.0)
	s += 0.15 * (environment / 100.0)
	return clampf(s, 0.0, 1.0)
