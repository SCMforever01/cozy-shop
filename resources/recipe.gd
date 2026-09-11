class_name Recipe
extends Resource
## 菜谱数据：定义一道菜的做法与售价。
## 加新菜 = 在编辑器里新建一个 Recipe 资源（.tres），不改代码。

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
## 制作步骤，如 ["切菜", "煎制"]（Phase 1 的轻操作据此生成）
@export var steps: Array = []
## 售价
@export var price: int = 0
## 解锁所需口碑（口碑低于此值不可做）
@export var unlock_reputation: int = 0
## 应季季节（spring/summer/autumn/winter，匹配时更受欢迎）
@export var season: String = ""
