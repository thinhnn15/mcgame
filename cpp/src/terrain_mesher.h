#pragma once

#include <godot_cpp/classes/array_mesh.hpp>
#include <godot_cpp/classes/ref_counted.hpp>

namespace godot {

class TerrainMesher : public RefCounted {
	GDCLASS(TerrainMesher, RefCounted)

protected:
	static void _bind_methods();

public:
	static constexpr int ROAD = 3;
	static constexpr int BALLAST = 11;

	static Ref<ArrayMesh> grid_mesh(const PackedFloat32Array &heights, const PackedByteArray &mats, int n, int half,
			const Dictionary &pal, const PackedByteArray &road_sdf, const PackedByteArray &rail_sdf,
			int x0, int z0, int cells, int step, float sink, const Vector3 &centre, float skirt);
};

}
