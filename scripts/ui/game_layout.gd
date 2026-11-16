class_name GameLayout
extends RefCounted
## UI 布局常量与命中区域的唯一来源。
## 绘制（scripts/ui/ 各视图）与输入（scenes/main.gd）都从这里取几何，
## 保证「画的位置」和「点的区域」永远一致。


const W := 1280.0
const H := 720.0
const HUD_H := 64.0

## 全局风格开关：true 用像素贴图，false 用代码图形（「像素/代码」按钮切换）。
static var use_sprites: bool = true

# 底部按钮
const OPEN_RECT := Rect2(40, H - 68, 150, 48)
const MOP_RECT := Rect2(210, H - 68, 150, 48)
const CLOSE_RECT := Rect2(380, H - 68, 150, 48)
const RESET_RECT := Rect2(W - 110, H - 68, 100, 48)
const LANG_RECT := Rect2(W - 220, H - 68, 100, 48)
const STYLE_RECT := Rect2(W - 330, H - 68, 100, 48)
const SOUND_RECT := Rect2(W - 440, H - 68, 100, 48)

# 升级 / 采购按钮
const UPGRADE_MOP_RECT := Rect2(40, H - 132, 168, 44)
const UPGRADE_STOVE_RECT := Rect2(216, H - 132, 168, 44)
const UPGRADE_SEAT_RECT := Rect2(392, H - 132, 168, 44)
const UPGRADE_INGREDIENT_RECT := Rect2(568, H - 132, 168, 44)
const UPGRADE_DECOR_RECT := Rect2(744, H - 132, 168, 44)
const BUY_INGREDIENTS_RECT := Rect2(40, H - 196, 230, 44)
const BUY_BULK_RECT := Rect2(290, H - 196, 230, 44)

# 新手引导弹窗
const TUTORIAL_RECT := Rect2(W * 0.15, H * 0.28, W * 0.7, H * 0.4)
const TUTORIAL_NEXT_RECT := Rect2(W * 0.58, H * 0.62, 150, 46)
const TUTORIAL_SKIP_RECT := Rect2(W * 0.30, H * 0.62, 150, 46)

# 场景摆设
## 地面污渍的固定位置（越脏出现越多，最多 8 处）
const DIRT_SPOTS := [
	Vector2(430, 610), Vector2(700, 540), Vector2(150, 560), Vector2(600, 260),
	Vector2(840, 420), Vector2(120, 380), Vector2(520, 430), Vector2(760, 640),
]
## 3 张餐桌（桌面中心点），对应 GameState.seats 的 id
const SEAT_POS := [Vector2(250, 300), Vector2(620, 300), Vector2(435, 470)]
## 门口等座区（满座时客人站这里，10 秒没座就走）
const DOOR_POS := Vector2(740, 545)


# ---------- 顾客位置（绘制与命中检测共用） ----------

## 门口排队序号（0 起）。
static func door_index(customers: Array, c: Dictionary) -> int:
	var n := 0
	for other in customers:
		if other.get("at_door", false):
			if other["id"] == c["id"]:
				return n
			n += 1
	return n


## 门口排队位置：沿对角线错位排开（避免人塔堆叠 + 气泡不出厨房分界线）。
static func door_queue_pos(index: int) -> Vector2:
	return Vector2(650.0 - 58.0 * index, 445.0 + 27.0 * index)


## 顾客当前绘制位置：座位上的桌子后方 / 门口等座（错位队列）/ 入场走位中。
static func customer_draw_pos(customers: Array, c: Dictionary) -> Vector2:
	if not c.get("at_door", false) and c.get("seat_id", -1) >= 0:
		var target: Vector2 = SEAT_POS[c["seat_id"]] + Vector2(0, -40)
		if c["enter_t"] > 0.0:
			return door_queue_pos(0).lerp(target, 1.0 - c["enter_t"])
		return target
	return door_queue_pos(door_index(customers, c))


## 顾客（头像 + 点单气泡）的点击区域（宽度覆盖自适应后的气泡）。
static func customer_hit_rect(customers: Array, c: Dictionary) -> Rect2:
	var p := customer_draw_pos(customers, c)
	return Rect2(p.x - 45, p.y - 70, 300, 110)


# ---------- 厨房工位 ----------

## 第 i 个工位卡片的中心位置。
static func station_pos(i: int) -> Vector2:
	return Vector2(1015 + (i % 2) * 170, 265 + (i / 2) * 180)


## 工位卡片的点击区域。
static func station_hit_rect(i: int) -> Rect2:
	var p := station_pos(i)
	return Rect2(p.x - 78, p.y - 62, 156, 128)


## 第 i 个待处理菜（等工位 / 待上菜）的位置。
static func waiting_pos(i: int) -> Vector2:
	return Vector2(985 + i * 72, 615)


## 待处理菜的点击区域。
static func waiting_hit_rect(i: int) -> Rect2:
	var p := waiting_pos(i)
	return Rect2(p.x - 30, p.y - 30, 60, 80)


## 待处理菜列表（等工位的 / 做完待上菜的，工位上的菜由工位卡片负责），
## 顺序即绘制顺序，输入命中按同一顺序索引。
static func waiting_dishes(customers: Array) -> Array:
	var result: Array = []
	for c in customers:
		if c["state"] != "being_served" and c["state"] != "ready":
			continue
		if c["cook"]["station_id"] >= 0:
			continue
		result.append(c)
	return result


# ---------- 餐桌 ----------

## 脏桌的点击区域。
static func seat_hit_rect(i: int) -> Rect2:
	var p: Vector2 = SEAT_POS[i]
	return Rect2(p.x - 95, p.y - 40, 190, 100)
