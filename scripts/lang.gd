extends Node

const LANGS := ["vi", "en", "ja", "ko", "zh_CN"]
const NAMES := {"vi": "Tiếng Việt", "en": "English", "ja": "日本語", "ko": "한국어", "zh_CN": "简体中文"}
const CFG := "user://settings.cfg"
const FONT_DIR := "res://fonts/"

const LATIN := ["Nunito[wght].ttf", 700]
const JA := ["MPLUSRounded1c-Bold.ttf", 0]
const KO := ["NotoSansKR[wght].ttf", 650]
const ZH := ["NotoSansSC[wght].ttf", 600]
const FONT_ORDER := {"vi": [LATIN, JA, KO, ZH], "en": [LATIN, JA, KO, ZH], "ja": [LATIN, JA, ZH, KO],
	"ko": [LATIN, KO, JA, ZH], "zh_CN": [LATIN, ZH, JA, KO]}

var current := "en"
var font: Font

func _ready() -> void:
	apply(chosen())

func chosen() -> String:
	var want := Stage.arg("--lang")
	if want == "":
		var cfg := ConfigFile.new()
		if cfg.load(CFG) == OK:
			want = str(cfg.get_value("general", "lang", ""))
	if want == "":
		want = _from_os()
	return want if want in LANGS else "en"

func _from_os() -> String:
	var lang := OS.get_locale_language()
	if lang == "zh":
		return "zh_CN"
	return lang if lang in LANGS else "en"

func set_language(lang: String) -> void:
	"""Switch, save for next time, and rebuild the current scene in the new language."""
	var cfg := ConfigFile.new()
	cfg.load(CFG)
	cfg.set_value("general", "lang", lang)
	cfg.save(CFG)
	apply(lang)
	get_tree().reload_current_scene()

func apply(lang: String) -> void:
	current = lang
	TranslationServer.set_locale(lang)
	font = _font_for(lang)
	ThemeDB.fallback_font = font
	ThemeDB.get_default_theme().default_font = font

func t(key: String, args := {}) -> String:
	var s := tr(key)
	return s.format(args) if not args.is_empty() else s

func path_for(dir: String, file: String) -> String:
	"""A picture drawn per language: <dir>/<lang>/<file>, or <dir>/en/<file> if that language has none."""
	var p := "%s/%s/%s" % [dir, current, file]
	return p if ResourceLoader.exists(p) else "%s/en/%s" % [dir, file]

func _font_for(lang: String) -> Font:
	var list: Array = FONT_ORDER[lang]
	var fonts: Array[Font] = []
	for f in list:
		var v := FontVariation.new()
		v.base_font = load(FONT_DIR + f[0])
		if f[1] > 0:
			v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): f[1]}
		fonts.append(v)
	var main := fonts[0]
	main.fallbacks = fonts.slice(1)
	return main
