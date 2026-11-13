class_name GripOverride
extends SkeletonModifier3D

const ARM := ["Arm_1_R", "Arm_2_R", "Wrist_R"]
var poses := {}

func setup(clip: Animation, skel: Skeleton3D) -> void:
	poses.clear()
	for i in clip.get_track_count():
		if clip.track_get_type(i) != Animation.TYPE_ROTATION_3D:
			continue
		var bone := String(clip.track_get_path(i).get_concatenated_subnames())
		if bone.ends_with("_R") and (bone.begins_with("Finger_") or bone in ARM):
			var bi := skel.find_bone(bone)
			if bi >= 0:
				poses[bi] = clip.rotation_track_interpolate(i, 0.0)

func _process_modification() -> void:
	var skel := get_skeleton()
	for bi in poses:
		skel.set_bone_pose_rotation(bi, poses[bi])
