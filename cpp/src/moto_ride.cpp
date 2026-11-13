#include "moto_ride.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>

#include <cmath>

using namespace godot;

namespace {
const float TOP_V = 6.0f;
const float BOOST_V = 8.5f;
const float ACCEL = 4.0f;
const float BRAKE = 7.0f;
const float COAST = 2.2f;
const float TURN_R = 2.6f;
const float SPIN_TURN = 2.2f;
const float LEAN_MAX = 0.32f;
const float WHEEL_R = 0.2f;
const float PI_F = 3.14159265f;

float wrap(float a) {
	while (a > PI_F) {
		a -= 2.0f * PI_F;
	}
	while (a < -PI_F) {
		a += 2.0f * PI_F;
	}
	return a;
}
}

void MotoRide::reset(float heading_) {
	heading = heading_;
	speed = 0.0f;
	lean = 0.0f;
	yaw_rate = 0.0f;
}

Dictionary MotoRide::step(double delta, const Vector2 &input, const Vector3 &cam_forward, bool boost) {
	const float dt = Math::min((float)delta, 0.1f);
	Vector3 fwd(cam_forward.x, 0.0f, cam_forward.z);
	fwd = fwd.length() > 1e-4f ? fwd.normalized() : Vector3(0, 0, -1);
	const Vector3 right = fwd.cross(Vector3(0, 1, 0));
	Vector3 want = right * input.x - fwd * input.y;
	const float push = Math::min(want.length(), 1.0f);
	float target_rate = 0.0f;
	float top = (boost ? BOOST_V : TOP_V) * push;
	if (cap > 0.0f) {
		top = Math::min(top, cap);
	}
	if (push > 0.1f) {
		want /= want.length();
		const float diff = wrap(std::atan2(want.x, want.z) - heading);

		const float max_rate = speed > 0.8f ? speed / TURN_R : SPIN_TURN;
		target_rate = Math::clamp(diff * 3.0f, -max_rate, max_rate);
		if (std::abs(diff) > 2.0f) {
			top = 0.0f;
		}
	}
	yaw_rate = Math::lerp(yaw_rate, target_rate, 1.0f - std::exp(-dt * 8.0f));
	if (speed > 0.05f || push > 0.1f) {
		heading = wrap(heading + yaw_rate * dt);
	}
	if (top > speed) {
		speed = Math::min(top, speed + ACCEL * dt);
	} else {
		speed = Math::max(top, speed - (push > 0.1f ? BRAKE : COAST) * dt);
	}

	const float want_lean = Math::clamp(std::atan(speed * yaw_rate / 9.8f) * 1.4f, -LEAN_MAX, LEAN_MAX);
	lean = Math::lerp(lean, want_lean, 1.0f - std::exp(-dt * 6.0f));
	Dictionary out;
	out["velocity"] = Vector3(std::sin(heading), 0.0f, std::cos(heading)) * speed;
	out["heading"] = heading;
	out["lean"] = -lean;
	out["spin"] = speed * dt / WHEEL_R;
	out["speed"] = speed;
	return out;
}

void MotoRide::_bind_methods() {
	ClassDB::bind_method(D_METHOD("reset", "heading"), &MotoRide::reset);
	ClassDB::bind_method(D_METHOD("step", "delta", "input", "cam_forward", "boost"), &MotoRide::step);
	ClassDB::bind_method(D_METHOD("get_speed"), &MotoRide::get_speed);
	ClassDB::bind_method(D_METHOD("get_heading"), &MotoRide::get_heading);
	ClassDB::bind_method(D_METHOD("stop"), &MotoRide::stop);
	ClassDB::bind_method(D_METHOD("set_cap", "metres_per_second"), &MotoRide::set_cap);
}
