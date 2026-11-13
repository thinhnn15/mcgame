#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

class RoomSurfaces : public RefCounted {
	GDCLASS(RoomSurfaces, RefCounted)

	Dictionary catalog;
	Array layers;
	PackedFloat32Array metres;
	Dictionary saved;
	Dictionary pending;
	bool previewing = false;

	const Dictionary &now() const { return previewing ? pending : saved; }
	static String face_key(const String &kind);
	static Dictionary normal(const Dictionary &d);
	String resolve(const Dictionary &st, const String &kind, int face) const;
	void used(const Dictionary &st, const String &kind, Array &out) const;
	int slice(const Dictionary &opt) const;

protected:
	static void _bind_methods();

public:
	static constexpr int FACES = 12;
	void setup(const Dictionary &p_catalog, const Dictionary &p_be_mat);
	void load(const Dictionary &state);
	Dictionary state() const { return saved.duplicate(true); }
	Dictionary option(const String &kind, const String &id) const;
	String current(const String &kind, int face) const;
	bool has_faces(const String &kind) const;
	void preview(const String &kind, const String &id, int face);
	bool is_previewing() const { return previewing; }
	Dictionary cost() const;
	void commit();
	void cancel();
	Dictionary shader_params(const Color &lime) const;
	static String face_name(int face);
	static int face_of(const String &name);
};

}
