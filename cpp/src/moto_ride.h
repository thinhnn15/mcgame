#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace godot {

class MotoRide : public RefCounted {
	GDCLASS(MotoRide, RefCounted)

	float speed = 0.0f;
	float heading = 0.0f;
	float lean = 0.0f;
	float yaw_rate = 0.0f;
	float cap = 0.0f;

protected:
	static void _bind_methods();

public:
	void reset(float heading_);
	Dictionary step(double delta, const Vector2 &input, const Vector3 &cam_forward, bool boost);
	float get_speed() const { return speed; }
	float get_heading() const { return heading; }
	void stop() { speed = 0.0f; yaw_rate = 0.0f; }
	void set_cap(float v) { cap = v; }
};

}
