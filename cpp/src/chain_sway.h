#pragma once

#include <godot_cpp/classes/mesh.hpp>
#include <godot_cpp/classes/skeleton3d.hpp>
#include <godot_cpp/classes/skeleton_modifier3d.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <vector>

namespace godot {

class ChainSway : public SkeletonModifier3D {
	GDCLASS(ChainSway, SkeletonModifier3D)

	struct Chain {
		String name;
		PackedInt32Array joints;
		int parent = -1;
		float k[3];
		bool active = false;
		bool restart = false;
		bool lap = false;
		std::vector<Vector3> tgt, p, pp;
	};

	std::vector<Chain> chains;
	bool dirty = true;
	bool set_up = false;
	int b_root = -1, b_neck = -1, b_head = -1;
	PackedInt32Array legs;
	std::vector<Vector3> leg_pts;
	float torso_len = 1.0f;
	Vector3 head_c_local;
	bool was_seen = false;

	void setup(Skeleton3D *sk);
	void match_parts(Skeleton3D *sk);
	static PackedInt32Array weighted_binds(const Ref<Mesh> &mesh);
	static Vector3 push_capsule(const Vector3 &q, const Vector3 &a, const Vector3 &b, float r, bool up = false);

protected:
	static void _bind_methods();

public:
	static Object *attach(Skeleton3D *sk);
	static bool wears(Skeleton3D *sk, const String &chain);
	void mark(Node *n);
	bool is_dirty() const { return dirty; }

	virtual void _process_modification_with_delta(double p_delta) override;
};

}
