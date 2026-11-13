#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace godot {

class Cooking : public RefCounted {
	GDCLASS(Cooking, RefCounted)

protected:
	static void _bind_methods();

public:
	static Array menu(const Dictionary &recipes, const Array &open_ids, const Dictionary &have);
	static Dictionary take(const Dictionary &recipe, const Dictionary &have);
	static int xp_bonus(const Dictionary &recipe, int per_level);
	static Dictionary cook(const Dictionary &pot, const Dictionary &recipes, const Array &open_ids, const Array &chosen);
};

}
