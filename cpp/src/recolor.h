#pragma once

#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace godot {

class Recolor : public RefCounted {
	GDCLASS(Recolor, RefCounted)

protected:
	static void _bind_methods();

public:
	static Ref<Image> apply(const Ref<Image> &image, const Dictionary &look);
	static Dictionary main_hue(const Ref<Image> &image);
};

}
