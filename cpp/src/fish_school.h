#pragma once

#include <godot_cpp/classes/multi_mesh.hpp>
#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <vector>

namespace godot {

class FishSchool : public Node3D {
	GDCLASS(FishSchool, Node3D)

public:
	static constexpr float FAR = 32.0f;

private:
	enum State { CRUISE, HANG, RISE, FLEE, BAIT };

	struct KindRow {
		float cruise, dart, turn;
		bool schools;
		float deep, peck;
		Vector2 size;
	};
	struct KindDraw {
		String name;
		KindRow row;
		Ref<MultiMesh> mm;
		Transform3D xf;
		float len = 1.0f;
	};
	struct Fish {
		Dictionary d;
		int id = 0;
		int kind = 0;
		Vector3 pos, goal, offset, bait;
		float yaw = 0, pitch = 0, speed = 0, t = 0, ph = 0, amp = 0.6f, bow = 0, size = 1, peck = 0, gap = 0;
		int lead = -1, slot = 0;
		State state = CRUISE;
		bool there = false;
	};

	Vector2 centre;
	Vector2 radii = Vector2(2, 2);
	float water_y = 0.0f;
	Callable floor_at;
	uint64_t scarer_id = 0;
	float scare_r = 1.5f;
	float shallow = 0.0f;
	Array fish_arr;
	std::vector<Fish> fish;
	std::vector<KindDraw> kinds;
	uint64_t fx_id = 0;
	Vector3 last_scarer;
	bool has_last_scarer = false;
	int next_id = 1;

	static KindRow kind_row(const String &kind);
	int kind_index(const String &kind);
	int make_kind(const String &kind);
	int count(int kind) const;
	int index_of(const Dictionary &f) const;
	Vector3 spot(float deep);
	float e(const Vector3 &p) const;
	float floor_y(float x, float z);
	void bolt(Fish &f, const Vector3 &from);
	void steer(Fish &f, float delta, const Vector3 *s, bool s_moving);
	void draw_all();
	void set_state(Fish &f, State s);
	static const char *state_name(State s);

protected:
	static void _bind_methods();

public:
	static Object *make(Node *parent, const Vector2 &centre, const Vector2 &radii, float water, const Callable &floor_fn, const Array &kinds);

	void set_centre(const Vector2 &v) { centre = v; }
	Vector2 get_centre() const { return centre; }
	void set_radii(const Vector2 &v) { radii = v; }
	Vector2 get_radii() const { return radii; }
	void set_water_y(float v) { water_y = v; }
	float get_water_y() const { return water_y; }
	void set_floor_at(const Callable &c) { floor_at = c; }
	Callable get_floor_at() const { return floor_at; }
	void set_scarer(Object *o);
	Object *get_scarer() const;
	void set_scare_r(float v) { scare_r = v; }
	float get_scare_r() const { return scare_r; }
	void set_shallow(float v) { shallow = v; }
	float get_shallow() const { return shallow; }
	Array get_fish() const { return fish_arr; }

	void add_kind(const String &kind, int n);
	void scare(const Vector3 &at, float r = 1.5f);
	float cm_of(const Dictionary &f) const;
	Array near(const Vector3 &at, float r) const;
	void lure(const Dictionary &f, const Vector3 &at);
	void let_go(const Dictionary &f);
	Dictionary take(const Dictionary &f);
	void reset(const Array &kinds);

	void _ready() override;
	void _process(double delta) override;
};

}
