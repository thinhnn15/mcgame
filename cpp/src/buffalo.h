#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace godot {

class Buffalo : public RefCounted {
	GDCLASS(Buffalo, RefCounted)

protected:
	static void _bind_methods();

public:
	static Vector3 rope_point(const PackedVector3Array &trail, double rope);
	static Dictionary seek(const Vector3 &me, double yaw, const Vector3 &goal, bool moving, double delta, const Dictionary &cfg);
	static Dictionary ride(double yaw, double speed, const Vector3 &dir, double delta, const Dictionary &cfg);
	static Vector3 graze_spot(const Vector3 &centre, double radius, int seed);
	static String plan(double hour, const String &state, bool on_hill, bool rain, const Dictionary &cfg);
	static int credit(Dictionary log, const String &act, int day, const Dictionary &cfg);
};

}
