#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace godot {

class FruitTrees : public RefCounted {
	GDCLASS(FruitTrees, RefCounted)

protected:
	static void _bind_methods();

public:
	static bool in_season(const Dictionary &kind, int month);
	static int start(const Dictionary &kind, int seed, int today);
	static bool ripe(const Dictionary &kind, int last, int today, int month);
	static int days_left(const Dictionary &kind, int last, int today, int month);
	static int amount(const Dictionary &kind, int seed, int today);
};

}
