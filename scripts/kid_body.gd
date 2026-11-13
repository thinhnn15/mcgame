class_name KidBody
extends SkeletonModifier3D

var head_scale := 1.0
var _head := -1

func _process_modification() -> void:
	var skel := get_skeleton()
	if _head < 0:
		_head = skel.find_bone("Head")
	if _head < 0 or is_equal_approx(head_scale, 1.0):
		return
	skel.set_bone_pose_scale(_head, skel.get_bone_pose_scale(_head) * head_scale)
