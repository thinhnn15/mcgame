#pragma once

#include <godot_cpp/classes/fast_noise_lite.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/rect2.hpp>
#include <godot_cpp/variant/vector2.hpp>

#include <vector>

namespace godot {

class FarmHeight : public RefCounted {
	GDCLASS(FarmHeight, RefCounted)

	struct Pad {
		Rect2 r;
		double edge;
	};
	Ref<FastNoiseLite> noise;
	Rect2 flat;
	std::vector<Pad> pads, sinks;
	double ditch_z = 6.6;
	Vector2 pond_c, pond_r = Vector2(1, 1);

protected:
	static void _bind_methods();

public:
	void configure(const Dictionary &d);
	double height(double x, double z) const;
	PackedFloat32Array grid(double x0, double z0, double step, int nx, int nz) const;
};

}
