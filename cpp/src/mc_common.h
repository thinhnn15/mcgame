#pragma once

#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/script.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/variant.hpp>

namespace mc {
using namespace godot;

struct Scripts {
	static Ref<Script> wind, clock, story, fish_table, swim_fx, hero;

	static Ref<Script> get(Ref<Script> &slot, const char *path) {
		if (slot.is_null()) {
			slot = ResourceLoader::get_singleton()->load(path);
		}
		return slot;
	}
	static Ref<Script> wind_gd() { return get(wind, "res://scripts/wind.gd"); }
	static Ref<Script> clock_gd() { return get(clock, "res://scripts/home/clock.gd"); }
	static Ref<Script> story_gd() { return get(story, "res://scripts/story.gd"); }
	static Ref<Script> fish_table_gd() { return get(fish_table, "res://scripts/farm/fish_table.gd"); }
	static Ref<Script> swim_fx_gd() { return get(swim_fx, "res://scripts/farm/swim_fx.gd"); }
	static void release() {
		wind.unref();
		clock.unref();
		story.unref();
		fish_table.unref();
		swim_fx.unref();
		hero.unref();
	}
};

struct Wind {
	static constexpr float BASE = 1.2f;
	static constexpr float GUST = 2.4f;
	static constexpr float LEAN = 0.04f;

	static float strength() {
		Ref<Script> w = Scripts::wind_gd();
		return w.is_valid() ? (float)(double)w->get("strength") : 0.0f;
	}

	static float gust_at(const Vector3 &at);
	static Vector3 force(const Vector3 &at, float strength) {
		if (strength <= 0.0f) {
			return Vector3();
		}
		const Vector3 dir = Vector3(0.94f, 0.0f, 0.33f).normalized();
		double t = Time::get_singleton()->get_ticks_msec() / 1000.0;
		float gust = 0.2f + 0.8f * gust_at(at);
		float flutter = Math::sin(t * 6.3 + at.x * 2.1 + at.z * 1.3) * 0.25f;
		return dir * strength * (BASE + GUST * gust) * (1.0f + flutter);
	}
};

inline float wrapf(float v, float lo, float hi) {
	float r = hi - lo;
	return r == 0.0f ? lo : v - r * Math::floor((v - lo) / r);
}

inline float move_toward(float from, float to, float delta) {
	return Math::abs(to - from) <= delta ? to : from + Math::sign(to - from) * delta;
}

inline float clampf(float v, float lo, float hi) {
	return v < lo ? lo : (v > hi ? hi : v);
}

inline Quaternion turn(const Vector3 &from, const Vector3 &to) {
	if (from.length_squared() < 1e-10f || to.length_squared() < 1e-10f) {
		return Quaternion();
	}
	return Quaternion(from.normalized(), to.normalized());
}
}
