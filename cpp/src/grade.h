#pragma once

#include <godot_cpp/classes/environment.hpp>
#include <godot_cpp/classes/image_texture3d.hpp>
#include <godot_cpp/classes/ref_counted.hpp>

#include <atomic>
#include <vector>

namespace godot {

class Grade : public RefCounted {
	GDCLASS(Grade, RefCounted)

public:

	struct Look {
		Color shadow, highlight;
		float amount = 0.0f, sat = 1.0f, contrast = 1.0f, lift = 0.0f, gamma = 1.0f, warm = 0.0f, green_sat = 1.0f;
	};

private:
	struct State {
		Ref<Environment> env;
		Ref<ImageTexture3D> tex;
		Look base;
		Look built;
		bool has_built = false;
		Look held;
		bool has_hold = false;
		float hold_w = 0.0f, hold_to = 0.0f, hold_speed = 1.0f;
		int64_t task = -1;
		Look pending;
		std::vector<uint8_t> result;
		std::atomic<bool> result_ready{ false };
		bool connected = false;
		uint64_t last_usec = 0;
	};
	static State *s;

	static Look compose();
	static void tick();
	static void build_job();
	static TypedArray<Image> images(const std::vector<uint8_t> &data);
	static void ensure_ticker();

protected:
	static void _bind_methods();

public:
	static constexpr int SIZE = 33;

	static void init();
	static void finish();

	static bool enabled();
	static void attach(const Ref<Environment> &env);
	static void update(const Ref<Environment> &env, double hour, double wet);
	static void hold(const String &preset, double secs = 2.0);
	static void release(double secs = 3.0);

	static void build_lut(const Look &p, std::vector<uint8_t> &out);
	static PackedByteArray lut_for(double hour, double wet);
};

}
