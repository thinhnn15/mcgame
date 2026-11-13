#pragma once

#include <godot_cpp/classes/skeleton3d.hpp>
#include <godot_cpp/classes/skeleton_modifier3d.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <vector>

namespace godot {

class HairPhysics : public SkeletonModifier3D {
	GDCLASS(HairPhysics, SkeletonModifier3D)

	struct Chain {
		PackedInt32Array bones;
		std::vector<Transform3D> rests;
		std::vector<float> lens;
		float k[3];
		std::vector<Vector3> tgt, p, pp;
	};

	uint64_t body_id = 0;
	uint64_t chibi_id = 0;
	int root = -1;
	int body_head = -1;
	Vector3 head_c_local;
	std::vector<Chain> chains;
	bool was_seen = false;

	void setup(Skeleton3D *sk);

protected:
	static void _bind_methods();

public:
	static constexpr float HEAD_R = 0.36f;

	void set_body(Object *p_body);
	Object *get_body() const;
	void set_chibi(Object *p_chibi);
	Object *get_chibi() const;

	virtual void _process_modification_with_delta(double p_delta) override;
};

}
