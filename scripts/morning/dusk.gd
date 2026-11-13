class_name Dusk
extends Node

const SUNSET := [1020.0, 1110.0]
const NIGHT := [1080.0, 1200.0]

var office
var _veil: StandardMaterial3D
var _lights: Array = []
var _day_glows: Array = []
var _day_decals: Array = []
var _sun: DirectionalLight3D
var _env: Environment
var _sun0 := 0.0
var _sun_col0 := Color.WHITE
var _amb0 := 0.0
var _off := 0.0
var _off_tw: Tween

func setup(p_office) -> void:
	office = p_office
	_sun = office.find_child("Sun", false, false)
	_env = (office.find_child("WorldEnvironment", false, false) as WorldEnvironment).environment
	_sun0 = _sun.light_energy
	_sun_col0 = _sun.light_color
	_amb0 = _env.ambient_light_energy
	for n in office.world.find_children("*", "", true, false):
		if n is Decal:
			_day_decals.append([n, (n as Decal).emission_energy])
		elif n is MeshInstance3D and (n as MeshInstance3D).material_override is StandardMaterial3D:
			var m := (n as MeshInstance3D).material_override as StandardMaterial3D
			if m.blend_mode == BaseMaterial3D.BLEND_MODE_ADD and (n as MeshInstance3D).global_position.x < 2.5:
				_day_glows.append([m, m.albedo_color.a])
	_build_veil()

func _build_veil() -> void:
	var z: float = -office.ROOM.y / 2.0 - 0.75
	_veil = StandardMaterial3D.new()
	_veil.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_veil.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_veil.albedo_color = Color(0, 0, 0, 0)
	var q := MeshInstance3D.new()
	var pm := QuadMesh.new()
	pm.size = Vector2(office.ROOM.x + 6.0, 4.6)
	q.mesh = pm
	q.material_override = _veil
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	q.position = Vector3(0, 2.2, z)
	office.world.add_child(q)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in 70:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var c := Color("ffd68a") if rng.randf() < 0.7 else Color("bfe0ff")
		m.albedo_color = Color(c, 0.0)
		var w := MeshInstance3D.new()
		var wm := QuadMesh.new()
		wm.size = Vector2(rng.randf_range(0.12, 0.3), 0.07)
		w.mesh = wm
		w.material_override = m
		w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		w.position = Vector3(rng.randf_range(-office.ROOM.x / 2.0 - 1.5, office.ROOM.x / 2.0 + 1.5), rng.randf_range(0.7, 3.4), z + 0.02)
		office.world.add_child(w)
		_lights.append([m, rng.randf_range(0.55, 0.95), rng.randf_range(0.0, 1.0)])

func set_time(minute: float) -> void:
	var s := smoothstep(SUNSET[0], SUNSET[1], minute)
	var n := smoothstep(NIGHT[0], NIGHT[1], minute)
	var warm := Color("ff9a5c")
	var deep := Color("161838")
	var veil := warm.lerp(deep, n)
	_veil.albedo_color = Color(veil, 0.3 * s * (1.0 - n) + 0.86 * n)
	for l in _lights:
		var k := smoothstep(float(l[2]) * 0.7, float(l[2]) * 0.7 + 0.15, n)
		(l[0] as StandardMaterial3D).albedo_color.a = float(l[1]) * k
	var day := 1.0 - n
	for g in _day_glows:
		(g[0] as StandardMaterial3D).albedo_color.a = float(g[1]) * day * (1.0 - _off)
	for d in _day_decals:
		(d[0] as Decal).emission_energy = float(d[1]) * (1.0 - s)
	_sun.light_energy = _sun0 * lerpf(1.0, 0.12, n) * lerpf(1.0, 0.75, s) * lerpf(1.0, 0.5, _off)
	_sun.light_color = _sun_col0.lerp(Color("ffb27a"), s * (1.0 - n)).lerp(Color("9fb0ff"), n)
	_env.ambient_light_energy = _amb0 * lerpf(1.0, 0.45, n) * lerpf(1.0, 0.35, _off)

func lights_off() -> void:
	"""The strip lights go out: only the hero's desk lamp and the monitor are left."""
	if _off_tw:
		return
	office._night_desk()
	_off_tw = create_tween()
	_off_tw.tween_property(self, "_off", 1.0, 1.2)
