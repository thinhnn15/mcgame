#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/aabb.hpp>
#include <godot_cpp/variant/transform3d.hpp>

#include <cstdint>
#include <unordered_map>
#include <vector>

namespace godot {

class PaveGrid : public RefCounted {
	GDCLASS(PaveGrid, RefCounted)

	struct Tile {
		Transform3D inv;
		Transform3D xf;
		float x0, x1, z0, z1;
		float top;
	};
	std::vector<Tile> tiles;
	std::unordered_map<int64_t, std::vector<int32_t>> cells;
	float cell = 2.0f;

	static int64_t key(int32_t cx, int32_t cz) { return (int64_t(cx) << 32) ^ int64_t(uint32_t(cz)); }

protected:
	static void _bind_methods();

public:
	void add(const Transform3D &xf, const AABB &box);
	int add_multimesh(Object *mmi);
	float top(float x, float y, float z) const;
	int count() const { return int(tiles.size()); }
	int cell_count() const { return int(cells.size()); }
	void clear() { tiles.clear(); cells.clear(); }
};

}
