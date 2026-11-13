#pragma once

#include <godot_cpp/classes/skeleton3d.hpp>
#include <godot_cpp/classes/skeleton_modifier3d.hpp>
#include <vector>

namespace godot {

class SkirtFollow : public SkeletonModifier3D {
	GDCLASS(SkirtFollow, SkeletonModifier3D)

	struct Chain {
		int bone, leg, knee, b2, b3;
		int ring;
		Basis rest_local, r1, r2, r3;
		Vector3 d3, d0, out, down, leg_axis, shin_axis;
		bool front;
		bool at_side = false;
		Vector3 d2, rest_pos;
		int parent = -1;
		bool shifted = false;
		Vector3 cur, vel;

		Vector3 prev_cur, hem, hem_v;
	};

	bool lap = false;
	bool long_hem = false;
	bool set_up = false;
	bool hem_wave = true;
	bool seat_on = true;
	float seat_lift = 0.0f;
	float seated = 0.0f;
	int waist = -1;
	std::vector<Chain> chains;
	Vector3 prev_pos, prev_vel;
	Basis prev_basis;
	bool have_prev_basis = false;
	bool started = false;

	void setup(Skeleton3D *sk);

protected:
	static void _bind_methods();

public:
	void set_lap(bool v) { lap = v; }
	bool get_lap() const { return lap; }
	void set_long_hem(bool v) { long_hem = v; }
	bool get_long_hem() const { return long_hem; }
	float get_seated() const { return seated; }

	void set_seat_lift(float v) { seat_lift = v; }
	float get_seat_lift() const { return seat_lift; }

	virtual void _process_modification_with_delta(double p_delta) override;
};

}
