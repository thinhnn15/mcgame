#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/vector2i.hpp>

namespace godot {

class PenWork : public RefCounted {
	GDCLASS(PenWork, RefCounted)

	static Dictionary *cache;
	static Dictionary kinds();
	static Dictionary kind(const String &id);
	static void clear_booking();
	static void advance(Dictionary b);
	static bool home_busy();

protected:
	static void _bind_methods();

public:
	static Dictionary check(const String &kind);
	static bool book(const String &kind, const Vector2i &cell, int rot, int pen, int start = -1);
	static Dictionary booked();
	static bool cancel();
	static void sync();
	static bool busy();
	static Array take_built();
	static void finish();
};

}
