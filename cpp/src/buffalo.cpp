#include "buffalo.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/array.hpp>

using namespace godot;

namespace {

double num(const Dictionary &cfg, const char *key, double def) {
	return cfg.has(key) ? (double)cfg[key] : def;
}

double turn_to(double a, double b) {
	return Math::wrapf(b - a, -Math::PI, Math::PI);
}

Vector3 nose_of(double yaw) {
	return Vector3(Math::sin(yaw), 0.0, Math::cos(yaw));
}

}

Vector3 Buffalo::rope_point(const PackedVector3Array &trail, double rope) {
	const int n = trail.size();
	if (n == 0) {
		return Vector3();
	}
	double left = rope;
	for (int i = n - 1; i > 0; i--) {
		const Vector3 a = trail[i], b = trail[i - 1];
		const double d = Vector3(a.x - b.x, 0.0, a.z - b.z).length();
		if (d >= left && d > 1e-6) {
			return a.lerp(b, left / d);
		}
		left -= d;
	}
	return trail[0];
}

Dictionary Buffalo::seek(const Vector3 &me, double yaw, const Vector3 &goal, bool moving, double delta, const Dictionary &cfg) {
	Vector3 to = goal - me;
	to.y = 0.0;
	const double dist = to.length();
	const double start = num(cfg, "start", 0.45), stop = num(cfg, "stop", 0.12);
	if (moving ? dist < stop : dist < start) {
		moving = false;
	} else {
		moving = true;
	}
	double speed = 0.0;
	if (moving && dist > 1e-4) {
		const double want = Math::atan2(to.x, to.z);
		const double dt = turn_to(yaw, want);
		const double step = num(cfg, "turn", 1.6) * delta;
		yaw += CLAMP(dt, -step, step);

		const double along = Math::cos(turn_to(yaw, want));
		speed = MIN(num(cfg, "follow_max", 1.0), MAX(num(cfg, "walk", 0.3), dist * num(cfg, "gain", 1.2))) * MAX(0.0, along);
		speed = MIN(speed, dist / MAX(delta, 1e-4));
	}
	Dictionary out;
	out["pos"] = me + nose_of(yaw) * speed * delta;
	out["yaw"] = Math::wrapf(yaw, -Math::PI, Math::PI);
	out["speed"] = speed;
	out["moving"] = moving;
	return out;
}

Dictionary Buffalo::ride(double yaw, double speed, const Vector3 &dir, double delta, const Dictionary &cfg) {
	Vector3 d = dir;
	d.y = 0.0;
	const double push = MIN(1.0, d.length());
	double want_speed = 0.0;
	if (push > 0.1) {
		const double want = Math::atan2(d.x, d.z);
		const double dt = turn_to(yaw, want);

		const double rate = num(cfg, "ride_turn", 1.4) * (speed > 0.15 ? 1.0 : 0.7);
		yaw += CLAMP(dt, -rate * delta, rate * delta);
		want_speed = num(cfg, "ride_speed", 0.75) * push * MAX(0.0, Math::cos(turn_to(yaw, want)));
	}
	const double acc = num(cfg, "accel", 0.9) * delta;
	speed += CLAMP(want_speed - speed, -acc * 1.5, acc);
	speed = MAX(0.0, speed);
	Dictionary out;
	out["velocity"] = nose_of(yaw) * speed;
	out["yaw"] = Math::wrapf(yaw, -Math::PI, Math::PI);
	out["speed"] = speed;
	return out;
}

Vector3 Buffalo::graze_spot(const Vector3 &centre, double radius, int seed) {

	uint32_t h = (uint32_t)seed * 2654435761u;
	h ^= h >> 15;
	h *= 2246822519u;
	h ^= h >> 13;
	const double a = (h & 0xffff) / 65535.0 * Math::PI * 2.0;
	const double r = radius * (0.35 + 0.65 * ((h >> 16) & 0xffff) / 65535.0);
	return centre + Vector3(Math::cos(a) * r, 0.0, Math::sin(a) * r);
}

String Buffalo::plan(double hour, const String &state, bool on_hill, bool rain, const Dictionary &cfg) {
	if (state != "tha") {
		return "stay";
	}
	if (hour >= num(cfg, "home_at", 18.5) || hour < num(cfg, "out_from", 5.0)) {
		return "home";
	}
	const Array shade = cfg.get("shade_hours", Array());
	if (on_hill && !rain && shade.size() == 2 && hour >= (double)shade[0] && hour < (double)shade[1]) {
		return "shade";
	}
	return "graze";
}

int Buffalo::credit(Dictionary log, const String &act, int day, const Dictionary &cfg) {
	if ((int)log.get("day", -1) != day) {
		log["day"] = day;
		log["done"] = Array();
	}
	Array done = log.get("done", Array());
	if (done.has(act)) {
		return 0;
	}
	done.push_back(act);
	log["done"] = done;
	const Dictionary pts = cfg.get("friend", Dictionary());
	return (int)pts.get(act, 0);
}

void Buffalo::_bind_methods() {
	ClassDB::bind_static_method("Buffalo", D_METHOD("rope_point", "trail", "rope"), &Buffalo::rope_point);
	ClassDB::bind_static_method("Buffalo", D_METHOD("seek", "me", "yaw", "goal", "moving", "delta", "cfg"), &Buffalo::seek);
	ClassDB::bind_static_method("Buffalo", D_METHOD("ride", "yaw", "speed", "dir", "delta", "cfg"), &Buffalo::ride);
	ClassDB::bind_static_method("Buffalo", D_METHOD("graze_spot", "centre", "radius", "seed"), &Buffalo::graze_spot);
	ClassDB::bind_static_method("Buffalo", D_METHOD("plan", "hour", "state", "on_hill", "rain", "cfg"), &Buffalo::plan);
	ClassDB::bind_static_method("Buffalo", D_METHOD("credit", "log", "act", "day", "cfg"), &Buffalo::credit);
}
