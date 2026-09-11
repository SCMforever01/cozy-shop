extends SceneTree
## 字体诊断：确认 Noto 字体是否加载成功、是否含中文形。
## 运行：godot --headless --script res://tests/test_font.gd


func _initialize() -> void:
	var font = load("res://assets/fonts/NotoSansSC-Static.ttf")
	if font == null:
		print("RESULT: FONT LOAD FAILED (null)")
		quit(1)
		return
	print("RESULT: font loaded, class = ", font.get_class())
	print("RESULT: has '天' (0x5929): ", font.has_char(0x5929))
	print("RESULT: has '第' (0x7B2C): ", font.has_char(0x7B2C))
	print("RESULT: has 'A' (0x41): ", font.has_char(0x41))
	quit(0)
