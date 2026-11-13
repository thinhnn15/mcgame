#pragma once

#include <godot_cpp/classes/array_mesh.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace godot {

class RoomShell : public RefCounted {
	GDCLASS(RoomShell, RefCounted)

protected:
	static void _bind_methods();

public:
	enum Face {
		BACK = 0,
		LEFT = 1,
		RIGHT = 2,
		FRONT = 3,
		FLOOR = 8,
		EDGE = 9,
		REVEAL = 10,
	};
	static Ref<ArrayMesh> build(const Dictionary &spec);
	static int face_id(const String &name);
};

}
