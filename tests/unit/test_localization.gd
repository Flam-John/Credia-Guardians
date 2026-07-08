extends GutTest
## EL/EN localization: translations load, Greek strings resolve, locale
## persists through the settings pipeline, English falls back to keys.

var _original_locale: String


func before_all() -> void:
	SaveManager.redirect_for_tests("user://test_saves", "user://test_settings.cfg")
	_original_locale = TranslationServer.get_locale()


func after_all() -> void:
	TranslationServer.set_locale(_original_locale)
	SaveManager.restore_default_paths()


func test_greek_translations_resolve() -> void:
	TranslationServer.set_locale("el")
	assert_eq(TranslationServer.translate(&"NEW GAME"), "ΝΕΟ ΠΑΙΧΝΙΔΙ")
	assert_eq(TranslationServer.translate(&"GAME OVER"), "ΤΕΛΟΣ ΠΑΙΧΝΙΔΙΟΥ")
	assert_eq(TranslationServer.translate(&"DEVELOPER OFFICE"), "ΓΡΑΦΕΙΟ ΠΡΟΓΡΑΜΜΑΤΙΣΤΩΝ")
	assert_eq(TranslationServer.translate(&"BANK SYSTEM SECURED!"),
			"ΤΟ ΤΡΑΠΕΖΙΚΟ ΣΥΣΤΗΜΑ ΑΣΦΑΛΙΣΤΗΚΕ!")


func test_english_locale_keeps_english() -> void:
	TranslationServer.set_locale("en")
	assert_eq(TranslationServer.translate(&"NEW GAME"), "NEW GAME")


func test_format_strings_translate_and_format() -> void:
	TranslationServer.set_locale("el")
	var formatted: String = TranslationServer.translate(&"SCORE %d") % 1234
	assert_eq(formatted, "ΣΚΟΡ 1234")


func test_intro_panels_have_both_languages() -> void:
	for key in ["INTRO_1", "INTRO_2", "INTRO_3", "INTRO_4"]:
		TranslationServer.set_locale("en")
		var en := TranslationServer.translate(StringName(key))
		TranslationServer.set_locale("el")
		var el := TranslationServer.translate(StringName(key))
		assert_ne(en, key, "%s has English text" % key)
		assert_ne(el, en, "%s has distinct Greek text" % key)


func test_locale_flows_through_settings() -> void:
	var settings := SettingsApplier.defaults()
	settings.general.locale = "el"
	SettingsApplier.apply(settings, get_window())
	assert_eq(TranslationServer.get_locale().substr(0, 2), "el")
	settings.general.locale = "en"
	SettingsApplier.apply(settings, get_window())
	assert_eq(TranslationServer.get_locale().substr(0, 2), "en")
