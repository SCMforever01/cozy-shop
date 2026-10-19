extends SceneTree
## 音频管理（v2 音效）单元测试：素材加载、循环设置、声音开关。
## 运行：godot --headless --script res://tests/test_audio.gd

var _failed: int = 0


func _initialize() -> void:
	var AM = load("res://scripts/audio_manager.gd")
	var am = AM.new()
	# --script 模式下 quit() 在 _initialize 内，入树节点的 _ready 不会触发，手动调用
	am._ready()

	# 用例 1：全部 SFX 素材加载成功
	var missing: Array = []
	for key in AM.SFX:
		if am._streams.get(key) == null:
			missing.append(key)
	_check(missing.is_empty(), "SFX 素材全部加载（缺失: %s）" % str(missing))

	# 用例 2：循环音频启用循环且范围正确
	_check(am._bgm.stream != null and am._bgm.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "BGM 启用循环")
	_check(am._bgm.stream.loop_end > 0, "BGM 循环范围非零")
	_check(am._rain.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "雨声启用循环")
	_check(am._sizzle.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "煎炒声启用循环")

	# 用例 3：声音开关
	am.toggle()
	_check(not am.enabled and AudioServer.is_bus_mute(0), "声音开关：静音生效")
	am.toggle()
	_check(am.enabled and not AudioServer.is_bus_mute(0), "声音开关：恢复生效")

	# 用例 4：播放不报错（headless 下走哑音频驱动）
	am.play_sfx("coin")
	am.set_rain(true)
	am.set_sizzle(true)
	am.set_rain(false)
	am.set_sizzle(false)
	_check(true, "播放/氛围开关调用安全")

	if _failed == 0:
		print("PASS: audio 全部用例通过")
	quit(1 if _failed > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: " + msg)
	else:
		_failed += 1
		print("  FAIL: " + msg)
