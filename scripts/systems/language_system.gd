class_name LanguageSystem
extends System
## 语言系统：中英切换。中文为默认（源文本），英文走翻译表。


var _is_en: bool = false
var _translation: Translation


func setup() -> void:
	_translation = Translation.new()
	_translation.locale = "en"
	var en := Translations.get_en()
	for k in en:
		_translation.add_message(k, en[k])
	TranslationServer.add_translation(_translation)
	TranslationServer.set_locale("zh")


func is_en() -> bool:
	return _is_en


func toggle() -> void:
	_is_en = not _is_en
	TranslationServer.set_locale("en" if _is_en else "zh")
	EventBus.emit("language.changed", _is_en)
