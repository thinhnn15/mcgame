extends Node

const TARGET_MS := 16.9
const START := 0.8
const MIN_S := 0.65
const MAX_S := 0.9
const STEP := 0.05
const CHECK := 0.5
const SHARP := 0.3
const PROBE_MS := 16.75

var _on := false
var _scale := START
var _sum := 0.0
var _n := 0
var _t := 0.0
var _good := 0.0
var _wait := 6.0
var _since_up := 999.0
var _sim := 0.0
var _log := false
var _hold := 0
var _fix := 0.0
var _miss := 0

func _ready() -> void:
	_on = (OS.has_feature("mobile") or OS.get_environment("MC_DYNRES") != "") and OS.get_environment("MC_DYNRES_OFF") == ""
	_sim = float(OS.get_environment("MC_DYNRES_SIM")) if OS.get_environment("MC_DYNRES_SIM") != "" else 0.0
	_log = OS.get_environment("MC_DYNRES_LOG") != ""
	_fix = float(OS.get_environment("MC_DYNRES_FIX")) if OS.get_environment("MC_DYNRES_FIX") != "" else 0.0
	if _fix > 0.0:
		_scale = _fix
	set_process(_on)
	if _on:
		_apply()

func hold(on: bool) -> void:
	_hold = maxi(_hold + (1 if on else -1), 0)

func scale() -> float:
	return _scale if _on else 1.0

func _process(delta: float) -> void:
	if _sim > 0.0:
		var want := _sim * _scale * _scale
		var spare := want - delta * 1000.0
		if spare > 0.5:
			OS.delay_usec(int(spare * 1000.0))
	if delta > 0.1:
		return
	_sum += delta
	_n += 1
	_t += delta
	_since_up += delta
	if _t < CHECK:
		return
	var avg := _sum / _n * 1000.0
	_sum = 0.0
	_n = 0
	var span := _t
	_t = 0.0
	if _hold > 0 or _fix > 0.0:
		_good = 0.0
		_apply()
		return
	if avg > TARGET_MS:
		if _since_up < 3.0:
			_wait = minf(_wait * 2.0, 60.0)
		_miss += 1
		if _miss >= 2:
			_miss = 0
			_set_scale(_scale - STEP, "miss %.1f ms" % avg)
		_good = 0.0
	else:
		_miss = 0
		_good += span if avg <= PROBE_MS else 0.0
		if _good >= _wait and _scale < MAX_S:
			_set_scale(_scale + STEP, "probe")
			_good = 0.0
			_since_up = 0.0
	_apply()

func _set_scale(s: float, why: String) -> void:
	var old := _scale
	_scale = clampf(snappedf(s, STEP), MIN_S, MAX_S)
	if _log and not is_equal_approx(old, _scale):
		print("dyn_res: %.2f -> %.2f (%s, wait %.0f s)" % [old, _scale, why, _wait])

func _apply() -> void:
	var vp := get_viewport()
	if vp == null:
		return

	var fwd := RenderingServer.get_current_rendering_method() == "forward_plus"
	var want := Viewport.SCALING_3D_MODE_FSR if fwd else Viewport.SCALING_3D_MODE_BILINEAR
	if vp.scaling_3d_mode != want:
		vp.scaling_3d_mode = want
		vp.fsr_sharpness = SHARP
	if not is_equal_approx(vp.scaling_3d_scale, _scale):
		vp.scaling_3d_scale = _scale
