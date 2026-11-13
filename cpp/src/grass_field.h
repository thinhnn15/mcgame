#pragma once

#include <godot_cpp/classes/fast_noise_lite.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

class GrassField : public RefCounted {
	GDCLASS(GrassField, RefCounted)

protected:
	static void _bind_methods();

public:
	static PackedFloat32Array lush_chunk(const Rect2 &area, int n, int half, const PackedByteArray &mats,
			const PackedByteArray &dens, const PackedByteArray &sdf, const PackedFloat32Array &heights,
			const Array &no_rects, int64_t seed, double step, double road_lo, double road_ramp,
			const Ref<FastNoiseLite> &noise, const Color &colour);
	static PackedFloat32Array weed_chunk(const Rect2 &area, int n, int half, const PackedByteArray &mats,
			const PackedByteArray &dens, const PackedByteArray &sdf, const PackedFloat32Array &heights,
			const Array &no_rects, const Array &no_circles, const Rect2 &skip, int64_t seed, double road_clear);
};

}
