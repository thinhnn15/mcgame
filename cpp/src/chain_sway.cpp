#include "chain_sway.h"
#include "mc_common.h"

#include <godot_cpp/classes/camera3d.hpp>
#include <godot_cpp/classes/mesh_instance3d.hpp>
#include <godot_cpp/classes/skin.hpp>
#include <godot_cpp/classes/viewport.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/typed_array.hpp>

using namespace godot;

static const char *NAMES[] = { "Khan_L", "Khan_R", "Ta_F", "Ta_B", "Cape_L", "Cape_C", "Cape_R", "Day_L", "Day_R" };

static const float KIND_KHAN[3] = { 0.08f, 0.10f, 0.6f };
static const float KIND_TA[3] = { 0.09f, 0.12f, 0.55f };
static const float KIND_CAPE[3] = { 0.07f, 0.10f, 0.6f };
static const float KIND_DAY[3] = { 0.03f, 0.06f, 1.0f };
static const Vector3 GRAVITY(0.0f, -9.8f, 0.0f);
static const float MARGIN = 0.012f;
static const Vector3 HEAD_C(0.0f, 1.19f, -0.07f);

static const float TORSO_R = 0.155f;
static const float THIGH_R = 0.085f;
static const float SHIN_R = 0.062f;
static const float HEAD_R = 0.36f;
static const char *LEG_BONES[] = { "Leg_1_L", "Leg_2_L", "Ankle_L", "Leg_1_R", "Leg_2_R", "Ankle_R" };

void ChainSway::_bind_methods() {
	ClassDB::bind_static_method("ChainSway", D_METHOD("attach", "sk"), &ChainSway::attach);
	ClassDB::bind_static_method("ChainSway", D_METHOD("wears", "sk", "chain"), &ChainSway::wears);
	ClassDB::bind_method(D_METHOD("_mark", "node"), &ChainSway::mark);
}

Object *ChainSway::attach(Skeleton3D *sk) {
	if (sk == nullptr || sk->find_bone("Ta_F_1") < 0) {
		return nullptr;
	}
	ChainSway *c = memnew(ChainSway);
	sk->add_child(c);
	sk->connect("child_entered_tree", Callable(c, "_mark"));
	sk->connect("child_exiting_tree", Callable(c, "_mark"));
	return c;
}

void ChainSway::mark(Node *n) {
	dirty = true;
}

bool ChainSway::wears(Skeleton3D *sk, const String &chain) {

	if (sk == nullptr) {
		return false;
	}
	TypedArray<Node> kids = sk->get_children();
	for (int i = 0; i < kids.size(); i++) {
		ChainSway *c = Object::cast_to<ChainSway>(kids[i]);
		if (c == nullptr) {
			continue;
		}
		if (!c->set_up) {
			c->setup(sk);
		}
		if (c->dirty) {
			c->match_parts(sk);
		}
		for (const Chain &ch : c->chains) {
			if (ch.name == chain) {
				return ch.active;
			}
		}
	}
	return false;
}

void ChainSway::setup(Skeleton3D *sk) {
	set_up = true;
	chains.clear();
	b_root = sk->find_bone("Skl_Root");
	b_neck = sk->find_bone("Neck");
	b_head = sk->find_bone("Head");
	legs.clear();
	for (const char *n : LEG_BONES) {
		legs.push_back(sk->find_bone(n));
	}
	leg_pts.assign(legs.size(), Vector3());
	torso_len = (sk->get_bone_global_rest(b_neck).origin - sk->get_bone_global_rest(b_root).origin).length();
	head_c_local = sk->get_bone_global_rest(b_head).affine_inverse().xform(HEAD_C);
	for (const char *name : NAMES) {
		int b = sk->find_bone(String(name) + "_1");
		if (b < 0) {
			continue;
		}
		Chain c;
		c.name = name;
		c.joints.push_back(b);
		int cur = b;
		while (true) {
			PackedInt32Array kids = sk->get_bone_children(cur);
			if (kids.is_empty()) {
				break;
			}
			cur = kids[0];
			c.joints.push_back(cur);
			if (sk->get_bone_name(cur).ends_with("_Z")) {
				break;
			}
		}
		c.parent = sk->get_bone_parent(b);
		const float *k = c.name.begins_with("Khan") ? KIND_KHAN : c.name.begins_with("Ta") ? KIND_TA : c.name.begins_with("Cape") ? KIND_CAPE : KIND_DAY;
		c.k[0] = k[0];
		c.k[1] = k[1];
		c.k[2] = k[2];
		c.lap = c.name == "Ta_F";
		c.tgt.assign(c.joints.size(), Vector3());
		c.p = c.tgt;
		c.pp = c.tgt;
		chains.push_back(c);
	}
}

PackedInt32Array ChainSway::weighted_binds(const Ref<Mesh> &mesh) {

	if (mesh->has_meta("chain_binds")) {
		return mesh->get_meta("chain_binds");
	}
	std::vector<bool> used;
	for (int s = 0; s < mesh->get_surface_count(); s++) {
		Array arr = mesh->surface_get_arrays(s);
		Variant vb = arr[Mesh::ARRAY_BONES];
		Variant vw = arr[Mesh::ARRAY_WEIGHTS];
		if (vb.get_type() == Variant::NIL || vw.get_type() == Variant::NIL) {
			continue;
		}
		PackedInt32Array bones = vb;
		PackedFloat32Array weights = vw;
		int n = MIN(bones.size(), weights.size());
		for (int i = 0; i < n; i++) {
			if (weights[i] > 0.0f) {
				int b = bones[i];
				if (b >= 0) {
					if ((int)used.size() <= b) {
						used.resize(b + 1, false);
					}
					used[b] = true;
				}
			}
		}
	}
	PackedInt32Array out;
	for (size_t i = 0; i < used.size(); i++) {
		if (used[i]) {
			out.push_back((int)i);
		}
	}
	mesh->set_meta("chain_binds", out);
	return out;
}

void ChainSway::match_parts(Skeleton3D *sk) {

	Dictionary used;
	TypedArray<Node> mis = sk->find_children("*", "MeshInstance3D", true, false);
	for (int m = 0; m < mis.size(); m++) {
		MeshInstance3D *mi = Object::cast_to<MeshInstance3D>(mis[m]);
		if (mi == nullptr) {
			continue;
		}
		Ref<Skin> skin = mi->get_skin();
		Ref<Mesh> mesh = mi->get_mesh();
		if (skin.is_null() || mesh.is_null() || !mi->is_inside_tree() || mi->is_queued_for_deletion()) {
			continue;
		}
		PackedInt32Array binds = weighted_binds(mesh);
		int bind_count = skin->get_bind_count();
		for (int i = 0; i < binds.size(); i++) {
			int bi = binds[i];
			if (bi >= bind_count) {
				continue;
			}
			String bn = skin->get_bind_name(bi);
			if (bn.is_empty() && skin->get_bind_bone(bi) >= 0) {
				bn = sk->get_bone_name(skin->get_bind_bone(bi));
			}
			used[bn] = true;
		}
	}
	for (Chain &c : chains) {
		bool was = c.active;
		c.active = false;
		for (int j = 0; j < c.joints.size(); j++) {
			if (used.has(sk->get_bone_name(c.joints[j]))) {
				c.active = true;
				break;
			}
		}
		if (c.active && !was) {
			c.restart = true;
		}
		if (was && !c.active) {
			for (int j = 0; j < c.joints.size(); j++) {
				sk->reset_bone_pose(c.joints[j]);
			}
		}
	}
	dirty = false;
}

Vector3 ChainSway::push_capsule(const Vector3 &q, const Vector3 &a, const Vector3 &b, float r, bool up) {

	Vector3 ab = b - a;
	float t = mc::clampf((q - a).dot(ab) / MAX(ab.length_squared(), 1e-8f), 0.0f, 1.0f);
	Vector3 c = a + ab * t;
	Vector3 off = q - c;
	float d = off.length();
	if (d >= r) {
		return q;
	}
	if (up && off.y < 0.0f) {
		off.y = -off.y;
	}
	if (off.length() < 1e-6f) {
		off = Vector3(0, 1, 0);
	}
	return c + off.normalized() * r;
}

void ChainSway::_process_modification_with_delta(double p_delta) {
	Skeleton3D *sk = get_skeleton();
	if (sk == nullptr) {
		return;
	}
	if (!set_up) {
		setup(sk);
	}
	if (dirty) {
		match_parts(sk);
	}
	bool any = false;
	for (const Chain &c : chains) {
		any = any || c.active;
	}
	if (!any) {
		return;
	}
	Transform3D w = sk->get_global_transform();
	Vector3 hip = w.xform(sk->get_bone_global_pose(b_root).origin);
	Camera3D *cam = sk->get_viewport() ? sk->get_viewport()->get_camera_3d() : nullptr;
	bool seen = cam == nullptr || cam->is_position_in_frustum(hip) || cam->get_global_position().distance_to(hip) < 1.5f;
	if (!seen) {
		was_seen = false;
		return;
	}
	bool restart_all = !was_seen;
	was_seen = true;
	float dt = mc::clampf((float)p_delta, 1.0f / 240.0f, 1.0f / 20.0f);
	Transform3D winv = w.affine_inverse();

	Vector3 neck = w.xform(sk->get_bone_global_pose(b_neck).origin);
	float ws = w.basis.get_scale().y;
	float s = (neck - hip).length() / MAX(torso_len * ws, 1e-4f);
	for (int i = 0; i < legs.size(); i++) {
		leg_pts[i] = w.xform(sk->get_bone_global_pose(legs[i]).origin);
	}
	Transform3D head_g = sk->get_bone_global_pose(b_head);
	Vector3 head_c = w.xform(head_g.xform(head_c_local));
	float head_r = HEAD_R * head_g.basis.get_scale().y * ws;
	float torso_r = (TORSO_R + MARGIN) * s;
	float thigh_r = (THIGH_R + MARGIN) * s;
	float shin_r = (SHIN_R + MARGIN) * s;
	float floor_y = w.origin.y + MARGIN;

	Vector3 knee_mid = (leg_pts[1] + leg_pts[4]) * 0.5f;
	Vector3 hip_mid = (leg_pts[0] + leg_pts[3]) * 0.5f;
	Vector3 thigh_dir = (knee_mid - hip_mid).normalized();
	float lap_amt = Math::smoothstep(0.6f, 0.15f, thigh_dir.dot(Vector3(0, -1, 0)));
	float wind_strength = mc::Wind::strength();
	for (Chain &c : chains) {
		if (!c.active) {
			continue;
		}
		const size_t n = c.tgt.size();
		Transform3D parent_g = sk->get_bone_global_pose(c.parent);
		Transform3D g = parent_g;
		for (size_t j = 0; j < n; j++) {
			g = g * sk->get_bone_rest(c.joints[(int)j]);
			c.tgt[j] = w.xform(g.origin);
		}
		if (restart_all || c.restart) {
			c.restart = false;
			c.p = c.tgt;
			c.pp = c.tgt;
		}
		bool lap = c.lap;
		if (lap && lap_amt > 0.0f) {
			float along = 0.0f;
			for (size_t j = 1; j < n; j++) {
				along += (c.tgt[j] - c.tgt[j - 1]).length();
				c.tgt[j] = c.tgt[j].lerp(c.tgt[0] + thigh_dir * along, lap_amt);
			}
		}
		float stiff = 1.0f - Math::pow(1.0f - c.k[0], dt * 60.0f);
		float keep = Math::pow(1.0f - c.k[1], dt * 60.0f);
		Vector3 grav = GRAVITY * c.k[2] * dt * dt;

		Vector3 lean = mc::Wind::force(c.p[0], wind_strength) * mc::Wind::LEAN * c.k[2];
		c.p[0] = c.tgt[0];
		c.pp[0] = c.tgt[0];
		for (size_t i = 1; i < n; i++) {
			Vector3 cur = c.p[i];
			Vector3 vel = (cur - c.pp[i]) * keep;
			c.pp[i] = cur;
			cur += vel + grav;
			cur = cur.lerp(c.tgt[i] + lean * (float)i / (float)(n - 1), stiff);
			float seg = (c.tgt[i] - c.tgt[i - 1]).length();
			cur = c.p[i - 1] + (cur - c.p[i - 1]).normalized() * seg;
			cur = push_capsule(cur, hip, neck, torso_r);
			for (int side = 0; side < 2; side++) {
				int o = side * 3;
				cur = push_capsule(cur, leg_pts[o], leg_pts[o + 1], thigh_r, lap);
				cur = push_capsule(cur, leg_pts[o + 1], leg_pts[o + 2], shin_r, lap);
			}
			if (lap && lap_amt > 0.0f) {
				cur = push_capsule(cur, hip_mid, knee_mid, thigh_r, true);
			}
			cur.y = MAX(cur.y, floor_y);
			Vector3 off = cur - head_c;
			if (off.length() < head_r) {
				cur = head_c + off.normalized() * head_r;
			}
			cur = c.p[i - 1] + (cur - c.p[i - 1]).normalized() * seg;
			c.p[i] = cur;
		}

		Transform3D pg = parent_g;
		for (int bi = 0; bi < c.joints.size() - 1; bi++) {
			Transform3D dflt = pg * sk->get_bone_rest(c.joints[bi]);
			Vector3 dir_now = dflt.basis.xform(sk->get_bone_rest(c.joints[bi + 1]).origin);
			Vector3 want = winv.xform(c.p[bi + 1]) - dflt.origin;
			Quaternion q = (want.length() > 1e-5f && dir_now.length() > 1e-5f) ? mc::turn(dir_now, want) : Quaternion();
			Transform3D new_g(Basis(q) * dflt.basis, dflt.origin);
			sk->set_bone_pose_rotation(c.joints[bi], (pg.affine_inverse() * new_g).basis.get_rotation_quaternion());
			pg = new_g;
		}
	}
}
