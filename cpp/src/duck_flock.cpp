#include "duck_flock.h"

#include <godot_cpp/core/class_db.hpp>

#include <algorithm>
#include <cmath>

using namespace godot;

void DuckFlock::_bind_methods() {
	ClassDB::bind_method(D_METHOD("setup", "ramp", "pond_c", "pond_r", "water_y", "swim", "walk", "hops", "roost", "wake",
								 "gap"),
			&DuckFlock::setup);
	ClassDB::bind_method(D_METHOD("snap", "hour"), &DuckFlock::snap);
	ClassDB::bind_method(D_METHOD("step", "delta", "hour", "now"), &DuckFlock::step);
	ClassDB::bind_method(D_METHOD("pos", "i"), &DuckFlock::pos);
	ClassDB::bind_method(D_METHOD("yaw", "i"), &DuckFlock::yaw);
	ClassDB::bind_method(D_METHOD("clip", "i"), &DuckFlock::clip);
	ClassDB::bind_method(D_METHOD("shown", "i"), &DuckFlock::shown);
	ClassDB::bind_method(D_METHOD("count"), &DuckFlock::count);
	ClassDB::bind_method(D_METHOD("feed", "at"), &DuckFlock::feed);
	ClassDB::bind_method(D_METHOD("night"), &DuckFlock::night);
	ClassDB::bind_method(D_METHOD("take_egg"), &DuckFlock::take_egg);
	ClassDB::bind_method(D_METHOD("eggs"), &DuckFlock::eggs);
	ClassDB::bind_method(D_METHOD("is_fed"), &DuckFlock::is_fed);
	ClassDB::bind_method(D_METHOD("to_dict"), &DuckFlock::to_dict);
	ClassDB::bind_method(D_METHOD("from_dict", "d"), &DuckFlock::from_dict);
}

float DuckFlock::rnd() {
	seed ^= seed << 13;
	seed ^= seed >> 17;
	seed ^= seed << 5;
	return float(seed & 0xffffffu) / float(0x1000000);
}

Vector3 DuckFlock::on_pond(float u, float v) const {
	const float ang = u * 6.2831853f;
	const float r = std::sqrt(v) * 0.55f;
	return Vector3(pond_c.x + std::cos(ang) * pond_r.x * r, water_y, pond_c.y + std::sin(ang) * pond_r.y * r);
}

Vector3 DuckFlock::sample(float s) const {
	if (ramp.empty()) return Vector3();
	if (s <= 0.0f) return ramp.front();
	for (size_t i = 1; i < ramp.size(); i++) {
		if (s <= acc[i]) {
			const float seg = acc[i] - acc[i - 1];
			const float t = seg > 1e-6f ? (s - acc[i - 1]) / seg : 1.0f;
			return ramp[i - 1].lerp(ramp[i], t);
		}
	}
	return ramp.back();
}

void DuckFlock::setup(const PackedVector3Array &ramp_pts, const Vector2 &c, const Vector2 &r, float wy,
		const PackedFloat32Array &swim, const PackedFloat32Array &walk, const PackedStringArray &hops, float roost_h,
		float wake_h, float gap_s) {
	ramp.clear();
	acc.clear();
	for (int i = 0; i < ramp_pts.size(); i++) {
		ramp.push_back(ramp_pts[i]);
		acc.push_back(i == 0 ? 0.0f : acc.back() + ramp_pts[i].distance_to(ramp_pts[i - 1]));
	}
	pond_c = c;
	pond_r = r;
	water_y = wy;
	roost = roost_h;
	wake = wake_h;
	gap = gap_s;
	ducks.clear();
	for (int i = 0; i < swim.size(); i++) {
		Duck d;
		d.swim = swim[i];
		d.walk = i < walk.size() ? walk[i] : 0.216f;
		d.hop_clip = i < hops.size() ? hops[i] : String("Hop");
		d.late = 0.03f * float(i);
		d.p = on_pond(rnd(), rnd());
		d.goal = d.p;
		d.yaw = rnd() * 6.2831853f;
		ducks.push_back(d);
	}
}

void DuckFlock::snap(float hour) {
	free_at = 0.0f;
	for (Duck &d : ducks) {
		if (night_for(d, hour)) {
			d.state = IN;
			d.shown = false;
		} else {
			d.state = SWIM;
			d.shown = true;
			d.p = on_pond(rnd(), rnd());
			d.goal = d.p;
			d.clip = "Swim";
		}
	}
	last_h = hour;
}

float DuckFlock::swim_to(Duck &d, const Vector3 &to, float delta, float k) {
	Vector3 v = to - d.p;
	v.y = 0.0f;
	const float dist = v.length();
	if (dist > 0.05f) {
		const Vector3 n = v / dist;
		d.p += n * std::min(d.swim * k * delta, dist);
		d.p.y = water_y;
		const float want = std::atan2(n.x, n.z);
		float dy = std::fmod(want - d.yaw + 3.14159265f * 3.0f, 6.2831853f) - 3.14159265f;
		d.yaw += dy * (1.0f - std::exp(-delta * 6.0f));
	}
	d.clip = "Swim";
	return dist;
}

Vector3 DuckFlock::queue_spot(int i) const {
	int n = 0;
	for (int j = 0; j < i; j++)
		if (ducks[j].state == HOME) n++;
	const Vector3 foot = sample(0.0f);
	Vector3 out = foot - sample(0.3f);
	out.y = 0.0f;
	out = out.length() > 1e-5f ? out.normalized() : Vector3(0, 0, 1);
	return foot + out * (0.3f * float(n));
}

bool DuckFlock::first_waiting(int i) const {
	for (int j = 0; j < i; j++)
		if (ducks[j].state == HOME) return false;
	return true;
}

void DuckFlock::step(double delta_d, float hour, float now) {
	const float delta = float(delta_d);
	if (last_h >= 0.0f && std::fabs(hour - last_h) > 0.2f) snap(hour);
	last_h = hour;
	feed_t -= delta;
	const float len = length();
	for (int i = 0; i < int(ducks.size()); i++) {
		Duck &d = ducks[i];
		const bool night = night_for(d, hour);
		switch (d.state) {
			case SWIM: {
				if (night) {
					d.state = HOME;
					break;
				}
				if (i == 0) {
					if (feed_t > 0.0f) d.goal = feed_at;
					else if (Vector2(d.p.x - d.goal.x, d.p.z - d.goal.z).length() < 0.15f) d.goal = on_pond(rnd(), rnd());
				} else {
					const Duck &mum = ducks[0];
					d.goal = mum.p + Vector3(-std::sin(mum.yaw), 0.0f, -std::cos(mum.yaw)) * (0.32f * float(i));
				}
				swim_to(d, d.goal, delta, (i == 0 ? 1.0f : 1.25f) * (feed_t > 0.0f ? 2.0f : 1.0f));
				break;
			}
			case HOME: {
				if (!night) {
					d.state = SWIM;
					break;
				}
				if (swim_to(d, queue_spot(i), delta, 1.3f) < 0.08f && first_waiting(i) && now >= free_at) {
					d.state = RAMP_IN;
					d.s = 0.0f;
					free_at = now + gap;
					d.hop = 0.5f;
					d.clip = d.hop_clip;
				}
				break;
			}
			case RAMP_IN:
			case RAMP_OUT: {
				const float dir = d.state == RAMP_IN ? 1.0f : -1.0f;
				d.s = std::clamp(d.s + dir * d.walk * delta, 0.0f, len);
				const Vector3 p = sample(d.s);
				const Vector3 ahead = sample(std::clamp(d.s + dir * 0.06f, 0.0f, len));
				const Vector3 dv = ahead - p;
				if (Vector2(dv.x, dv.z).length() > 0.004f) {
					const float want = std::atan2(dv.x, dv.z);
					float dy = std::fmod(want - d.yaw + 3.14159265f * 3.0f, 6.2831853f) - 3.14159265f;
					d.yaw += dy * (1.0f - std::exp(-delta * 10.0f));
				}
				d.p = p;
				d.hop -= delta;
				if (d.hop <= 0.0f) d.clip = d.s > 0.05f ? "Walk" : "Swim";
				if (dir > 0.0f && d.s >= len) {
					d.state = IN;
					d.shown = false;
				} else if (dir < 0.0f && d.s <= 0.0f) {
					d.state = SWIM;
					d.goal = on_pond(rnd(), rnd());
					d.clip = "Swim";
				}
				break;
			}
			case IN: {
				if (!night && now >= free_at && (i == 0 || ducks[i - 1].state != IN)) {
					d.state = RAMP_OUT;
					d.s = len;
					free_at = now + gap;
					d.p = sample(len);
					d.shown = true;
				}
				break;
			}
		}
	}
}

String DuckFlock::feed(const Vector3 &at) {
	const bool all_in = std::all_of(ducks.begin(), ducks.end(), [](const Duck &d) { return d.state == IN || d.state == HOME; });
	if (all_in) return "asleep";
	Vector2 q(at.x - pond_c.x, at.z - pond_c.y);
	const float e = std::sqrt((q.x / pond_r.x) * (q.x / pond_r.x) + (q.y / pond_r.y) * (q.y / pond_r.y));
	if (e > 0.8f) q *= 0.8f / e;
	feed_at = Vector3(pond_c.x + q.x, water_y, pond_c.y + q.y);
	feed_t = 9.0f;
	const bool first = !fed;
	fed = true;
	return first ? "first" : "again";
}

void DuckFlock::night() {
	if (fed) eggs_n = std::min(eggs_n + 1, EGGS_MAX);
	fed = false;
}

Dictionary DuckFlock::to_dict() const {
	Dictionary d;
	d["fed"] = fed;
	d["eggs"] = eggs_n;
	return d;
}

void DuckFlock::from_dict(const Dictionary &d) {
	fed = bool(d.get("fed", false));
	eggs_n = std::clamp(int(d.get("eggs", 0)), 0, EGGS_MAX);
}
