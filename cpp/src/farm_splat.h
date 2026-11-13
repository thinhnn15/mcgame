#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/vector2.hpp>

namespace godot {

class FarmSplat : public RefCounted {
	GDCLASS(FarmSplat, RefCounted)

protected:
	static void _bind_methods();

public:
	static PackedByteArray paint(double size, int px, const Array &paths, const Array &earth_rects, const Array &worn_circles,
			const Array &worn_rects, double ditch_z, const Vector2 &pond_c, const Vector2 &pond_r);
};

}
