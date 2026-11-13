#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <vector>

namespace godot {

class Apiary : public RefCounted {
	GDCLASS(Apiary, RefCounted)

	struct Bee {
		int hive = 0;
		int state = 0;
		Vector3 from, to;
		float t = 0.0f, dur = 1.0f;
		float wait = 0.0f;
		float phase = 0.0f, radius = 0.4f, height = 0.5f, spin = 1.0f;
		Vector3 last;
	};
	std::vector<Bee> bees;
	PackedVector3Array hives;
	PackedVector3Array flowers;
	std::vector<float> calm_left, anger_left;
	std::vector<Vector3> anger_at;
	uint32_t seed = 0x9E3779B9u;

	float rnd();
	float rnd(float a, float b) { return a + (b - a) * rnd(); }
	void pick_flower(Bee &b);

protected:
	static void _bind_methods();

public:
	static String honey_of(const String &crop);
	static bool flowering(const String &crop, int stage, int stages);
	static Dictionary night(float fill, const Dictionary &cells);
	static int jars(const Dictionary &cells);
	static float range();

	void set_hives(const PackedVector3Array &entrances);
	void set_flowers(const PackedVector3Array &points);
	int add_bee(int hive);
	void clear_bees();
	int bee_count() const { return (int)bees.size(); }
	void calm(int hive, float secs);
	void anger(int hive, const Vector3 &at, float secs);
	bool is_calm(int hive) const;
	void step(double delta, const Array &nodes);
};

}
