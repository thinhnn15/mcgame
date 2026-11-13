#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <cstdint>
#include <vector>

namespace godot {

class FarmCritters : public RefCounted {
	GDCLASS(FarmCritters, RefCounted)

	enum Kind { SPARROW = 0, FROG, VISITOR };
	enum State { GROUND = 0, TAKEOFF, FLY, LAND, PERCH, BANK, LEAP, SWIM, AWAY, ARRIVE, SETTLED, LEAVE };
	struct Critter {
		int kind = SPARROW, state = GROUND;
		Vector3 p, a, b, home, water, perch;
		float yaw = 0.0f, t = 0.0f, dur = 1.0f, wait = 1.0f, apex = 0.6f;
		bool to_perch = false, want = false, shown = true, moving = false;
		String clip = "Idle", event;
	};
	std::vector<Critter> cs;
	std::vector<Vector3> ground, perches;
	uint32_t seed = 0x2F6B1D93u;

	float rnd();
	static float flat(const Vector3 &a, const Vector3 &b);
	void face(Critter &c, const Vector3 &to, float k);
	void flight(Critter &c, const Vector3 &to, float speed, float apex);
	Vector3 pick(const std::vector<Vector3> &from, const Vector3 &hero, float clear, const Vector3 &near) ;
	void flush(int i, const Vector3 &hero);
	void step_sparrow(Critter &c, int i, float dt, const Vector3 &hero, float hero_speed);
	void step_frog(Critter &c, float dt, const Vector3 &hero, float hero_speed);
	void step_visitor(Critter &c, float dt);

protected:
	static void _bind_methods();

public:
	void set_ground(const PackedVector3Array &spots);
	void set_perches(const PackedVector3Array &pts);
	int add_sparrow(const Vector3 &at);
	int add_frog(const Vector3 &bank, const Vector3 &water);
	int add_visitor();
	void set_perch(int i, const Vector3 &at, bool want);
	void step(double delta, const Vector3 &hero, float hero_speed);
	Vector3 pos(int i) const { return ok(i) ? cs[i].p : Vector3(); }
	float yaw(int i) const { return ok(i) ? cs[i].yaw : 0.0f; }
	String clip(int i) const { return ok(i) ? cs[i].clip : String("Idle"); }
	bool shown(int i) const { return ok(i) && cs[i].shown; }
	String state_name(int i) const;
	String take_event(int i);
	int count() const { return int(cs.size()); }
	bool ok(int i) const { return i >= 0 && i < int(cs.size()); }
};

}
