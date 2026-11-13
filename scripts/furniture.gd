class_name Furniture
extends RefCounted

const DIR := "res://props/furniture/"
const TOON := preload("res://shaders/toon.gdshader")

static var _mats := {}

static func material(name: String) -> ShaderMaterial:
	if _mats.has(name):
		return _mats[name]
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("base_color", Color.WHITE)
	m.set_shader_parameter("has_albedo", true)
	m.set_shader_parameter("albedo_tex", load(local_path(name + "_alb.png")))
	if ResourceLoader.exists(DIR + name + "_nrm.png"):
		m.set_shader_parameter("has_prop_nrm", true)
		m.set_shader_parameter("prop_nrm", load(DIR + name + "_nrm.png"))
	if ResourceLoader.exists(DIR + name + "_emit.png"):
		m.set_shader_parameter("has_prop_emit", true)
		m.set_shader_parameter("prop_emit", load(local_path(name + "_emit.png")))
	m.set_shader_parameter("shade_soft", 0.35)
	m.set_shader_parameter("rim", 0.12)
	_mats[name] = m
	return m

static func local_path(file: String) -> String:
	"""An atlas with printed words has a copy per language in i18n/<lang>/ (tools/furniture/station_i18n.py)."""
	var lang = Engine.get_main_loop().root.get_node_or_null("Lang")
	if lang:
		var p := "%si18n/%s/%s" % [DIR, lang.current, file]
		if ResourceLoader.exists(p):
			return p
	return DIR + file

static func place(parent: Node3D, name: String, pos: Vector3, yaw_deg := 0.0, solid := true, skin := "") -> Node3D:
	var n: Node3D = load(DIR + name + ".glb").instantiate()
	n.position = pos
	n.rotation.y = deg_to_rad(yaw_deg)
	parent.add_child(n)
	var aabb := AABB()
	var first := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = material(skin if skin != "" else name)
		var box := mi.transform * mi.get_aabb()
		aabb = box if first else aabb.merge(box)
		first = false
	if solid and not first:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = aabb.size
		cs.shape = bs
		cs.position = aabb.get_center()
		sb.add_child(cs)
		n.add_child(sb)
	return n
