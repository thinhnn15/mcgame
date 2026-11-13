#include "room_surfaces.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

using namespace godot;

namespace {
const char *KINDS[3] = { "wall", "dado", "floor" };
const char *FACE_NAMES[4] = { "back", "left", "right", "front" };
}

String RoomSurfaces::face_name(int face) {
	return face >= 0 && face < 4 ? String(FACE_NAMES[face]) : String();
}

int RoomSurfaces::face_of(const String &name) {
	for (int i = 0; i < 4; i++) {
		if (name == FACE_NAMES[i]) {
			return i;
		}
	}
	return -1;
}

String RoomSurfaces::face_key(const String &kind) {
	return kind == "wall" ? String("faces") : kind + String("_faces");
}

Dictionary RoomSurfaces::normal(const Dictionary &d) {
	Dictionary out;
	for (const char *k : KINDS) {
		const String kind(k);
		const Variant v = d.get(kind, "");
		out[kind] = v.get_type() == Variant::STRING ? String(v) : String();
		const Variant had = d.get(kind + String("s_had"), Array());
		out[kind + String("s_had")] = had.get_type() == Variant::ARRAY ? Array(had).duplicate() : Array();
		if (kind != "floor") {
			const Variant f = d.get(face_key(kind), Dictionary());
			Dictionary faces;
			if (f.get_type() == Variant::DICTIONARY) {
				const Dictionary fd = f;
				const Array keys = fd.keys();
				for (int i = 0; i < keys.size(); i++) {
					if (face_of(keys[i]) >= 0) {
						faces[String(keys[i])] = String(fd[keys[i]]);
					}
				}
			}
			out[face_key(kind)] = faces;
		}
	}
	return out;
}

void RoomSurfaces::setup(const Dictionary &p_catalog, const Dictionary &p_be_mat) {
	catalog = p_catalog;
	layers = p_be_mat.get("layers", Array());
	const Array m = p_be_mat.get("metres", Array());
	metres.resize(m.size());
	for (int i = 0; i < m.size(); i++) {
		metres.set(i, float(m[i]));
	}
}

void RoomSurfaces::load(const Dictionary &state) {
	saved = normal(state);
	pending.clear();
	previewing = false;
}

Dictionary RoomSurfaces::option(const String &kind, const String &id) const {
	const Dictionary block = catalog.get(kind, Dictionary());
	const Array opts = block.get("options", Array());
	for (int i = 0; i < opts.size(); i++) {
		const Dictionary o = opts[i];
		if (String(o.get("id", "")) == id) {
			return o;
		}
	}
	return Dictionary();
}

String RoomSurfaces::resolve(const Dictionary &st, const String &kind, int face) const {
	String v;
	if (kind != "floor" && face >= 0 && face < 4) {
		const Dictionary faces = st.get(face_key(kind), Dictionary());
		v = String(faces.get(face_name(face), ""));
	}
	if (v.is_empty()) {
		v = String(st.get(kind, ""));
	}
	if (v.is_empty()) {
		const Dictionary block = catalog.get(kind, Dictionary());
		v = String(block.get("default", ""));
	}
	return v == "none" ? String() : v;
}

String RoomSurfaces::current(const String &kind, int face) const {
	return resolve(now(), kind, face);
}

bool RoomSurfaces::has_faces(const String &kind) const {
	return kind != "floor" && !Dictionary(now().get(face_key(kind), Dictionary())).is_empty();
}

void RoomSurfaces::preview(const String &kind, const String &id, int face) {
	if (!previewing) {
		pending = saved.duplicate(true);
		previewing = true;
	}
	if (kind == "floor") {
		pending["floor"] = id;
		return;
	}
	if (kind != "wall" && kind != "dado") {
		return;
	}
	Dictionary faces = pending[face_key(kind)];
	if (face < 0 || face > 3) {
		pending[kind] = id.is_empty() && kind == "dado" ? String("none") : id;
		faces.clear();
		return;
	}
	const String room_wide = resolve(pending, kind, -1);
	if (id == room_wide) {
		faces.erase(face_name(face));
	} else {
		faces[face_name(face)] = id.is_empty() ? String("none") : id;
	}
}

void RoomSurfaces::used(const Dictionary &st, const String &kind, Array &out) const {
	out.clear();
	const int n = kind == "floor" ? 1 : 4;
	for (int f = 0; f < n; f++) {
		const String id = resolve(st, kind, kind == "floor" ? -1 : f);
		if (!id.is_empty() && !out.has(id)) {
			out.push_back(id);
		}
	}
}

Dictionary RoomSurfaces::cost() const {
	Dictionary out;
	if (!previewing) {
		return out;
	}
	for (const char *k : KINDS) {
		const String kind(k);
		const Dictionary block = catalog.get(kind, Dictionary());
		const Dictionary kind_cost = block.get("cost", Dictionary());
		Array now_ids, then_ids;
		used(pending, kind, now_ids);
		used(saved, kind, then_ids);
		const Array had = saved.get(kind + String("s_had"), Array());
		const String def = block.get("default", "");
		for (int i = 0; i < now_ids.size(); i++) {
			const String id = now_ids[i];
			if (then_ids.has(id) || had.has(id) || id == def) {
				continue;
			}
			const Dictionary o = option(kind, id);
			const Dictionary c = o.has("cost") ? Dictionary(o["cost"]) : (o.has("tile") ? Dictionary() : kind_cost);
			const Array keys = c.keys();
			for (int q = 0; q < keys.size(); q++) {
				out[keys[q]] = int(out.get(keys[q], 0)) + int(c[keys[q]]);
			}
		}
	}
	return out;
}

void RoomSurfaces::commit() {
	if (!previewing) {
		return;
	}
	for (const char *k : KINDS) {
		const String kind(k);
		Array ids;
		used(pending, kind, ids);
		Array had = pending[kind + String("s_had")];
		for (int i = 0; i < ids.size(); i++) {
			if (!had.has(ids[i])) {
				had.push_back(ids[i]);
			}
		}
	}
	saved = pending;
	pending = Dictionary();
	previewing = false;
}

void RoomSurfaces::cancel() {
	pending = Dictionary();
	previewing = false;
}

int RoomSurfaces::slice(const Dictionary &opt) const {
	const String tile = opt.get("tile", opt.has("hex") ? "voi" : "");
	const int i = layers.find(tile);
	return i < 0 ? 0 : i;
}

Dictionary RoomSurfaces::shader_params(const Color &lime) const {
	const Dictionary &st = now();
	PackedInt32Array f_layer, d_layer;
	PackedColorArray f_tint, d_tint;
	PackedFloat32Array f_m, d_m;
	auto metre = [&](int layer) { return layer < metres.size() ? metres[layer] : 1.0f; };
	auto tint = [](const Dictionary &o) { return o.has("hex") ? Color::html(String(o["hex"])) : Color(1, 1, 1); };
	const Dictionary room_wall = option("wall", resolve(st, "wall", -1));
	const int lime_layer = MAX(0, (int)layers.find("voi"));
	for (int i = 0; i < FACES; i++) {
		Dictionary o;
		if (i < 8) {
			o = option("wall", resolve(st, "wall", i < 4 ? i : -1));
		} else if (i == 8) {
			o = option("floor", resolve(st, "floor", -1));
		}
		if (i < 9) {
			const int l = slice(o);
			f_layer.push_back(l);
			f_tint.push_back(tint(o));
			f_m.push_back(metre(l));
		} else {
			f_layer.push_back(lime_layer);
			f_tint.push_back(room_wall.has("hex") ? tint(room_wall) : lime);
			f_m.push_back(metre(lime_layer));
		}
		const String did = i < 8 ? resolve(st, "dado", i < 4 ? i : -1) : String();
		const Dictionary d = did.is_empty() ? Dictionary() : option("dado", did);
		if (d.is_empty()) {
			d_layer.push_back(-1);
			d_tint.push_back(Color(1, 1, 1));
			d_m.push_back(1.0f);
		} else {
			const int l = slice(d);
			d_layer.push_back(l);
			d_tint.push_back(tint(d));
			d_m.push_back(metre(l));
		}
	}
	Dictionary out;
	out["face_layer"] = f_layer;
	out["face_tint"] = f_tint;
	out["face_m"] = f_m;
	out["dado_layer"] = d_layer;
	out["dado_tint"] = d_tint;
	out["dado_m"] = d_m;
	return out;
}

void RoomSurfaces::_bind_methods() {
	ClassDB::bind_method(D_METHOD("setup", "catalog", "be_mat"), &RoomSurfaces::setup);
	ClassDB::bind_method(D_METHOD("load", "state"), &RoomSurfaces::load);
	ClassDB::bind_method(D_METHOD("state"), &RoomSurfaces::state);
	ClassDB::bind_method(D_METHOD("option", "kind", "id"), &RoomSurfaces::option);
	ClassDB::bind_method(D_METHOD("current", "kind", "face"), &RoomSurfaces::current, DEFVAL(-1));
	ClassDB::bind_method(D_METHOD("has_faces", "kind"), &RoomSurfaces::has_faces);
	ClassDB::bind_method(D_METHOD("preview", "kind", "id", "face"), &RoomSurfaces::preview, DEFVAL(-1));
	ClassDB::bind_method(D_METHOD("is_previewing"), &RoomSurfaces::is_previewing);
	ClassDB::bind_method(D_METHOD("cost"), &RoomSurfaces::cost);
	ClassDB::bind_method(D_METHOD("commit"), &RoomSurfaces::commit);
	ClassDB::bind_method(D_METHOD("cancel"), &RoomSurfaces::cancel);
	ClassDB::bind_method(D_METHOD("shader_params", "lime"), &RoomSurfaces::shader_params);
	ClassDB::bind_static_method("RoomSurfaces", D_METHOD("face_name", "face"), &RoomSurfaces::face_name);
	ClassDB::bind_static_method("RoomSurfaces", D_METHOD("face_of", "name"), &RoomSurfaces::face_of);
}
