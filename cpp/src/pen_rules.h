#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/rect2.hpp>
#include <godot_cpp/variant/vector2i.hpp>

namespace godot {

class PenRules : public RefCounted {
	GDCLASS(PenRules, RefCounted)

	static Dictionary *kinds;

protected:
	static void _bind_methods();

public:
	static constexpr float CELL = 0.5f;
	static constexpr float DOOR = 1.0f;
	static constexpr float SLOPE = 0.4f;
	static void setup(const Dictionary &p_kinds);
	static void finish();
	static Dictionary kind(const String &id);
	static Vector2i size_of(const String &kind, int rot);
	static Rect2 rect_of(const String &kind, const Vector2i &cell, int rot);
	static Rect2 door_rect(const String &kind, const Vector2i &cell, int rot);
	static String check(const String &kind, const Vector2i &cell, int rot, const Dictionary &ctx);
	static Dictionary room(const String &kind, const Array &animals);
	static bool takes(const String &kind, const Array &animals, const String &species);
	static Dictionary refund(const String &kind);
};

}
