#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace godot {

class PatternShop : public RefCounted {
	GDCLASS(PatternShop, RefCounted)

protected:
	static void _bind_methods();

public:
	static bool in_season(const Array &spans, int month, int day);
	static Array stock(const Dictionary &prices, const Dictionary &seasons, int month, int day);
	static bool priced(const Dictionary &prices, const String &id);
	static bool owned(const String &id);
	static String buy(const String &id, int price);
};

}
