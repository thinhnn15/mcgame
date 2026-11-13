#include "pen_rules.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <godot_cpp/variant/vector2.hpp>

using namespace godot;

Dictionary *PenRules::kinds = nullptr;

void PenRules::setup(const Dictionary &p_kinds) {
	if (!kinds) {
		kinds = new Dictionary();
	}
	*kinds = p_kinds.duplicate(true);
}

void PenRules::finish() {
	delete kinds;
	kinds = nullptr;
}

Dictionary PenRules::kind(const String &id) {
	return kinds ? Dictionary(kinds->get(id, Dictionary())) : Dictionary();
}

Vector2i PenRules::size_of(const String &kind_id, int rot) {
	const Dictionary k = kind(kind_id);
	const Array s = k.get("size", Array());
	Vector2i v(2, 2);
	if (s.size() >= 2) {
		v = Vector2i(int(s[0]), int(s[1]));
	}
	return (rot % 2) ? Vector2i(v.y, v.x) : v;
}

Rect2 PenRules::rect_of(const String &kind_id, const Vector2i &cell, int rot) {
	const Vector2i s = size_of(kind_id, rot);
	return Rect2(Vector2(cell) * CELL, Vector2(s) * CELL);
}

Rect2 PenRules::door_rect(const String &kind_id, const Vector2i &cell, int rot) {
	if (!(bool)kind(kind_id).get("door", false)) {
		return Rect2();
	}
	const Rect2 r = rect_of(kind_id, cell, rot);
	switch (((rot % 4) + 4) % 4) {
		case 0:
			return Rect2(r.position.x, r.get_end().y, r.size.x, DOOR);
		case 1:
			return Rect2(r.get_end().x, r.position.y, DOOR, r.size.y);
		case 2:
			return Rect2(r.position.x, r.position.y - DOOR, r.size.x, DOOR);
		default:
			return Rect2(r.position.x - DOOR, r.position.y, DOOR, r.size.y);
	}
}

String PenRules::check(const String &kind_id, const Vector2i &cell, int rot, const Dictionary &ctx) {
	if (kind(kind_id).is_empty()) {
		return "PEN_BAD_THING";
	}
	const Rect2 r = rect_of(kind_id, cell, rot).grow(-0.01f);
	const Rect2 d = door_rect(kind_id, cell, rot).grow(-0.01f);
	const bool has_door = d.has_area();
	const Rect2 bounds = ctx.get("bounds", Rect2());
	if (!bounds.encloses(r) || (has_door && !bounds.encloses(d))) {
		return "PEN_BAD_OUT";
	}
	const Array blockers = ctx.get("blockers", Array());
	for (int i = 0; i < blockers.size(); i++) {
		const Array b = blockers[i];
		if (b.size() < 2) {
			continue;
		}
		const Rect2 br = b[0];
		if (r.intersects(br) || (has_door && d.intersects(br))) {
			return String(b[1]);
		}
	}
	const Array pens = ctx.get("pens", Array());
	for (int i = 0; i < pens.size(); i++) {
		const Array p = pens[i];
		if (p.size() < 3) {
			continue;
		}
		const Rect2 pr = rect_of(p[0], p[1], int(p[2]));
		const Rect2 pd = door_rect(p[0], p[1], int(p[2]));
		if (r.intersects(pr) || (pd.has_area() && r.intersects(pd)) || (has_door && d.intersects(pr))) {
			return "PEN_BAD_PEN";
		}
	}
	const String ground = kind(kind_id).get("ground", "any");
	const Callable height = ctx.get("height", Callable());
	const Callable terrain = ctx.get("terrain", Callable());
	float lo = 1e9f, hi = -1e9f;
	const Rect2 full = rect_of(kind_id, cell, rot);
	for (float x = full.position.x; x <= full.get_end().x + 0.01f; x += CELL) {
		for (float z = full.position.y; z <= full.get_end().y + 0.01f; z += CELL) {
			if (terrain.is_valid()) {
				const String why = terrain.call(x, z, ground);
				if (!why.is_empty()) {
					return why;
				}
			}
			if (height.is_valid()) {
				const float h = height.call(x, z);
				lo = MIN(lo, h);
				hi = MAX(hi, h);
			}
		}
	}
	if (hi - lo > SLOPE) {
		return "PEN_BAD_SLOPE";
	}
	if (ctx.has("hero")) {
		const Vector2 hp = ctx["hero"];
		if (r.grow(0.3f).has_point(hp)) {
			return "PEN_BAD_HERO";
		}
	}
	return String();
}

Dictionary PenRules::room(const String &kind_id, const Array &animals) {
	const Dictionary k = kind(kind_id);
	const Dictionary holds = k.get("holds", Dictionary());
	const Array small = k.get("small", Array());
	int total = 0;
	if (holds.has("total")) {
		total = int(holds["total"]);
	} else {
		const Array keys = holds.keys();
		for (int i = 0; i < keys.size(); i++) {
			total += int(holds[keys[i]]);
		}
	}
	int big = 0;
	for (int i = 0; i < animals.size(); i++) {
		if (!small.has(animals[i])) {
			big++;
		}
	}
	Dictionary out;
	out["total"] = total;
	out["free"] = MAX(0, total - big);
	return out;
}

bool PenRules::takes(const String &kind_id, const Array &animals, const String &species) {
	const Dictionary k = kind(kind_id);
	const Dictionary holds = k.get("holds", Dictionary());
	const Array small = k.get("small", Array());
	if (small.has(species)) {
		return !holds.is_empty() || true;
	}
	if (!holds.has(species)) {
		return false;
	}
	int of_kind = 0;
	for (int i = 0; i < animals.size(); i++) {
		if (String(animals[i]) == species) {
			of_kind++;
		}
	}
	if (of_kind >= int(holds[species])) {
		return false;
	}
	return int(room(kind_id, animals)["free"]) > 0;
}

Dictionary PenRules::refund(const String &kind_id) {
	const Dictionary needs = kind(kind_id).get("needs", Dictionary());
	Dictionary out;
	const Array keys = needs.keys();
	for (int i = 0; i < keys.size(); i++) {
		const int n = int(needs[keys[i]]) / 2;
		if (n > 0) {
			out[keys[i]] = n;
		}
	}
	return out;
}

void PenRules::_bind_methods() {
	ClassDB::bind_static_method("PenRules", D_METHOD("setup", "kinds"), &PenRules::setup);
	ClassDB::bind_static_method("PenRules", D_METHOD("kind", "id"), &PenRules::kind);
	ClassDB::bind_static_method("PenRules", D_METHOD("size_of", "kind", "rot"), &PenRules::size_of);
	ClassDB::bind_static_method("PenRules", D_METHOD("rect_of", "kind", "cell", "rot"), &PenRules::rect_of);
	ClassDB::bind_static_method("PenRules", D_METHOD("door_rect", "kind", "cell", "rot"), &PenRules::door_rect);
	ClassDB::bind_static_method("PenRules", D_METHOD("check", "kind", "cell", "rot", "ctx"), &PenRules::check);
	ClassDB::bind_static_method("PenRules", D_METHOD("room", "kind", "animals"), &PenRules::room);
	ClassDB::bind_static_method("PenRules", D_METHOD("takes", "kind", "animals", "species"), &PenRules::takes);
	ClassDB::bind_static_method("PenRules", D_METHOD("refund", "kind"), &PenRules::refund);
}
