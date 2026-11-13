class_name ItemFollow
extends SkeletonModifier3D

var item := -1
var wrist := -1

func setup(skel: Skeleton3D) -> void:
	item = skel.find_bone("Item")
	wrist = skel.find_bone("Wrist_R")

func _process_modification() -> void:
	var skel := get_skeleton()
	if item < 0 or wrist < 0:
		return
	var g := skel.get_bone_global_pose(wrist) * skel.get_bone_global_rest(wrist).affine_inverse() * skel.get_bone_global_rest(item)
	var parent := skel.get_bone_parent(item)
	var local := g if parent < 0 else skel.get_bone_global_pose(parent).affine_inverse() * g
	skel.set_bone_pose_position(item, local.origin)
	skel.set_bone_pose_rotation(item, local.basis.get_rotation_quaternion())
