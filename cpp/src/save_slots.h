#pragma once

#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace godot {

class SaveSlots : public RefCounted {
	GDCLASS(SaveSlots, RefCounted)

protected:
	static void _bind_methods();

public:
	static const int COUNT = 3;

	static void recover();
	static int active();
	static Dictionary info(int slot);
	static Array all();
	static bool use(int slot);
	static void erase(int slot);
	static void touch(double seconds, const String &scene);
	static void save_thumb(const Ref<Image> &image);
	static String dir_of(int slot);
};

}
