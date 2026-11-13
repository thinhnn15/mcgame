class_name Lod
extends RefCounted

const DETAIL_AT := 15.0
const NPC_HIDE_AT := 70.0
const MARGIN := 2.0

const NPC_LOD_BIAS := 1.0
const DETAIL := ["Nose_", "_Trim"]

const FACE := ["mEye", "mMouth", "mBrow", "mCheek", "mPaint"]

static func npc(chibi: Node3D, hide_far := true) -> void:
	for g: GeometryInstance3D in chibi.find_children("*", "GeometryInstance3D", true, false):
		var n := String(g.name)
		var end := NPC_HIDE_AT if hide_far else 0.0
		if _any(n, DETAIL):
			end = DETAIL_AT
		if _any(n, DETAIL) or _any(n, FACE) or _small(g):
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.visibility_range_end = end
		g.visibility_range_end_margin = MARGIN if end > 0.0 else 0.0
		if hide_far:
			var env := OS.get_environment("MC_NPC_LOD_BIAS")
			g.lod_bias = float(env) if env != "" else NPC_LOD_BIAS

static func _any(n: String, keys: Array) -> bool:
	for k: String in keys:
		if n.contains(k):
			return true
	return false

static func _small(g: GeometryInstance3D) -> bool:
	return g.get_aabb().size.length() < 0.3
