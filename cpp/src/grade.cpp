#include "grade.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/classes/worker_thread_pool.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/callable_method_pointer.hpp>

#include <algorithm>
#include <cmath>

using namespace godot;

Grade::State *Grade::s = nullptr;

namespace {

struct Key {
	float hour;
	Grade::Look look;
};

Color hex(const char *h) { return Color::html(h); }

const Key *keys(int &n) {
	static const Key K[] = {
		{ 4.5f, { hex("666a90"), hex("8a9ccc"), 0.15f, 1.12f, 0.98f, 0.03f, 1.0f, 0.05f, 1.0f } },
		{ 5.3f, { hex("7a6aa8"), hex("e8b8a8"), 0.26f, 1.0f, 1.00f, 0.02f, 1.0f, 0.02f, 1.0f } },
		{ 6.0f, { hex("6a8aa0"), hex("f0dcc0"), 0.16f, 1.03f, 1.00f, 0.0f, 1.0f, 0.0f, 1.0f } },
		{ 8.0f, { hex("7a7aa6"), hex("8a8580"), 0.12f, 1.04f, 1.0f, 0.0f, 1.0f, 0.0f, 1.0f } },
		{ 16.0f, { hex("7a7aa6"), hex("8a8580"), 0.12f, 1.04f, 1.0f, 0.0f, 1.0f, 0.0f, 1.0f } },
		{ 17.6f, { hex("5f74b0"), hex("ff9868"), 0.19f, 1.08f, 1.04f, 0.0f, 1.03f, 0.0f, 0.86f } },
		{ 18.5f, { hex("7a5a9a"), hex("f29a7a"), 0.20f, 1.16f, 1.0f, 0.0f, 1.08f, 0.03f, 1.0f } },
		{ 19.1f, { hex("6a6698"), hex("c08aa8"), 0.18f, 1.04f, 0.99f, 0.03f, 1.04f, 0.04f, 1.0f } },
		{ 19.8f, { hex("666a90"), hex("8a9ccc"), 0.15f, 1.12f, 0.98f, 0.03f, 1.0f, 0.05f, 1.0f } },
	};
	n = (int)(sizeof(K) / sizeof(K[0]));
	return K;
}

const Grade::Look &rain() {
	static const Grade::Look R{ hex("707a88"), hex("a0a8b0"), 0.25f, 0.86f, 0.96f, 0.02f, 1.0f, 0.0f, 1.0f };
	return R;
}

int preset_index(const String &p) {
	if (p == "sunset") return 6;
	if (p == "noon") return 3;
	if (p == "morning") return 2;
	if (p == "night") return 0;
	return 5;
}

inline float lerpf(float a, float b, float t) { return a + (b - a) * t; }
inline float smooth(float a, float b, float x) {
	float t = std::clamp((x - a) / (b - a), 0.0f, 1.0f);
	return t * t * (3.0f - 2.0f * t);
}

Grade::Look mix(const Grade::Look &a, const Grade::Look &b, float t) {
	Grade::Look r;
	r.shadow = a.shadow.lerp(b.shadow, t);
	r.highlight = a.highlight.lerp(b.highlight, t);
	r.amount = lerpf(a.amount, b.amount, t);
	r.sat = lerpf(a.sat, b.sat, t);
	r.contrast = lerpf(a.contrast, b.contrast, t);
	r.lift = lerpf(a.lift, b.lift, t);
	r.gamma = lerpf(a.gamma, b.gamma, t);
	r.warm = lerpf(a.warm, b.warm, t);
	r.green_sat = lerpf(a.green_sat, b.green_sat, t);
	return r;
}

bool differs(const Grade::Look &a, const Grade::Look &b) {
	auto dc = [](const Color &x, const Color &y) {
		return std::fabs(x.r - y.r) + std::fabs(x.g - y.g) + std::fabs(x.b - y.b) > 0.012f;
	};
	auto df = [](float x, float y) { return std::fabs(x - y) > 0.004f; };
	return dc(a.shadow, b.shadow) || dc(a.highlight, b.highlight) || df(a.amount, b.amount) || df(a.sat, b.sat) ||
			df(a.contrast, b.contrast) || df(a.lift, b.lift) || df(a.gamma, b.gamma) || df(a.warm, b.warm) ||
			df(a.green_sat, b.green_sat);
}

Grade::Look for_hour(float h) {
	int n = 0;
	const Key *K = keys(n);
	if (h < K[0].hour || h >= K[n - 1].hour) {
		return K[n - 1].look;
	}
	for (int i = 0; i < n - 1; ++i) {
		if (h < K[i + 1].hour) {
			float t = (h - K[i].hour) / (K[i + 1].hour - K[i].hour);
			return mix(K[i].look, K[i + 1].look, t * t * (3.0f - 2.0f * t));
		}
	}
	return K[n - 1].look;
}

struct V3 {
	float x, y, z;
	V3 operator+(const V3 &o) const { return { x + o.x, y + o.y, z + o.z }; }
	V3 operator-(const V3 &o) const { return { x - o.x, y - o.y, z - o.z }; }
	V3 operator*(float k) const { return { x * k, y * k, z * k }; }
	float dot(const V3 &o) const { return x * o.x + y * o.y + z * o.z; }
	float operator[](int i) const { return i == 0 ? x : (i == 1 ? y : z); }
};
const V3 LUMA{ 0.2126f, 0.7152f, 0.0722f };
inline V3 grey(float l) { return { l, l, l }; }
inline V3 lerp3(const V3 &a, const V3 &b, float t) { return a + (b - a) * t; }

V3 chroma(const Color &c) {
	V3 v{ c.r, c.g, c.b };
	return v - grey(v.dot(LUMA));
}

float skin(const V3 &c) {
	float mx = std::max(c.x, std::max(c.y, c.z));
	float mn = std::min(c.x, std::min(c.y, c.z));
	if (mx <= 0.0f || mx - mn < 0.02f) {
		return 0.0f;
	}
	float s = (mx - mn) / mx;
	float hue;
	if (mx == c.x) {
		float q = std::fmod((c.y - c.z) / (mx - mn), 6.0f);
		hue = (q < 0.0f ? q + 6.0f : q) * 60.0f;
	} else if (mx == c.y) {
		hue = ((c.z - c.x) / (mx - mn) + 2.0f) * 60.0f;
	} else {
		hue = ((c.x - c.y) / (mx - mn) + 4.0f) * 60.0f;
	}
	float wh = smooth(5.0f, 15.0f, hue) * (1.0f - smooth(40.0f, 55.0f, hue));
	float ws = smooth(0.08f, 0.18f, s) * (1.0f - smooth(0.55f, 0.75f, s));
	float wv = smooth(0.3f, 0.5f, mx);
	return wh * ws * wv;
}

V3 fit(const V3 &c) {
	float l = std::clamp(c.dot(LUMA), 0.0f, 1.0f);
	float t = 1.0f;
	for (int i = 0; i < 3; ++i) {
		float v = c[i];
		if (v > 1.0f && v - l > 1e-5f) {
			t = std::min(t, (1.0f - l) / (v - l));
		} else if (v < 0.0f && l - v > 1e-5f) {
			t = std::min(t, l / (l - v));
		}
	}
	return lerp3(grey(l), c, std::clamp(t, 0.0f, 1.0f));
}

inline uint8_t byte(float v) { return (uint8_t)std::clamp((int)std::lround(v * 255.0f), 0, 255); }

}

void Grade::_bind_methods() {
	ClassDB::bind_static_method("Grade", D_METHOD("enabled"), &Grade::enabled);
	ClassDB::bind_static_method("Grade", D_METHOD("attach", "env"), &Grade::attach);
	ClassDB::bind_static_method("Grade", D_METHOD("update", "env", "hour", "wet"), &Grade::update);
	ClassDB::bind_static_method("Grade", D_METHOD("hold", "preset", "secs"), &Grade::hold, DEFVAL(2.0));
	ClassDB::bind_static_method("Grade", D_METHOD("release", "secs"), &Grade::release, DEFVAL(3.0));
	ClassDB::bind_static_method("Grade", D_METHOD("lut_for", "hour", "wet"), &Grade::lut_for);
}

void Grade::init() {
	if (s == nullptr) {
		s = memnew(State);
		s->base = for_hour(12.0f);
	}
}

void Grade::finish() {
	if (s == nullptr) {
		return;
	}
	if (s->task >= 0) {
		WorkerThreadPool::get_singleton()->wait_for_task_completion(s->task);
	}
	memdelete(s);
	s = nullptr;
}

bool Grade::enabled() {
	OS *os = OS::get_singleton();
	return os->get_environment("MC_LOOK_OLD").is_empty() && !os->get_cmdline_user_args().has("--no-grade");
}

void Grade::attach(const Ref<Environment> &env) {
	if (s == nullptr || env.is_null()) {
		return;
	}
	s->env = env;
	if (s->tex.is_null()) {
		Look p = compose();
		std::vector<uint8_t> data;
		build_lut(p, data);
		s->tex.instantiate();
		s->tex->create(Image::FORMAT_RGB8, SIZE, SIZE, SIZE, false, images(data));
		s->built = p;
		s->has_built = true;
	}
	env->set_adjustment_enabled(true);
	env->set_adjustment_color_correction(s->tex);
	ensure_ticker();
}

void Grade::update(const Ref<Environment> &env, double hour, double wet) {
	if (s == nullptr) {
		return;
	}
	if (env != s->env) {
		attach(env);
	}
	s->base = mix(for_hour((float)hour), rain(), (float)wet * 0.7f);
}

void Grade::hold(const String &preset, double secs) {
	if (s == nullptr) {
		return;
	}
	int n = 0;
	s->held = keys(n)[preset_index(preset)].look;
	s->has_hold = true;
	s->hold_to = 1.0f;
	s->hold_speed = 1.0f / (float)std::max(secs, 0.01);
	ensure_ticker();
}

void Grade::release(double secs) {
	if (s == nullptr) {
		return;
	}
	s->hold_to = 0.0f;
	s->hold_speed = 1.0f / (float)std::max(secs, 0.01);
}

Grade::Look Grade::compose() {
	Look p = s->base;
	if (s->hold_w > 0.0f && s->has_hold) {
		float w = s->hold_w * s->hold_w * (3.0f - 2.0f * s->hold_w);
		p = mix(p, s->held, w);
	}
	return p;
}

void Grade::tick() {
	if (s == nullptr) {
		return;
	}
	uint64_t now = Time::get_singleton()->get_ticks_usec();
	float delta = s->last_usec == 0 ? 0.0f : std::min((now - s->last_usec) / 1e6f, 0.25f);
	s->last_usec = now;
	float step = delta * s->hold_speed;
	if (s->hold_w < s->hold_to) {
		s->hold_w = std::min(s->hold_w + step, s->hold_to);
	} else if (s->hold_w > s->hold_to) {
		s->hold_w = std::max(s->hold_w - step, s->hold_to);
	}
	WorkerThreadPool *pool = WorkerThreadPool::get_singleton();
	if (s->task >= 0 && pool->is_task_completed(s->task)) {
		pool->wait_for_task_completion(s->task);
		s->task = -1;
		if (s->tex.is_valid() && s->result_ready.load() && s->result.size() == (size_t)SIZE * SIZE * SIZE * 3) {
			s->tex->update(images(s->result));
			s->built = s->pending;
			s->has_built = true;
		}
	}
	if (s->task < 0 && s->env.is_valid() && s->tex.is_valid()) {
		Look want = compose();
		if (!s->has_built || differs(want, s->built)) {
			s->pending = want;
			s->result_ready.store(false);
			s->task = pool->add_task(callable_mp_static(&Grade::build_job), false, "grade lut");
		}
	}
}

void Grade::build_job() {
	if (s == nullptr) {
		return;
	}
	build_lut(s->pending, s->result);
	s->result_ready.store(true);
}

void Grade::build_lut(const Look &p, std::vector<uint8_t> &out) {
	const V3 sh = chroma(p.shadow);
	const V3 hi = chroma(p.highlight);
	const float inv = 1.0f / (float)SIZE;
	const float skin_sat = 1.0f / std::max(p.sat, 0.01f);
	out.resize((size_t)SIZE * SIZE * SIZE * 3);
	size_t i = 0;
	for (int bz = 0; bz < SIZE; ++bz) {
		for (int gy = 0; gy < SIZE; ++gy) {
			for (int rx = 0; rx < SIZE; ++rx) {
				const V3 c0{ (rx + 0.5f) * inv, (gy + 0.5f) * inv, (bz + 0.5f) * inv };
				const float l = c0.dot(LUMA);
				V3 c = lerp3(grey(l), c0, p.sat);
				if (p.green_sat != 1.0f && c0.y > c0.x && c0.y > c0.z) {
					float gw = smooth(0.0f, 0.15f, c0.y - std::max(c0.x, c0.z));
					c = lerp3(grey(l), c, lerpf(1.0f, p.green_sat, gw));
				}
				c = (c - grey(0.5f)) * p.contrast + grey(0.5f);
				const float sk = skin(c0);
				const float k = p.amount * (1.0f - 0.85f * sk);
				const float ws = (1.0f - l) * (1.0f - smooth(0.3f, 0.6f, l));
				float wh = l * (1.0f - smooth(0.9f, 1.0f, l));
				const float mx = std::max(c0.x, std::max(c0.y, c0.z));
				const float s0 = (mx - std::min(c0.x, std::min(c0.y, c0.z))) / std::max(mx, 1e-4f);
				wh *= smooth(0.02f, 0.12f, s0);
				c = c + (sh * ws + hi * wh) * k;
				if (p.gamma != 1.0f) {
					float lg = c.dot(LUMA);
					if (lg > 1e-4f) {
						c = c * (std::pow(std::clamp(lg, 0.0f, 1.0f), 1.0f / p.gamma) / lg);
					}
				}
				c = c + V3{ 1.0f, 0.2f, -0.8f } * (p.warm * sk);

				const float ls = c.dot(LUMA);
				c = lerp3(grey(ls), c, lerpf(1.0f, skin_sat, sk * 0.8f));
				const float lf = p.lift * (1.0f - 0.9f * sk);
				c = grey(lf) + c * (1.0f - lf);
				c = fit(c);
				out[i] = byte(c.x);
				out[i + 1] = byte(c.y);
				out[i + 2] = byte(c.z);
				i += 3;
			}
		}
	}
}

PackedByteArray Grade::lut_for(double hour, double wet) {
	std::vector<uint8_t> data;
	build_lut(mix(for_hour((float)hour), rain(), (float)wet * 0.7f), data);
	PackedByteArray out;
	out.resize((int64_t)data.size());
	std::copy(data.begin(), data.end(), out.ptrw());
	return out;
}

TypedArray<Image> Grade::images(const std::vector<uint8_t> &data) {
	TypedArray<Image> list;
	const int64_t slice = (int64_t)SIZE * SIZE * 3;
	for (int z = 0; z < SIZE; ++z) {
		PackedByteArray bytes;
		bytes.resize(slice);
		std::copy(data.begin() + z * slice, data.begin() + (z + 1) * slice, bytes.ptrw());
		list.append(Image::create_from_data(SIZE, SIZE, false, Image::FORMAT_RGB8, bytes));
	}
	return list;
}

void Grade::ensure_ticker() {
	if (s->connected) {
		return;
	}
	SceneTree *tree = Object::cast_to<SceneTree>(Engine::get_singleton()->get_main_loop());
	if (tree == nullptr) {
		return;
	}
	tree->connect("process_frame", callable_mp_static(&Grade::tick));
	s->connected = true;
}
