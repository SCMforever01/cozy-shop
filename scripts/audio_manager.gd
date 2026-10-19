class_name AudioManager
extends Node
## 音频管理（v2 音效）：BGM 循环 + 雨声/煎炒声氛围 + SFX 池 + 声音开关。
## 素材：Kenney CC0 音效包 + 自合成循环（bgm/sizzle/rain，见 tools 说明）。

const SFX := {
	"tap": "res://assets/audio/tap.ogg",
	"accept": "res://assets/audio/accept.ogg",
	"pickup": "res://assets/audio/pickup.ogg",
	"coin": "res://assets/audio/coin.ogg",
	"burn": "res://assets/audio/burn.ogg",
	"door": "res://assets/audio/door.ogg",
	"upgrade": "res://assets/audio/upgrade.ogg",
	"open": "res://assets/audio/jingle_open.ogg",
	"summary": "res://assets/audio/jingle_day.ogg",
	"typhoon": "res://assets/audio/typhoon.ogg",
	"mop": "res://assets/audio/mop.ogg",
	"deny": "res://assets/audio/deny.ogg",
}

var enabled: bool = true

var _streams: Dictionary = {}
var _pool: Array = []
var _bgm: AudioStreamPlayer
var _rain: AudioStreamPlayer
var _sizzle: AudioStreamPlayer


func _ready() -> void:
	for key in SFX:
		_streams[key] = load(SFX[key])
	for i in range(8):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_bgm = _make_loop("res://assets/audio/bgm_loop.wav")
	_bgm.volume_db = -12.0
	_bgm.play()
	_rain = _make_loop("res://assets/audio/rain_loop.wav")
	_rain.volume_db = -60.0
	_sizzle = _make_loop("res://assets/audio/sizzle_loop.wav")
	_sizzle.volume_db = -60.0


func _make_loop(path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var stream = load(path)
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2  # 16bit 单声道：帧数 = 字节/2
	p.stream = stream
	add_child(p)
	return p


func play_sfx(key: String, volume_db: float = 0.0) -> void:
	if not enabled or not _streams.has(key):
		return
	for p in _pool:
		if not p.playing:
			p.stream = _streams[key]
			p.volume_db = volume_db
			p.play()
			return


## 雨声氛围开关（雨/暴雨/台风）。
func set_rain(on: bool) -> void:
	if on:
		if not _rain.playing:
			_rain.play()
		_rain.volume_db = -14.0
	else:
		_rain.volume_db = -60.0


## 煎炒声氛围开关（灶台上有菜在做）。
func set_sizzle(on: bool) -> void:
	if on:
		if not _sizzle.playing:
			_sizzle.play()
		_sizzle.volume_db = -22.0
	else:
		_sizzle.volume_db = -60.0


func toggle() -> void:
	enabled = not enabled
	AudioServer.set_bus_mute(0, not enabled)
