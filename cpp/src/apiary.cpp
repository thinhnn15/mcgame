#include "apiary.h"

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>

#include <cmath>

using namespace godot;

namespace {
const float RANGE = 9.0f;
const float BASE = 1.0f / 6.0f;
const float BEST = 1.0f / 3.0f;
const float FULL_AT = 9.0f;

const char *GOURDS[] = {"bi_do", "bi_dao", "bau", "muop", "dua_chuot", "dua_hau", "muop_dang", "su_su"};
const char *BLOOMS[] = {"ca_chua", "ot", "ca_tim", "ca_phao", "lac", "dau_dua", "cuc_van_tho", "hoa_muoi_gio", "xoai",
		"oi", "khe", "du_du", "mit", "chanh", "cam", "hong_xiem", "na", "roi"};
const char *FLOWERS[] = {"huong_duong", "cuc_van_tho", "hoa_muoi_gio"};

template <size_t N>
bool in(const String &s, const char *(&list)[N]) {
	for (size_t i = 0; i < N; i++) {
		if (s == list[i]) {
			return true;
		}
	}
	return false;
}
}

float Apiary::range() { return RANGE; }

String Apiary::honey_of(const String &crop) {
	if (crop == "nhan" || crop == "vai" || crop == "huong_duong") {
		return crop;
	}
	if (in(crop, GOURDS)) {
		return "bi";
	}
	if (in(crop, BLOOMS)) {
		return "bach_hoa";
	}
	return "";
}

bool Apiary::flowering(const String &crop, int stage, int stages) {
	if (honey_of(crop).is_empty() || stages < 5) {
		return false;
	}
	if (in(crop, FLOWERS)) {
		return stage >= stages - 2;
	}
	return stage == 2 || stage == 3;
}

Dictionary Apiary::night(float fill, const Dictionary &cells) {
	float n = 0.0f;
	String best;
	float best_n = 0.0f;
	Array keys = cells.keys();
	for (int i = 0; i < keys.size(); i++) {
		float c = (float)cells[keys[i]];
		n += c;
		if (c > best_n) {
			best_n = c;
			best = keys[i];
		}
	}
	float rate = BASE + (BEST - BASE) * Math::min(n, FULL_AT) / FULL_AT;
	Dictionary out;
	out["fill"] = Math::min(1.0f, fill + rate);
	out["kind"] = (n > 0.0f && best_n >= 0.6f * n) ? best : String("bach_hoa");
	return out;
}

int Apiary::jars(const Dictionary &cells) {
	float n = 0.0f;
	int kinds = 0;
	Array keys = cells.keys();
	for (int i = 0; i < keys.size(); i++) {
		float c = (float)cells[keys[i]];
		n += c;
		kinds += c > 0.0f ? 1 : 0;
	}
	return 1 + (kinds >= 3 ? 1 : 0) + (n >= 12.0f ? 1 : 0);
}

float Apiary::rnd() {
	seed ^= seed << 13;
	seed ^= seed >> 17;
	seed ^= seed << 5;
	return (seed & 0xFFFFFF) / float(0x1000000);
}

void Apiary::set_hives(const PackedVector3Array &entrances) {
	hives = entrances;
	calm_left.resize(hives.size(), 0.0f);
	anger_left.resize(hives.size(), 0.0f);
	anger_at.resize(hives.size(), Vector3());
}

void Apiary::set_flowers(const PackedVector3Array &points) {
	flowers = points;
}

int Apiary::add_bee(int hive) {
	Bee b;
	b.hive = hive;
	b.phase = rnd(0.0f, 6.2831853f);
	b.radius = rnd(0.25f, 0.6f);
	b.height = rnd(0.15f, 0.6f);
	b.spin = rnd(0.8f, 1.4f) * (rnd() < 0.5f ? -1.0f : 1.0f);
	b.wait = rnd(0.5f, 6.0f);
	bees.push_back(b);
	return (int)bees.size() - 1;
}

void Apiary::clear_bees() {
	bees.clear();
}

void Apiary::calm(int hive, float secs) {
	if (hive >= 0 && hive < (int)calm_left.size()) {
		calm_left[hive] = secs;
	}
}

bool Apiary::is_calm(int hive) const {
	return hive >= 0 && hive < (int)calm_left.size() && calm_left[hive] > 0.0f;
}

void Apiary::anger(int hive, const Vector3 &at, float secs) {
	if (hive >= 0 && hive < (int)anger_left.size()) {
		anger_left[hive] = secs;
		anger_at[hive] = at;
	}
}

void Apiary::pick_flower(Bee &b) {
	const Vector3 h = hives[b.hive];
	int tries = 6;
	while (tries-- > 0 && flowers.size() > 0) {
		Vector3 f = flowers[(int)(rnd() * flowers.size()) % flowers.size()];
		if (Vector2(f.x - h.x, f.z - h.z).length() <= RANGE) {
			b.state = 1;
			b.from = b.last;
			b.to = f + Vector3(rnd(-0.12f, 0.12f), rnd(0.0f, 0.15f), rnd(-0.12f, 0.12f));
			b.t = 0.0f;
			b.dur = Math::max(0.6f, b.from.distance_to(b.to) / rnd(1.1f, 1.6f));
			return;
		}
	}
	b.wait = rnd(2.0f, 5.0f);
}

void Apiary::step(double delta, const Array &nodes) {
	const float dt = (float)delta;
	for (size_t i = 0; i < calm_left.size(); i++) {
		calm_left[i] = Math::max(0.0f, calm_left[i] - dt);
		anger_left[i] = Math::max(0.0f, anger_left[i] - dt);
	}
	const int n = Math::min((int)bees.size(), (int)nodes.size());
	for (int i = 0; i < n; i++) {
		Bee &b = bees[i];
		Node3D *node = Object::cast_to<Node3D>(nodes[i]);
		if (node == nullptr || b.hive >= hives.size()) {
			continue;
		}
		const Vector3 h = hives[b.hive];
		const bool calm_ = calm_left[b.hive] > 0.0f;
		const bool angry = anger_left[b.hive] > 0.0f;
		Vector3 p = b.last;
		b.phase += dt * b.spin * (angry ? 5.0f : (calm_ ? 0.5f : 1.6f));
		if (angry) {
			const Vector3 c = anger_at[b.hive];
			p = c + Vector3(std::cos(b.phase) * 0.38f, 1.05f + b.height * 0.5f + 0.06f * std::sin(b.phase * 3.1f),
					std::sin(b.phase) * 0.38f);
			p = b.last.is_zero_approx() ? p : b.last.lerp(p, Math::min(1.0f, dt * 8.0f));
			b.state = 3;
			b.from = p;
			b.t = 0.0f;
			b.dur = 1.2f;
			b.to = h;
		} else if (b.state == 0 || (calm_ && b.state != 3)) {
			if (calm_ && b.state != 0) {
				b.state = 3;
				b.from = b.last;
				b.to = h;
				b.t = 0.0f;
				b.dur = Math::max(0.8f, b.last.distance_to(h) / 0.8f);
			} else {
				const float r = b.radius * (calm_ ? 0.55f : 1.0f);
				p = h + Vector3(std::cos(b.phase) * r, b.height * (calm_ ? 0.5f : 1.0f) + 0.05f * std::sin(b.phase * 2.3f),
						std::sin(b.phase) * r * 0.8f + r * 0.45f);
				b.wait -= dt;
				if (b.wait <= 0.0f && !calm_) {
					b.last = p;
					pick_flower(b);
				}
			}
		} else if (b.state == 1 || b.state == 3) {
			b.t += dt / b.dur;
			const float s = Math::smoothstep(0.0f, 1.0f, Math::min(b.t, 1.0f));
			const float arc = Math::min(0.6f, b.from.distance_to(b.to) * 0.12f);
			p = b.from.lerp(b.to, s) + Vector3(std::sin(b.phase * 7.0f) * 0.03f, std::sin(3.14159265f * s) * arc, std::cos(b.phase * 6.0f) * 0.03f);
			if (b.t >= 1.0f) {
				if (b.state == 1) {
					b.state = 2;
					b.wait = rnd(2.0f, 5.0f);
				} else {
					b.state = 0;
					b.wait = rnd(4.0f, 10.0f);
				}
			}
		} else {
			p = b.to + Vector3(std::sin(b.phase * 4.0f) * 0.05f, 0.04f * std::sin(b.phase * 5.0f), std::cos(b.phase * 3.0f) * 0.05f);
			b.wait -= dt;
			if (b.wait <= 0.0f) {
				b.state = 3;
				b.from = p;
				b.to = h + Vector3(rnd(-0.2f, 0.2f), rnd(0.1f, 0.4f), rnd(0.2f, 0.5f));
				b.t = 0.0f;
				b.dur = Math::max(0.6f, b.from.distance_to(b.to) / rnd(1.1f, 1.6f));
			}
		}
		const Vector3 mv = p - b.last;
		if (!b.last.is_zero_approx() && Vector2(mv.x, mv.z).length() > 1e-4f) {
			node->set_rotation(Vector3(0.0f, std::atan2(mv.x, mv.z), 0.0f));
		}
		node->set_position(p);
		b.last = p;
	}
}

void Apiary::_bind_methods() {
	ClassDB::bind_static_method("Apiary", D_METHOD("honey_of", "crop"), &Apiary::honey_of);
	ClassDB::bind_static_method("Apiary", D_METHOD("flowering", "crop", "stage", "stages"), &Apiary::flowering);
	ClassDB::bind_static_method("Apiary", D_METHOD("night", "fill", "cells"), &Apiary::night);
	ClassDB::bind_static_method("Apiary", D_METHOD("jars", "cells"), &Apiary::jars);
	ClassDB::bind_static_method("Apiary", D_METHOD("range"), &Apiary::range);
	ClassDB::bind_method(D_METHOD("set_hives", "entrances"), &Apiary::set_hives);
	ClassDB::bind_method(D_METHOD("set_flowers", "points"), &Apiary::set_flowers);
	ClassDB::bind_method(D_METHOD("add_bee", "hive"), &Apiary::add_bee);
	ClassDB::bind_method(D_METHOD("clear_bees"), &Apiary::clear_bees);
	ClassDB::bind_method(D_METHOD("bee_count"), &Apiary::bee_count);
	ClassDB::bind_method(D_METHOD("calm", "hive", "secs"), &Apiary::calm);
	ClassDB::bind_method(D_METHOD("anger", "hive", "at", "secs"), &Apiary::anger);
	ClassDB::bind_method(D_METHOD("is_calm", "hive"), &Apiary::is_calm);
	ClassDB::bind_method(D_METHOD("step", "delta", "nodes"), &Apiary::step);
}
