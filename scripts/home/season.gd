extends Node

const START := [5, 15]
const END := [8, 15]

var _t := 0.0
const BLOOM_ROWS := ["phuong", "bang_lang", "hoa_sua", "sen", "gao"]
static var _ramp: Image

static func phase(month: int, day: int) -> float:
	return fmod(float((month - 1) * 30 + day - 1) / 360.0 + 1.0, 1.0)

static func story(s: float) -> float:
	var s0 := phase(START[0], START[1])
	return s0 + (phase(END[0], END[1]) - s0) * clampf(s, 0.0, 1.0)

static func value() -> float:
	var l: Array = Clock.lunar()
	return phase(int(l[0]), int(l[1]))

static func strength(k: float) -> void:
	RenderingServer.global_shader_parameter_set("season_strength", clampf(k, 0.0, 1.0))

var _forced := -1.0

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		if args[i] == "--season":
			_forced = story(float(args[i + 1]))
		elif args[i] == "--lunar":
			var md := args[i + 1].split(",")
			if md.size() == 2:
				_forced = phase(int(md[0]), int(md[1]))
		elif args[i] == "--season-strength":
			strength(float(args[i + 1]))
	_apply()

func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = 1.0
		_apply()

func _apply() -> void:
	RenderingServer.global_shader_parameter_set("season", _forced if _forced >= 0.0 else value())

static func bloom(species: String) -> float:
	var row := BLOOM_ROWS.find(species)
	if row < 0:
		return 0.0
	if _ramp == null:
		_ramp = (load("res://props/bloom_ramp.png") as Texture2D).get_image()
		if _ramp.is_compressed():
			_ramp.decompress()
	var x := clampi(roundi(_now() * (_ramp.get_width() - 1)), 0, _ramp.get_width() - 1)
	return _ramp.get_pixel(x, clampi(row, 0, _ramp.get_height() - 1)).r

static func lotus(rng: RandomNumberGenerator) -> String:
	var b := bloom("sen")
	var r := rng.randf()
	if r < b:
		return "sen_3"
	var s0 := story(0.0)
	var late := clampf((_now() - s0) / (story(1.0) - s0) * 1.2, 0.0, 1.0)
	return "sen_4" if rng.randf() < late else "sen_2"

static func _now() -> float:
	var tree := Engine.get_main_loop() as SceneTree
	var n: Node = tree.root.get_node_or_null("Season") if tree else null
	if n and float(n.get("_forced")) >= 0.0:
		return float(n.get("_forced"))
	return value()
