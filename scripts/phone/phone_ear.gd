class_name PhoneEar
extends SkeletonModifier3D

const CLIP := "Wait_ScratchHead"
const AT := 20.0 / 66.0
const ARM := ["Clavicle_R", "Arm_1_R", "Arm_2_R", "Wrist_R"]
const SIZE := Vector3(0.095, 0.15, 0.017)
const ALONG := 0.075
const OUT := 0.035
const FADE := 4.0

var chibi: Chibi
var on_call := false
var poses := {}
var _phone: Node3D
var _wrist := -1
var _head := -1

static func on(c: Chibi) -> PhoneEar:
	"""The chibi's call pose (made the first time; null if it has no Wait_ScratchHead)."""
	var e := c.skel.get_node_or_null("PhoneEar") as PhoneEar
	if e == null and c.anim != null and c.anim.has_animation(CLIP):
		e = PhoneEar.new()
		e.name = "PhoneEar"
		e.chibi = c
		c.skel.add_child(e)
	return e

func _ready() -> void:
	var skel := get_skeleton()
	var clip: Animation = chibi.anim.get_animation(CLIP)
	var t := clip.length * AT
	for i in clip.get_track_count():
		if clip.track_get_type(i) != Animation.TYPE_ROTATION_3D:
			continue
		var bone := String(clip.track_get_path(i).get_concatenated_subnames())
		if bone.ends_with("_R") and (bone.begins_with("Finger_") or bone in ARM):
			var bi := skel.find_bone(bone)
			if bi >= 0:
				poses[bi] = clip.rotation_track_interpolate(i, t)
	_wrist = skel.find_bone("Wrist_R")
	_head = skel.find_bone("Head")
	_phone = _make_phone()
	add_child(_phone)
	influence = 0.0
	active = false

func _make_phone() -> Node3D:
	var root := Node3D.new()
	root.top_level = true
	root.visible = false
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = SIZE
	body.mesh = bm
	var case_ := StandardMaterial3D.new()
	case_.albedo_color = Color("f08aa6")
	case_.roughness = 0.6
	body.material_override = case_
	root.add_child(body)
	var screen := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(SIZE.x - 0.008, SIZE.y - 0.012, 0.002)
	screen.mesh = sm
	screen.position = Vector3(0, 0, SIZE.z * 0.5 + 0.001)
	var lit := StandardMaterial3D.new()
	lit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lit.albedo_color = Color("dbeaff")
	screen.material_override = lit
	root.add_child(screen)
	return root

func _process(delta: float) -> void:
	influence = move_toward(influence, 1.0 if on_call else 0.0, delta * FADE)
	active = influence > 0.0
	_phone.visible = influence > 0.6

func _process_modification() -> void:
	var skel := get_skeleton()
	for bi in poses:
		skel.set_bone_pose_rotation(bi, poses[bi])
	if _wrist < 0 or not _phone.visible:
		return
	var g := skel.global_transform
	var w := g * skel.get_bone_global_pose(_wrist)
	var head := (g * skel.get_bone_global_pose(_head)).origin
	var up := w.basis.y.normalized()
	var pos := w.origin + up * ALONG
	var face := head - pos
	face = (face - up * face.dot(up)).normalized()
	var x := up.cross(face).normalized()
	_phone.global_transform = Transform3D(Basis(x, up, face), pos - face * OUT)
