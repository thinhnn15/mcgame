#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/rect2i.hpp>
#include <vector>

namespace godot {

class DecorGrid : public RefCounted {
	GDCLASS(DecorGrid, RefCounted)

	Vector2i size = Vector2i(14, 10);
	int wall_len[3] = { 14, 10, 10 };
	int wall_rows = 5;
	float cell = 0.5f;
	float wall_cell = 0.5f;
	Rect2i door;
	std::vector<Rect2i> keep_clear;
	std::vector<Rect2i> wall_fixed[3];
	std::vector<String> history;
	int history_max = 10;

	bool clash(const Rect2i &floor_rect, float height, int wall, const Rect2i &wr) const;
	Rect2i wall_area(int wall) const;

protected:
	static void _bind_methods();

public:
	void setup(const Vector2i &p_size, const PackedInt32Array &p_wall_lens, int p_wall_rows, float p_cell,
			const Rect2i &p_door, const Array &p_keep_clear, const Array &p_wall_fixed);
	bool fits_floor(const Rect2i &r, float height, const Rect2i &hero, const PackedFloat32Array &floors,
			const PackedInt32Array &walls) const;
	bool fits_wall(int wall, const Rect2i &r, const PackedFloat32Array &floors, const PackedInt32Array &walls,
			bool loose = false) const;
	void set_wall_cell(float c) { wall_cell = c > 0.0f ? c : cell; }
	float get_wall_cell() const { return wall_cell; }
	bool fits_top(const Rect2i &host, const Rect2i &r, const PackedInt32Array &siblings) const;

	void remember(const String &state);
	String undo();
	bool can_undo() const { return !history.empty(); }
	void forget() { history.clear(); }
	int undo_steps() const { return (int)history.size(); }
	void set_history_max(int n) { history_max = n > 0 ? n : 1; }
	int get_history_max() const { return history_max; }
};

}
