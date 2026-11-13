class_name HandPhone
extends Node3D

const SIZE := Vector3(0.085, 0.13, 0.015)
const BOTH := 0.26

var chibi: Chibi
var shown := false:
	set(v):
		shown = v
		visible = v
var _hand_l := -1
var _hand_r := -1
var _head := -1

static func on(c: Chibi) -> HandPhone:
	"""The chibi's phone (made the first time)."""
	var ph := c.get_node_or_null("HandPhone") as HandPhone
	if ph == null:
		ph = HandPhone.new()
		ph.name = "HandPhone"
		ph.chibi = c
		c.add_child(ph)
	return ph

func _ready() -> void:
	top_level = true
	visible = false
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = SIZE
	body.mesh = bm
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("f08aa6")
	dark.roughness = 0.6
	body.material_override = dark
	add_child(body)
	var screen := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(SIZE.x - 0.008, SIZE.y - 0.012, 0.002)
	screen.mesh = sm
	screen.position = Vector3(0, 0, SIZE.z * 0.5 + 0.001)
	var lit := StandardMaterial3D.new()
	lit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lit.albedo_color = Color("dbeaff")
	screen.material_override = lit
	add_child(screen)
	var skel: Skeleton3D = chibi.skel
	_hand_l = skel.find_bone("Hand_L")
	_hand_r = skel.find_bone("Hand_R")
	_head = skel.find_bone("Head")

func _process(_delta: float) -> void:
	if not shown or _hand_r < 0:
		return
	var skel: Skeleton3D = chibi.skel
	var g := skel.global_transform
	var l := g * skel.get_bone_global_pose(_hand_l)
	var r := g * skel.get_bone_global_pose(_hand_r)
	var head := (g * skel.get_bone_global_pose(_head)).origin
	var across := r.origin - l.origin
	var pos: Vector3
	var x: Vector3
	if across.length() < BOTH:
		pos = l.origin.lerp(r.origin, 0.5)
		x = across.normalized()
	else:
		pos = r.origin + r.basis.y.normalized() * 0.045
		x = r.basis.x.normalized()
	var face := head - pos
	face = (face - x * face.dot(x)).normalized()
	var y := face.cross(x).normalized()
	global_transform = Transform3D(Basis(x, y, face), pos + face * 0.012)
