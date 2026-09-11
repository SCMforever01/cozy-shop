class_name LanguageSystem
extends System
## 语言系统：中英切换。中文为默认（源文本），英文走翻译表。
## 注意：Godot 翻译有「en」兜底 locale，需额外加一个中文恒等翻译，
## 否则 locale 为 zh 时也会回退到英文。


var _is_en: bool = false


func setup() -> void:
	var en := Translations.get_en()
	# 中文恒等翻译（中文 -> 中文），避免回退到英文兜底
	var zh := Translation.new()
	zh.locale = "zh"
	for k in en:
		zh.add_message(k, k)
	TranslationServer.add_translation(zh)
	# 英文翻译
	var en_trans := Translation.new()
	en_trans.locale = "en"
	for k in en:
		en_trans.add_message(k, en[k])
	TranslationServer.add_translation(en_trans)
	TranslationServer.set_locale("zh")


func is_en() -> bool:
	return _is_en


func toggle() -> void:
	_is_en = not _is_en
	TranslationServer.set_locale("en" if _is_en else "zh")
	EventBus.emit("language.changed", _is_en)
