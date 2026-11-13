#include "farm_critters.h"

#include <godot_cpp/core/class_db.hpp>

#include <algorithm>
#include <cmath>

using namespace godot;

namespace {
constexpr float SPARROW_FLY = 3.5f;
constexpr float SPARROW_HOP = 0.21f;
constexpr float FLUSH_WALK = 1.5f;
constexpr float FLUSH_RUN = 2.6f;
constexpr float RUN_SPEED = 2.2f;
constexpr float FLOCK = 2.2f;
constexpr float FROG_NEAR = 1.5f;
constexpr float FROG_NEAR_RUN = 2.4f;
constexpr float FROG_BACK = 3.2f;
constexpr float VISITOR_FLY = 1.4f;
constexpr float PI2 = 6.2831853f;
}

void FarmCritters::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_ground", "spots"), &FarmCritters::set_ground);
	ClassDB::bind_method(D_METHOD("set_perches", "points"), &FarmCritters::set_perches);
	ClassDB::bind_method(D_METHOD("add_sparrow", "at"), &FarmCritters::add_sparrow);
	ClassDB::bind_method(D_METHOD("add_frog", "bank", "water"), &FarmCritters::add_frog);
	ClassDB::bind_method(D_METHOD("add_visitor"), &FarmCritters::add_visitor);
	ClassDB::bind_method(D_METHOD("set_perch", "i", "at", "want"), &FarmCritters::set_perch);
	ClassDB::bind_method(D_METHOD("step", "delta", "hero", "hero_speed"), &FarmCritters::step);
	ClassDB::bind_method(D_METHOD("pos", "i"), &FarmCritters::pos);
	ClassDB::bind_method(D_METHOD("yaw", "i"), &FarmCritters::yaw);
	ClassDB::bind_method(D_METHOD("clip", "i"), &FarmCritters::clip);
	ClassDB::bind_method(D_METHOD("shown", "i"), &FarmCritters::shown);
	ClassDB::bind_method(D_METHOD("state_name", "i"), &FarmCritters::state_name);
	ClassDB::bind_method(D_METHOD("take_event", "i"), &FarmCritters::take_event);
	ClassDB::bind_method(D_METHOD("count"), &FarmCritters::count);
}

float FarmCritters::rnd() {
	seed ^= seed << 13;
	seed ^= seed >> 17;
	seed ^= seed << 5;
	return float(seed & 0xffffffu) / float(0x1000000);
}

float FarmCritters::flat(const Vector3 &a, const Vector3 &b) {
	const float dx = a.x - b.x, dz = a.z - b.z;
	return std::sqrt(dx * dx + dz * dz);
}

void FarmCritters::face(Critter &c, const Vector3 &to, float k) {
	const float dx = to.x - c.p.x, dz = to.z - c.p.z;
	if (dx * dx + dz * dz < 1e-6f) return;
	const float want = std::atan2(dx, dz);
	float d = std::fmod(want - c.yaw + 3.0f * 3.14159265f, PI2) - 3.14159265f;
	c.yaw += d * std::min(1.0f, k);
}

void FarmCritters::flight(Critter &c, const Vector3 &to, float speed, float apex) {
	c.a = c.p;
	c.b = to;
	c.apex = apex;
	c.t = 0.0f;
	c.dur = std::max(0.3f, c.a.distance_to(to) / speed);
}

Vector3 FarmCritters::pick(const std::vector<Vector3> &from, const Vector3 &hero, float clear, const Vector3 &near) {
	if (from.empty()) return near;
	Vector3 best = from[0];
	float best_d = 1e9f;
	bool found = false;
	for (int k = 0; k < 6; k++) {
		const Vector3 &q = from[size_t(rnd() * float(from.size())) % from.size()];
		if (flat(q, hero) < clear) continue;
		const float d = flat(q, near);
		if (d < best_d) {
			best_d = d;
			best = q;
			found = true;
		}
		if (found && k >= 2) break;
	}
	if (!found) {
		float far = -1.0f;
		for (const Vector3 &q : from) {
			const float d = flat(q, hero);
			if (d > far) {
				far = d;
				best = q;
			}
		}
	}
	return best;
}

void FarmCritters::set_ground(const PackedVector3Array &spots) {
	ground.assign(spots.ptr(), spots.ptr() + spots.size());
}

void FarmCritters::set_perches(const PackedVector3Array &pts) {
	perches.assign(pts.ptr(), pts.ptr() + pts.size());
}

int FarmCritters::add_sparrow(const Vector3 &at) {
	Critter c;
	c.kind = SPARROW;
	c.state = GROUND;
	c.p = c.home = at;
	c.yaw = rnd() * PI2;
	c.wait = 0.3f + rnd() * 1.5f;
	c.clip = "Peck";
	cs.push_back(c);
	return int(cs.size()) - 1;
}

int FarmCritters::add_frog(const Vector3 &bank, const Vector3 &water) {
	Critter c;
	c.kind = FROG;
	c.state = BANK;
	c.p = c.home = bank;
	c.water = water;
	c.wait = 3.0f + rnd() * 8.0f;
	c.yaw = std::atan2(water.x - bank.x, water.z - bank.z);
	cs.push_back(c);
	return int(cs.size()) - 1;
}

int FarmCritters::add_visitor() {
	Critter c;
	c.kind = VISITOR;
	c.state = AWAY;
	c.shown = false;
	c.clip = "Fly";
	c.wait = 1.0f + rnd() * 1.5f;
	cs.push_back(c);
	return int(cs.size()) - 1;
}

void FarmCritters::set_perch(int i, const Vector3 &at, bool want) {
	if (!ok(i)) return;
	cs[i].perch = at;
	cs[i].want = want;
}

String FarmCritters::take_event(int i) {
	if (!ok(i)) return String();
	String e = cs[i].event;
	cs[i].event = String();
	return e;
}

String FarmCritters::state_name(int i) const {
	static const char *names[] = {"ground", "takeoff", "fly", "land", "perch", "bank", "leap", "swim", "away", "arrive",
		"settled", "leave"};
	return ok(i) ? String(names[cs[i].state]) : String();
}

void FarmCritters::flush(int i, const Vector3 &hero) {
	const Vector3 at = cs[i].p;
	for (int j = 0; j < int(cs.size()); j++) {
		Critter &c = cs[j];
		if (c.kind != SPARROW || (c.state != GROUND && c.state != PERCH)) continue;
		if (j != i && flat(c.p, at) > FLOCK) continue;
		c.state = TAKEOFF;
		c.t = 0.0f;
		c.dur = 0.18f + (j == i ? 0.0f : rnd() * 0.3f);
		c.to_perch = true;
		c.moving = false;
		c.clip = "Takeoff";
		face(c, c.p + (c.p - hero), 1.0f);
	}
	cs[i].event = "flush";
}

void FarmCritters::step_sparrow(Critter &c, int i, float dt, const Vector3 &hero, float hero_speed) {
	const float near = hero_speed > RUN_SPEED ? FLUSH_RUN : FLUSH_WALK;
	switch (c.state) {
		case GROUND: {
			if (flat(c.p, hero) < near) {
				flush(i, hero);
				return;
			}
			if (c.moving) {
				Vector3 to = c.b - c.p;
				to.y = 0.0f;
				const float l = to.length();
				if (l < 0.02f) {
					c.moving = false;
					c.clip = "Peck";
					c.wait = 0.8f + rnd() * 1.6f;
				} else {
					c.p += to / l * std::min(l, SPARROW_HOP * dt);
					face(c, c.b, dt * 10.0f);
				}
				return;
			}
			c.wait -= dt;
			if (c.wait > 0.0f) return;
			const float r = rnd();
			if (r < 0.5f) {
				c.clip = "Peck";
				c.wait = 0.8f + rnd() * 1.4f;
			} else if (r < 0.75f) {
				c.clip = "Idle";
				c.wait = 0.8f + rnd() * 1.8f;
			} else {
				const float ang = rnd() * PI2;
				const float d = 0.12f + rnd() * 0.18f;
				Vector3 to = c.p + Vector3(std::sin(ang) * d, 0.0f, std::cos(ang) * d);
				if (flat(to, c.home) > 0.7f) to = c.home.lerp(to, 0.3f);
				to.y = c.home.y;
				c.b = to;
				c.moving = true;
				c.clip = "Walk";
			}
			return;
		}
		case TAKEOFF:
			c.t += dt;
			c.p.y += 0.5f * dt;
			if (c.t >= c.dur) {
				Vector3 to;
				if (c.to_perch) {
					to = pick(perches, hero, 3.0f, c.p);
					to += Vector3((rnd() - 0.5f) * 0.1f, 0.0f, (rnd() - 0.5f) * 0.1f);
				} else {
					to = pick(ground, hero, 3.0f, c.home);
					c.home = to;
					to += Vector3((rnd() - 0.5f) * 0.5f, 0.0f, (rnd() - 0.5f) * 0.5f);
				}
				flight(c, to, SPARROW_FLY * (0.85f + rnd() * 0.3f), c.to_perch ? 0.35f : 0.6f);
				c.state = FLY;
				c.clip = "Fly";
			}
			return;
		case FLY: {
			c.t += dt;
			const float s = std::min(1.0f, c.t / c.dur);
			c.p = c.a.lerp(c.b, s) + Vector3(0.0f, c.apex * 4.0f * s * (1.0f - s), 0.0f);
			face(c, c.b, dt * 12.0f);
			c.clip = s < 0.7f ? "Fly" : "Glide";
			if (s >= 1.0f) {
				c.p = c.b;
				c.state = LAND;
				c.t = 0.0f;
				c.dur = 0.3f;
				c.clip = "Land";
			}
			return;
		}
		case LAND:
			c.t += dt;
			if (c.t >= c.dur) {
				c.state = c.to_perch ? PERCH : GROUND;
				c.wait = c.to_perch ? 4.0f + rnd() * 5.0f : 0.6f;
				c.clip = c.to_perch ? "Idle" : "Peck";
			}
			return;
		case PERCH:
			face(c, hero, dt * 2.0f);
			if (flat(c.p, hero) < 1.0f) {
				flush(i, hero);
				return;
			}
			c.wait -= dt;
			if (c.wait <= 0.0f) {
				if (!ground.empty()) {
					c.state = TAKEOFF;
					c.t = 0.0f;
					c.dur = 0.18f;
					c.to_perch = false;
					c.clip = "Takeoff";
				} else {
					c.wait = 2.0f + rnd() * 2.0f;
				}
			}
			return;
		default:
			return;
	}
}

void FarmCritters::step_frog(Critter &c, float dt, const Vector3 &hero, float hero_speed) {
	switch (c.state) {
		case BANK: {
			face(c, c.water, dt * 3.0f);
			const float near = hero_speed > RUN_SPEED ? FROG_NEAR_RUN : FROG_NEAR;
			if (flat(c.p, hero) < near) {
				c.a = c.p;
				c.b = c.water;
				c.t = 0.0f;
				c.dur = 0.5f;
				c.apex = 0.18f;
				c.state = LEAP;
				c.clip = "Hop";
				return;
			}
			c.wait -= dt;
			if (c.wait <= 0.0f) {
				if (c.clip == "Croak") {
					c.clip = "Idle";
					c.wait = 5.0f + rnd() * 10.0f;
				} else {
					c.clip = "Croak";
					c.event = "croak";
					c.wait = 1.4f;
				}
			}
			return;
		}
		case LEAP: {
			c.t += dt;
			const float s = std::min(1.0f, c.t / c.dur);
			c.p = c.a.lerp(c.b, s) + Vector3(0.0f, c.apex * 4.0f * s * (1.0f - s), 0.0f);
			face(c, c.b, dt * 15.0f);
			if (s >= 1.0f) {
				if (c.b == c.water) {
					c.event = "splash";
					c.state = SWIM;
					c.clip = "Swim";
					c.wait = 6.0f + rnd() * 5.0f;
					c.t = 0.0f;
				} else {
					c.state = BANK;
					c.clip = "Idle";
					c.wait = 2.0f + rnd() * 6.0f;
				}
			}
			return;
		}
		case SWIM: {
			c.t += dt;
			c.p = c.water + Vector3(std::sin(c.t * 0.5f) * 0.12f, 0.0f, std::sin(c.t * 0.35f) * 0.08f);
			face(c, c.water + Vector3(std::cos(c.t * 0.5f), 0.0f, std::cos(c.t * 0.35f) * 0.6f) * 10.0f, dt * 2.0f);
			c.wait -= dt;
			if (c.wait <= 0.0f && flat(c.home, hero) > FROG_BACK) {
				c.a = c.p;
				c.b = c.home;
				c.t = 0.0f;
				c.dur = 0.55f;
				c.apex = 0.22f;
				c.state = LEAP;
				c.clip = "Hop";
			}
			return;
		}
		default:
			return;
	}
}

void FarmCritters::step_visitor(Critter &c, float dt) {
	const Vector3 hover = c.perch + Vector3(0.0f, 0.05f, 0.0f);
	switch (c.state) {
		case AWAY:
			c.shown = false;
			if (!c.want) return;
			c.wait -= dt;
			if (c.wait > 0.0f) return;
			{
				const float ang = rnd() * PI2;
				c.p = c.perch + Vector3(std::sin(ang) * 2.5f, 1.0f + rnd() * 0.5f, std::cos(ang) * 2.5f);
			}
			flight(c, hover, VISITOR_FLY, 0.2f);
			c.state = ARRIVE;
			c.shown = true;
			c.clip = "Fly";
			return;
		case ARRIVE: {
			if (!c.want) {
				c.state = LEAVE;
				flight(c, c.p + (c.p - c.perch).normalized() * 2.5f + Vector3(0.0f, 1.0f, 0.0f), VISITOR_FLY * 2.0f, 0.1f);
				return;
			}
			c.t += dt;
			c.b = hover;
			const float s = std::min(1.0f, c.t / c.dur);
			const float e = s * s * (3.0f - 2.0f * s);
			c.p = c.a.lerp(c.b, e) + Vector3(0.0f, c.apex * 4.0f * s * (1.0f - s), 0.0f);
			face(c, c.b, dt * 8.0f);
			if (s >= 1.0f) {
				c.state = LAND;
				c.t = 0.0f;
				c.dur = 0.6f;
				c.clip = "Hover";
			}
			return;
		}
		case LAND:
			c.t += dt;
			c.p = c.perch + Vector3(0.0f, 0.05f * (1.0f - std::min(1.0f, c.t / c.dur)), 0.0f);
			if (!c.want) {
				c.state = LEAVE;
				flight(c, c.p + Vector3(1.5f, 1.2f, -1.0f), VISITOR_FLY * 2.0f, 0.1f);
				c.clip = "Fly";
			} else if (c.t >= c.dur) {
				c.state = SETTLED;
				c.clip = "Idle";
			}
			return;
		case SETTLED:
			c.p = c.perch;
			if (!c.want) {
				const float ang = rnd() * PI2;
				c.state = LEAVE;
				flight(c, c.p + Vector3(std::sin(ang) * 2.5f, 1.2f, std::cos(ang) * 2.5f), VISITOR_FLY * 2.2f, 0.1f);
				c.clip = "Fly";
			}
			return;
		case LEAVE: {
			c.t += dt;
			const float s = std::min(1.0f, c.t / c.dur);
			c.p = c.a.lerp(c.b, s);
			face(c, c.b, dt * 10.0f);
			if (s >= 1.0f) {
				c.state = AWAY;
				c.shown = false;
				c.wait = 8.0f + rnd() * 8.0f;
			}
			return;
		}
		default:
			return;
	}
}

void FarmCritters::step(double delta, const Vector3 &hero, float hero_speed) {
	const float dt = float(std::min(delta, 0.1));
	for (int i = 0; i < int(cs.size()); i++) {
		Critter &c = cs[i];
		switch (c.kind) {
			case SPARROW: step_sparrow(c, i, dt, hero, hero_speed); break;
			case FROG: step_frog(c, dt, hero, hero_speed); break;
			default: step_visitor(c, dt); break;
		}
	}
}
