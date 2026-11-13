#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <cstdint>
#include <vector>

namespace godot {

class DuckFlock : public RefCounted {
	GDCLASS(DuckFlock, RefCounted)

	enum State { SWIM = 0, HOME, RAMP_IN, IN, RAMP_OUT };
	struct Duck {
		int state = SWIM;
		Vector3 p, goal;
		float yaw = 0.0f, s = 0.0f, late = 0.0f, hop = 0.0f;
		float swim = 0.2f, walk = 0.216f;
		String hop_clip, clip = "Swim";
		bool shown = true;
	};
	std::vector<Duck> ducks;
	std::vector<Vector3> ramp;
	std::vector<float> acc;
	Vector2 pond_c, pond_r = Vector2(1, 1);
	float water_y = 0.0f, roost = 18.2f, wake = 6.0f, gap = 0.7f;
	float free_at = 0.0f, last_h = -1.0f, feed_t = 0.0f;
	Vector3 feed_at;
	bool fed = false;
	int eggs_n = 0;
	uint32_t seed = 0x6C8E9CF5u;

	float rnd();
	Vector3 on_pond(float u, float v) const;
	float length() const { return acc.empty() ? 0.0f : acc.back(); }
	Vector3 sample(float s) const;
	bool night_for(const Duck &d, float h) const { return h >= roost + d.late || h < wake; }
	float swim_to(Duck &d, const Vector3 &to, float delta, float k);
	Vector3 queue_spot(int i) const;
	bool first_waiting(int i) const;

protected:
	static void _bind_methods();

public:
	static constexpr int EGGS_MAX = 4;
	void setup(const PackedVector3Array &ramp_pts, const Vector2 &c, const Vector2 &r, float wy,
			const PackedFloat32Array &swim, const PackedFloat32Array &walk, const PackedStringArray &hops,
			float roost_h, float wake_h, float gap_s);
	void snap(float hour);
	void step(double delta, float hour, float now);
	Vector3 pos(int i) const { return i >= 0 && i < int(ducks.size()) ? ducks[i].p : Vector3(); }
	float yaw(int i) const { return i >= 0 && i < int(ducks.size()) ? ducks[i].yaw : 0.0f; }
	String clip(int i) const { return i >= 0 && i < int(ducks.size()) ? ducks[i].clip : String("Idle"); }
	bool shown(int i) const { return i >= 0 && i < int(ducks.size()) && ducks[i].shown; }
	int count() const { return int(ducks.size()); }
	String feed(const Vector3 &at);
	void night();
	void take_egg() { eggs_n = eggs_n > 0 ? eggs_n - 1 : 0; }
	int eggs() const { return eggs_n; }
	bool is_fed() const { return fed; }
	Dictionary to_dict() const;
	void from_dict(const Dictionary &d);
};

}
