#include "decor_grid.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>

using namespace godot;

void DecorGrid::_bind_methods() {
	ClassDB::bind_method(D_METHOD("setup", "size", "wall_lens", "wall_rows", "cell", "door", "keep_clear", "wall_fixed"),
			&DecorGrid::setup);
	ClassDB::bind_method(D_METHOD("fits_floor", "rect", "height", "hero", "floors", "walls"), &DecorGrid::fits_floor);
	ClassDB::bind_method(D_METHOD("fits_wall", "wall", "rect", "floors", "walls", "loose"), &DecorGrid::fits_wall,
			DEFVAL(false));
	ClassDB::bind_method(D_METHOD("set_wall_cell", "c"), &DecorGrid::set_wall_cell);
	ClassDB::bind_method(D_METHOD("get_wall_cell"), &DecorGrid::get_wall_cell);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "wall_cell"), "set_wall_cell", "get_wall_cell");
	ClassDB::bind_method(D_METHOD("fits_top", "host", "rect", "siblings"), &DecorGrid::fits_top);
	ClassDB::bind_method(D_METHOD("remember", "state"), &DecorGrid::remember);
	ClassDB::bind_method(D_METHOD("undo"), &DecorGrid::undo);
	ClassDB::bind_method(D_METHOD("can_undo"), &DecorGrid::can_undo);
	ClassDB::bind_method(D_METHOD("forget"), &DecorGrid::forget);
	ClassDB::bind_method(D_METHOD("undo_steps"), &DecorGrid::undo_steps);
	ClassDB::bind_method(D_METHOD("set_history_max", "n"), &DecorGrid::set_history_max);
	ClassDB::bind_method(D_METHOD("get_history_max"), &DecorGrid::get_history_max);
	ADD_PROPERTY(PropertyInfo(Variant::INT, "history_max"), "set_history_max", "get_history_max");
}

void DecorGrid::setup(const Vector2i &p_size, const PackedInt32Array &p_wall_lens, int p_wall_rows, float p_cell,
		const Rect2i &p_door, const Array &p_keep_clear, const Array &p_wall_fixed) {
	size = p_size;
	for (int w = 0; w < 3; w++) {
		wall_len[w] = w < p_wall_lens.size() ? p_wall_lens[w] : (w == 0 ? size.x : size.y);
		wall_fixed[w].clear();
	}
	wall_rows = p_wall_rows;
	cell = p_cell;
	wall_cell = p_cell;
	door = p_door;
	keep_clear.clear();
	for (int i = 0; i < p_keep_clear.size(); i++) {
		keep_clear.push_back(p_keep_clear[i]);
	}
	for (int w = 0; w < 3 && w < p_wall_fixed.size(); w++) {
		Array a = p_wall_fixed[w];
		for (int i = 0; i < a.size(); i++) {
			wall_fixed[w].push_back(a[i]);
		}
	}
	history.clear();
}

Rect2i DecorGrid::wall_area(int wall) const {
	const int lo = (int)Math::round(0.5f / wall_cell);
	return Rect2i(0, lo, wall_len[wall], wall_rows - lo);
}

bool DecorGrid::clash(const Rect2i &floor_rect, float height, int wall, const Rect2i &wr) const {
	if (height <= wr.position.y * wall_cell + 0.02f) {
		return false;
	}
	const float k = cell / wall_cell;
	int a, b;
	switch (wall) {
		case 0:
			if (floor_rect.position.y != 0) {
				return false;
			}
			a = floor_rect.position.x;
			b = floor_rect.get_end().x;
			break;
		case 1:
			if (floor_rect.position.x != 0) {
				return false;
			}
			a = floor_rect.position.y;
			b = floor_rect.get_end().y;
			break;
		default:
			if (floor_rect.get_end().x != size.x) {
				return false;
			}
			a = floor_rect.position.y;
			b = floor_rect.get_end().y;
			break;
	}
	return a * k < wr.get_end().x && wr.position.x < b * k;
}

bool DecorGrid::fits_floor(const Rect2i &r, float height, const Rect2i &hero, const PackedFloat32Array &floors,
		const PackedInt32Array &walls) const {
	if (!Rect2i(Vector2i(), size).encloses(r) || r.intersects(door) || r.intersects(hero)) {
		return false;
	}
	for (const Rect2i &k : keep_clear) {
		if (r.intersects(k)) {
			return false;
		}
	}
	for (int i = 0; i + 4 < floors.size(); i += 5) {
		if (r.intersects(Rect2i((int)floors[i], (int)floors[i + 1], (int)floors[i + 2], (int)floors[i + 3]))) {
			return false;
		}
	}
	for (int i = 0; i + 4 < walls.size(); i += 5) {
		if (clash(r, height, walls[i], Rect2i(walls[i + 1], walls[i + 2], walls[i + 3], walls[i + 4]))) {
			return false;
		}
	}
	return true;
}

bool DecorGrid::fits_wall(int wall, const Rect2i &r, const PackedFloat32Array &floors, const PackedInt32Array &walls,
		bool loose) const {
	if (wall < 0 || wall > 2 || !wall_area(wall).encloses(r)) {
		return false;
	}
	for (const Rect2i &f : wall_fixed[wall]) {
		if (r.intersects(f)) {
			return false;
		}
	}
	for (int i = 0; i + 4 < walls.size(); i += 5) {
		if (walls[i] != wall) {
			continue;
		}
		Rect2i o(walls[i + 1], walls[i + 2], walls[i + 3], walls[i + 4]);
		if (!r.intersects(o)) {
			continue;
		}
		if (loose) {
			Rect2i in = r.intersection(o);
			int a = in.size.x * in.size.y;
			int least = Math::min(r.size.x * r.size.y, o.size.x * o.size.y);
			if ((in.size.x <= 1 || in.size.y <= 1) && a * 2 <= least) {
				continue;
			}
		}
		return false;
	}
	for (int i = 0; i + 4 < floors.size(); i += 5) {
		Rect2i fr((int)floors[i], (int)floors[i + 1], (int)floors[i + 2], (int)floors[i + 3]);
		if (clash(fr, floors[i + 4], wall, r)) {
			return false;
		}
	}
	return true;
}

bool DecorGrid::fits_top(const Rect2i &host, const Rect2i &r, const PackedInt32Array &siblings) const {
	if (!host.encloses(r)) {
		return false;
	}
	for (int i = 0; i + 3 < siblings.size(); i += 4) {
		if (r.intersects(Rect2i(siblings[i], siblings[i + 1], siblings[i + 2], siblings[i + 3]))) {
			return false;
		}
	}
	return true;
}

void DecorGrid::remember(const String &state) {
	if (!history.empty() && history.back() == state) {
		return;
	}
	history.push_back(state);
	while ((int)history.size() > history_max) {
		history.erase(history.begin());
	}
}

String DecorGrid::undo() {
	if (history.empty()) {
		return String();
	}
	String s = history.back();
	history.pop_back();
	return s;
}
