class_name WeatherType
extends Resource
## 天气数据。加新天气 = 新建资源文件，不改代码。

@export var id: String = ""
@export var display_name: String = ""
## 客流系数（1.0 为基准，雨 0.6 表示客流减少）
@export var customer_traffic_modifier: float = 1.0
## 卫生劣化系数（雨 1.3 表示地面更易脏）
@export var hygiene_decay_modifier: float = 1.0
## 环境值加成（负数表示阴冷不适）
@export var environment_modifier: float = 0.0
