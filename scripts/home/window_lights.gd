class_name WindowLights
extends Node

const ATLASES := ["cua", "cua2"]
const STEP := 0.5
const GLOW := preload("res://shaders/window_glow.gdshader")

var home: Node3D
var _pass := {}
var _mats := {}
var _houses := []
var _t := 0.0
var _on := false

static func add(parent: Node3D) -> WindowLights:
	var w := WindowLights.new()
	w.name = "WindowLights"
	w.home = parent
	parent.add_child(w)
	return w

func _ready() -> void:
	for a in ATLASES:
		var path := "res://props/village/%s_glass.png" % a
		if not ResourceLoader.exists(path):
			continue
		var m := ShaderMaterial.new()
		m.shader = GLOW
		m.set_shader_parameter("glass_tex", load(path))
		m.set_shader_parameter("albedo_tex", load("res://props/hometown/%s_alb.png" % a))
		_pass[a] = m
	await get_tree().create_timer(2.0).timeout
	_scan()

func _scan() -> void:
	"""The village houses (layout dress.houses) that have the atlas materials, and those materials."""
	var layout = home.get("layout")
	if not layout is Dictionary:
		return
	var spots := {}
	for h: Array in layout.get("dress", {}).get("houses", []):
		spots[Vector2i(roundi(h[0] * 10.0), roundi(h[1] * 10.0))] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for n in home.get_children():
		if not n is Node3D:
			continue
		var p := (n as Node3D).global_position
		if not spots.has(Vector2i(roundi(p.x * 10.0), roundi(p.z * 10.0))):
			continue
		var meshes := []
		for mi: MeshInstance3D in (n as Node3D).find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null:
				continue
			for s in mi.mesh.get_surface_count():
				var m := mi.get_active_material(s) as ShaderMaterial
				var a := _atlas_of(m)
				if a != "":
					_mats[m] = a
					if not mi in meshes:
						meshes.append(mi)
		if not meshes.is_empty():
			_houses.append({"node": n, "meshes": meshes, "off": rng.randf_range(20.5, 22.8), "lit": -1.0})
	if _on:
		for m: ShaderMaterial in _mats:
			m.next_pass = _pass[_mats[m]]
	if OS.get_cmdline_user_args().has("--village-log"):
		print("windows: %d houses matched of %d, %d atlas materials, passes %s" % [_houses.size(), spots.size(), _mats.size(), _pass.keys()])

func _atlas_of(m: ShaderMaterial) -> String:
	if m == null or not _pass.size():
		return ""
	var tex = m.get_shader_parameter("albedo_tex")
	if not tex is Texture2D:
		return ""
	var f := (tex as Texture2D).resource_path.get_file()
	for a in ATLASES:
		if f == a + "_alb.png" and _pass.has(a):
			return a
	return ""

func _process(delta: float) -> void:
	_t += delta
	if _t < STEP:
		return
	_t = 0.0
	var night: float = HomeKit._night
	var on := night > 0.02
	if on != _on:
		_on = on
		for m: ShaderMaterial in _mats:
			m.next_pass = _pass[_mats[m]] if on else null
	if not on:
		return
	for a in _pass:
		(_pass[a] as ShaderMaterial).set_shader_parameter("night", night)
	var h := VillageLife.hour()
	var vl := home.get_node_or_null("VillageLife") as VillageLife
	var homes := {}
	var owned := {}
	if vl:
		for id in vl.people:
			var hs: Array = vl._house(vl.people[id]["spec"])
			if hs[0] != null:
				owned[hs[0]] = true
				if vl.people[id].get("home", false):
					homes[hs[0]] = true
	for e: Dictionary in _houses:
		var want := 0.0
		if owned.has(e["node"]):
			want = 1.0 if homes.has(e["node"]) else 0.0
		elif h >= 17.5 or h < 5.0:
			want = 1.0 if (h >= 17.5 and h < float(e["off"])) else 0.0
		if want != e["lit"]:
			e["lit"] = want
			for mi: MeshInstance3D in e["meshes"]:
				mi.set_instance_shader_parameter("lit", want)
