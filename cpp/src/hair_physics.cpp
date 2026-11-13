#include "hair_physics.h"
#include "mc_common.h"

#include <godot_cpp/classes/camera3d.hpp>
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/viewport.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/object.hpp>

using namespace godot;

static const float BANGS[3] = { 0.45f, 0.25f, 0.15f };
static const float BY_LENGTH[4][3] = { { 0.28f, 0.18f, 0.3f }, { 0.28f, 0.18f, 0.3f }, { 0.2f, 0.15f, 0.35f }, { 0.12f, 0.1f, 0.5f } };
static const Vector3 HEAD_C(0.0f, 1.19f, -0.07f);
static const Vector3 GRAVITY(0.0f, -9.8f, 0.0f);

void HairPhysics::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_body", "body"), &HairPhysics::set_body);
	ClassDB::bind_method(D_METHOD("get_body"), &HairPhysics::get_body);
	ClassDB::bind_method(D_METHOD("set_chibi", "chibi"), &HairPhysics::set_chibi);
	ClassDB::bind_method(D_METHOD("get_chibi"), &HairPhysics::get_chibi);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "body", PROPERTY_HINT_NODE_TYPE, "Skeleton3D"), "set_body", "get_body");
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "chibi", PROPERTY_HINT_NODE_TYPE, "Node"), "set_chibi", "get_chibi");
}

void HairPhysics::set_body(Object *p_body) {
	body_id = p_body ? p_body->get_instance_id() : 0;
	root = -1;
}

Object *HairPhysics::get_body() const {
	return body_id ? ObjectDB::get_instance(body_id) : nullptr;
}

void HairPhysics::set_chibi(Object *p_chibi) {
	chibi_id = p_chibi ? p_chibi->get_instance_id() : 0;
}

Object *HairPhysics::get_chibi() const {
	return chibi_id ? ObjectDB::get_instance(chibi_id) : nullptr;
}

void HairPhysics::setup(Skeleton3D *sk) {
	chains.clear();
	root = sk->find_bone("Root");
	Skeleton3D *body = Object::cast_to<Skeleton3D>(get_body());
	body_head = body ? body->find_bone("Head") : -1;
	if (root < 0) {
		return;
	}
	head_c_local = sk->get_bone_global_rest(root).affine_inverse().xform(HEAD_C);
	int count = sk->get_bone_count();
	for (int i = 0; i < count; i++) {
		String n = sk->get_bone_name(i);
		if (sk->get_bone_parent(i) != root || !(n.begins_with("Bangs") || n.begins_with("Hair_"))) {
			continue;
		}
		PackedInt32Array bones;
		bones.push_back(i);
		int tip = -1;
		int cur = i;
		while (tip < 0) {
			PackedInt32Array kids = sk->get_bone_children(cur);
			if (kids.is_empty()) {
				break;
			}
			int nxt = kids[0];
			if (sk->get_bone_name(nxt).begins_with("Z_")) {
				tip = nxt;
			} else {
				bones.push_back(nxt);
				cur = nxt;
			}
		}
		if (tip < 0) {
			continue;
		}
		Chain c;
		c.bones = bones;
		for (int j = 0; j < bones.size(); j++) {
			c.rests.push_back(sk->get_bone_rest(bones[j]));
		}
		c.rests.push_back(sk->get_bone_rest(tip));
		for (size_t k = 1; k < c.rests.size(); k++) {
			c.lens.push_back(c.rests[k].origin.length());
		}
		const float *kind = n.begins_with("Bangs") ? BANGS : BY_LENGTH[MIN((int)bones.size(), 3)];
		c.k[0] = kind[0];
		c.k[1] = kind[1];
		c.k[2] = kind[2];
		c.tgt.assign(c.rests.size(), Vector3());
		c.p = c.tgt;
		c.pp = c.tgt;
		chains.push_back(c);
	}
}

void HairPhysics::_process_modification_with_delta(double p_delta) {
	Skeleton3D *sk = get_skeleton();
	if (sk == nullptr) {
		return;
	}
	if (root < 0) {
		setup(sk);
		if (root < 0) {
			return;
		}
	}

	Transform3D head_g = sk->get_bone_global_rest(root);
	Skeleton3D *body = Object::cast_to<Skeleton3D>(get_body());
	if (body && body_head >= 0) {

		Object *chibi = get_chibi();
		head_g = chibi ? (Transform3D)chibi->call("final_pose", body_head) : body->get_bone_global_pose(body_head);
	}
	sk->set_bone_pose_position(root, head_g.origin);
	sk->set_bone_pose_rotation(root, head_g.basis.get_rotation_quaternion());
	sk->set_bone_pose_scale(root, head_g.basis.get_scale());
	Transform3D w = sk->get_global_transform();
	Vector3 head_c = w.xform(head_g.xform(head_c_local));
	Camera3D *cam = sk->get_viewport() ? sk->get_viewport()->get_camera_3d() : nullptr;
	bool seen = cam == nullptr || cam->is_position_in_frustum(head_c) || cam->get_global_position().distance_to(head_c) < 1.5f;
	if (!seen) {
		was_seen = false;
		return;
	}
	bool restart = !was_seen;
	was_seen = true;
	float dt = mc::clampf((float)p_delta, 1.0f / 240.0f, 1.0f / 20.0f);
	Transform3D winv = w.affine_inverse();
	float wind_strength = mc::Wind::strength();
	for (Chain &c : chains) {
		const size_t n = c.tgt.size();
		Transform3D g = head_g;
		for (size_t j = 0; j < n; j++) {
			g = g * c.rests[j];
			c.tgt[j] = w.xform(g.origin);
		}
		if (restart) {
			c.p = c.tgt;
			c.pp = c.tgt;
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
			Vector3 d = cur - c.p[i - 1];
			cur = c.p[i - 1] + d.normalized() * c.lens[i - 1];
			Vector3 off = cur - head_c;
			if (off.length() < HEAD_R) {
				cur = head_c + off.normalized() * HEAD_R;
				d = cur - c.p[i - 1];
				cur = c.p[i - 1] + d.normalized() * c.lens[i - 1];
			}
			c.p[i] = cur;
		}
		Transform3D parent_g = head_g;
		for (int bi = 0; bi < c.bones.size(); bi++) {
			Transform3D dflt = parent_g * c.rests[bi];
			Vector3 dir_now = dflt.basis.xform(c.rests[bi + 1].origin);
			Vector3 want = winv.xform(c.p[bi + 1]) - dflt.origin;
			Quaternion q = want.length() > 1e-5f ? mc::turn(dir_now, want) : Quaternion();
			Transform3D new_g(Basis(q) * dflt.basis, dflt.origin);
			sk->set_bone_pose_rotation(c.bones[bi], (parent_g.affine_inverse() * new_g).basis.get_rotation_quaternion());
			parent_g = new_g;
		}
	}
}
