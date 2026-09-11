class_name CustomerType
extends Resource
## 客人类型数据。加新客人类型 = 新建资源文件，不改代码。

@export var id: String = ""
@export var display_name: String = ""
## 基础耐心值（越高越能等）
@export var patience_base: float = 100.0
## 是否为熟客
@export var is_regular: bool = false
## 固定点单（熟客用，存 Recipe 的 id）
@export var favorite_recipe_id: String = ""
