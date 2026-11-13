#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

class TeaRows : public RefCounted {
	GDCLASS(TeaRows, RefCounted)

protected:
	static void _bind_methods();

public:
	static bool ready(const Dictionary &cfg, int last, int today);
	static Dictionary pick(const Dictionary &cfg, int seed, int today, double hour, bool wet, bool with_ba);
	static Dictionary roast(const Dictionary &cfg, const PackedFloat32Array &offsets);
};

}
