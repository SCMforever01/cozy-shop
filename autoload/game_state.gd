extends Node
## 单一数据源：店铺、顾客等可变状态集中于此，纯数据、可脱离渲染单测。
##
## 系统之间不要互相持有状态，统一读写 GameState。
## 注意：时间由 GameClock 单独持有（单一职责，避免重复）。

# 店铺级状态
var shop: Dictionary = {
	"hygiene": 100.0,   # 卫生值 0~100
	"environment": 100.0,  # 环境值 0~100
	"money": 100,       # 金钱
	"reputation": 0,    # 口碑
	"level": 1,         # 等级
	"day_state": "preparing",  # preparing / serving / closed
}

# 当前天气 id（对应 data/catalog.gd 的定义）
var weather_id: String = "sunny"
# 天气对各项机制的系数（由 WeatherSystem 每天写入）
var weather_modifiers: Dictionary = {
	"traffic": 1.0,       # 客流系数
	"hygiene_decay": 1.0, # 卫生劣化系数
	"environment": 0.0,   # 环境加成
}

# 在场顾客列表（每个元素为 Dictionary）
var customers: Array = []

# 熟客列表（每个熟客一个字典，可扩展更多熟客）
var regulars: Array = [
	{
		"id": "laozhang",
		"name": "老张",
		"favorite": "milk_tea",
		"relationship": 0,  # -3 ~ 5，越高越亲密；<= -2 视为流失
		"visits": 0,
		"lost": false,
	},
	{
		"id": "xiaowang",
		"name": "小王",
		"favorite": "coffee",
		"relationship": 0,
		"visits": 0,
		"lost": false,
	},
]
