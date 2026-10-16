class_name CustomerSystem
extends System
## 顾客系统：生成、耐心衰减、满意度、熟客关系、评论家。
## 这是「多线程心流」和「情感羁绊」两根乐趣支柱的实现。


## 每游戏分钟生成顾客的基础概率（受天气客流系数影响）。
## 0.14 ≈ 一天 8~9 人：配合 4 个工位是「忙得过来但要动脑」的密度。
const SPAWN_PROB_PER_MINUTE: float = 0.14
## 每游戏分钟耐心衰减量（受卫生惩罚放大）。
const PATIENCE_DECAY_PER_MINUTE: float = 3.0

var _next_id: int = 0
var _spawned_today: Dictionary = {}  # regular_id -> bool


func setup() -> void:
	EventBus.subscribe("clock.tick", _on_tick)
	EventBus.subscribe("clock.day_started", _on_day_started)
	EventBus.subscribe("event.food_critic", _on_food_critic)
	EventBus.subscribe("event.rush_hour", _on_rush_hour)
	EventBus.subscribe("kitchen.burnt", _on_burnt)


func teardown() -> void:
	EventBus.unsubscribe("clock.tick", _on_tick)
	EventBus.unsubscribe("clock.day_started", _on_day_started)
	EventBus.unsubscribe("event.food_critic", _on_food_critic)
	EventBus.unsubscribe("event.rush_hour", _on_rush_hour)
	EventBus.unsubscribe("kitchen.burnt", _on_burnt)


func _on_day_started(_day) -> void:
	_spawned_today.clear()
	GameState.customers.clear()
	for s in GameState.seats:
		s["customer_id"] = -1
		s["dirty"] = false
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
			_spawn_customer(Catalog.get_recipe_by_id(r["favorite"]), r["name"], r["id"], randf() < 0.15)


func _random_recipe() -> Recipe:
	var unlocked: Array = Catalog.get_unlocked_recipes(GameState.shop["reputation"])
	var weighted: Array = []
	for r in unlocked:
		weighted.append(r)
		if r.season == GameState.current_season:
			weighted.append(r)  # 应季菜权重翻倍
	if weighted.is_empty():
		weighted = Catalog.get_recipes()  # 兜底：口碑为负也要有点单（防 %0 崩溃）
	return weighted[randi() % weighted.size()]


func _spawn_customer(recipe: Recipe, name: String, regular_id: String, celebrating: bool = false) -> void:
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
		"cook": {"station_id": -1, "phase": ""},
		"regular_id": regular_id,
		"is_critic": false,
		"celebrating": celebrating,
		"seat_id": -1,
		"at_door": false,
		"enter_t": 0.0,
		"dine_timer": 0.0,
	}
	_next_id += 1
	GameState.customers.append(customer)
	_seat_or_queue(customer)
	EventBus.emit("customer.entered", {"name": name, "recipe_name": recipe.display_name, "celebrating": celebrating})


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
		"cook": {"station_id": -1, "phase": ""},
		"regular_id": "",
		"is_critic": true,
		"seat_id": -1,
		"at_door": false,
		"enter_t": 0.0,
		"dine_timer": 0.0,
	}
	_next_id += 1
	GameState.customers.append(customer)
	_seat_or_queue(customer)
	EventBus.emit("customer.entered", {"name": "美食评论家", "recipe_name": recipe.display_name})


# ---------- 座位（v2 P2：落座 / 用餐 / 留盘 / 满座排队） ----------

## 有空桌就落座（走进店里），没座就到门口排队。
func _seat_or_queue(c: Dictionary) -> void:
	if _try_seat(c):
		return
	c["at_door"] = true
	c["door_timer"] = 10.0


func _try_seat(c: Dictionary) -> bool:
	for s in GameState.seats:
		if s["id"] >= GameState.seat_capacity():
			continue  # 未解锁的扩建座位
		if s["customer_id"] == -1 and not s["dirty"]:
			s["customer_id"] = c["id"]
			c["seat_id"] = s["id"]
			c["at_door"] = false
			c["enter_t"] = 1.0  # 走到座位的入场动画
			return true
	return false


## 有座位空出来时，门口排队的人补位。
func _try_seat_waiting() -> void:
	for c in GameState.customers:
		if c.get("at_door", false):
			if _try_seat(c):
				return


## 收桌：清掉脏盘才能接待下一位。
func clean_seat(seat_id: int) -> void:
	var s: Dictionary = GameState.seats[seat_id]
	if not s["dirty"]:
		return
	s["dirty"] = false
	EventBus.emit("seat.cleaned", {"id": seat_id})
	_try_seat_waiting()


func _free_seat(c: Dictionary) -> void:
	if c.get("seat_id", -1) < 0:
		return
	var s: Dictionary = GameState.seats[c["seat_id"]]
	if s["customer_id"] == c["id"]:
		s["customer_id"] = -1
	c["seat_id"] = -1
	_try_seat_waiting()


func _finish_dining(c: Dictionary) -> void:
	# 吃完走人，桌上留脏盘（不收桌不能接待下一位）
	var seat_id: int = c.get("seat_id", -1)
	if seat_id >= 0:
		var s: Dictionary = GameState.seats[seat_id]
		if s["customer_id"] == c["id"]:
			s["customer_id"] = -1
			s["dirty"] = true
	GameState.customers.erase(c)
	EventBus.emit("customer.dined", {"id": c["id"], "name": c["name"]})


func _leave_no_seat(c: Dictionary) -> void:
	# 门口等 10 秒还没座，人走了（小扣口碑）
	GameState.customers.erase(c)
	GameState.shop["reputation"] -= 1
	EventBus.emit("customer.left_no_seat", {"id": c["id"], "name": c["name"]})


## 入场走位 / 用餐倒计时 / 门口等座，全部按真实秒推进。
func _process(delta: float) -> void:
	if GameState.shop["day_state"] != "serving":
		return
	for c in GameState.customers.duplicate():
		if c["enter_t"] > 0.0:
			c["enter_t"] = maxf(c["enter_t"] - delta / 0.8, 0.0)
		if c["state"] == "dining":
			c["dine_timer"] -= delta
			if c["dine_timer"] <= 0.0:
				_finish_dining(c)
		elif c.get("at_door", false):
			if _try_seat(c):
				pass  # 有人翻台了，补位坐下
			else:
				c["door_timer"] -= delta
				if c["door_timer"] <= 0.0:
					_leave_no_seat(c)


# ---------- 耐心 ----------

func _decay_patience() -> void:
	var penalty: float = _hygiene_penalty()
	for c in GameState.customers.duplicate():
		if c["state"] == "dining":
			continue  # 用餐中不掉耐心
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
	_free_seat(c)
	GameState.customers.erase(c)
	GameState.shop["reputation"] -= 1
	if c["regular_id"] != "":
		var r: Dictionary = _find_regular(c["regular_id"])
		if not r.is_empty():
			r["relationship"] -= 1
			if r["relationship"] <= -2:
				r["lost"] = true
				EventBus.emit("regular.lost", {"name": r["name"]})
	EventBus.emit("customer.left_angry", {"id": c["id"], "name": c["name"]})


# ---------- 制作流程 ----------

func take_order(customer_id: int) -> void:
	var c: Dictionary = _find(customer_id)
	if c.is_empty() or c["state"] != "waiting":
		return
	if c.get("at_door", false) or c["enter_t"] > 0.0:
		return  # 门口等座 / 还没走到座位，不能点单
	if GameState.shop["ingredients"] <= 0:
		EventBus.emit("ingredients.empty")
		return
	c["state"] = "being_served"
	c["cook"] = {"station_id": -1, "phase": "queued"}
	GameState.shop["ingredients"] -= 1


func _on_burnt(p) -> void:
	# 糊锅：客人被气走（工位清理由 KitchenSystem 负责）
	var c: Dictionary = _find(p.get("id", -1))
	if not c.is_empty():
		_angry_leave(c)


func serve(customer_id: int) -> void:
	var c: Dictionary = _find(customer_id)
	if c.is_empty() or c["state"] != "ready":
		return
	var recipe: Recipe = Catalog.get_recipe_by_id(c["recipe_id"])
	var patience_ratio: float = c["patience"] / c["patience_max"]
	var satisfaction: float = calc_satisfaction(patience_ratio, GameState.shop["environment"], GameState.shop["hygiene"])
	var tip: int = int(recipe.price * satisfaction)
	var price_mult: float = 1.0 + GameState.shop["upgrades"]["ingredient"] * 0.15
	price_mult *= GameState.weather_modifiers.get("price", 1.0)  # 雨天/台风溢价
	if recipe.season == GameState.current_season:
		price_mult *= 1.5  # 应季加价 50%
	if GameState.shop["holiday"]:
		price_mult *= 1.3  # 节日促销加价 30%
	var earned: int = int((recipe.price + tip) * price_mult)
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
			var prev_rel: int = r["relationship"]
			if satisfaction >= 0.6:
				r["relationship"] += 1
			if c.get("celebrating", false):
				r["relationship"] += 1
				EventBus.emit("regular.celebrate", {"name": r["name"]})
			r["relationship"] = clampi(r["relationship"], -3, 5)
			if r["lost"]:
				r["lost"] = false
			# 里程碑送礼
			if prev_rel < 3 and r["relationship"] >= 3:
				GameState.shop["money"] += 50
				EventBus.emit("regular.gift", {"name": r["name"]})
			# 口碑传播：带朋友
			if satisfaction >= 0.8 and randf() < 0.3:
				_spawn_customer(_random_recipe(), "客人", "")
				EventBus.emit("regular.brings_friend", {"name": r["name"]})

	# 上菜后坐下用餐 5~8 秒，吃完留脏盘（v2 P2）
	c["state"] = "dining"
	c["dine_timer"] = 5.0 + randf() * 3.0
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
