#pragma once

#include <godot_cpp/classes/array_mesh.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>

namespace godot {

class PhotoPrint : public RefCounted {
	GDCLASS(PhotoPrint, RefCounted)

	static Variant read_json(const String &path, const Variant &fallback);
	static void write_json(const String &path, const Variant &v);

protected:
	static void _bind_methods();

public:
	static String save_shot(const Ref<Image> &image);
	static PackedStringArray album();
	static String shot_path(const String &id);
	static bool forget_shot(const String &id);
	static String make_print(const String &id, int long_px);
	static void order(const String &id, const String &size, const String &frame, const String &mount, int ready_day);
	static Array orders();
	static Array due(int day);
	static Ref<ArrayMesh> frame_mesh(float pic_w, float pic_h, float border, float depth, bool stand);
	static Ref<Image> finish(const Ref<Image> &image, const Dictionary &params);
};

}
