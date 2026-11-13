#include "photo_print.h"

#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/classes/mesh.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/basis.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <cmath>

using namespace godot;

static const char *DIR = "user://photos/";
static const char *ALBUM = "user://photos/album.json";
static const char *ORDERS = "user://photos/orders.json";

void PhotoPrint::_bind_methods() {
	ClassDB::bind_static_method("PhotoPrint", D_METHOD("save_shot", "image"), &PhotoPrint::save_shot);
	ClassDB::bind_static_method("PhotoPrint", D_METHOD("album"), &PhotoPrint::album);
	ClassDB::bind_static_method("PhotoPrint", D_METHOD("shot_path", "id"), &PhotoPrint::shot_path);
	ClassDB::bind_static_method("PhotoPrint", D_METHOD("forget_shot", "id"), &PhotoPrint::forget_shot);
	ClassDB::bind_static_method("PhotoPrint", D_METHOD("make_print", "id", "long_px"), &PhotoPrint::make_print);
	ClassDB::bind_static_method("PhotoPrint", D_METHOD("order", "id", "size", "frame", "mount", "ready_day"),
			&PhotoPrint::order);
	ClassDB::bind_static_method("PhotoPrint", D_METHOD("orders"), &PhotoPrint::orders);
	ClassDB::bind_static_method("PhotoPrint", D_METHOD("due", "day"), &PhotoPrint::due);
	ClassDB::bind_static_method("PhotoPrint", D_METHOD("frame_mesh", "pic_w", "pic_h", "border", "depth", "stand"),
			&PhotoPrint::frame_mesh);
	ClassDB::bind_static_method("PhotoPrint", D_METHOD("finish", "image", "params"), &PhotoPrint::finish);
}

Variant PhotoPrint::read_json(const String &path, const Variant &fallback) {
	if (!FileAccess::file_exists(path)) {
		return fallback;
	}
	Variant v = JSON::parse_string(FileAccess::get_file_as_string(path));
	return v.get_type() == fallback.get_type() ? v : fallback;
}

void PhotoPrint::write_json(const String &path, const Variant &v) {
	DirAccess::make_dir_recursive_absolute(path.get_base_dir());
	Ref<FileAccess> f = FileAccess::open(path, FileAccess::WRITE);
	if (f.is_valid()) {
		f->store_string(JSON::stringify(v, "\t"));
	}
}

String PhotoPrint::save_shot(const Ref<Image> &image) {
	if (image.is_null() || image->is_empty()) {
		return String();
	}
	DirAccess::make_dir_recursive_absolute(DIR);
	Array list = read_json(ALBUM, Array());
	String id = "p" + String::num_int64(Time::get_singleton()->get_unix_time_from_system());
	String base = id;
	for (int n = 2; FileAccess::file_exists(String(DIR) + id + ".jpg"); n++) {
		id = base + "_" + String::num_int64(n);
	}
	Ref<Image> img = image->duplicate();
	if (img->is_compressed()) {
		img->decompress();
	}
	img->convert(Image::FORMAT_RGB8);
	if (img->save_jpg(String(DIR) + id + ".jpg", 0.9f) != OK) {
		return String();
	}
	list.push_back(id);
	write_json(ALBUM, list);
	return id;
}

PackedStringArray PhotoPrint::album() {
	PackedStringArray out;
	Array list = read_json(ALBUM, Array());
	for (int i = 0; i < list.size(); i++) {
		String id = list[i];
		if (FileAccess::file_exists(shot_path(id))) {
			out.push_back(id);
		}
	}
	return out;
}

String PhotoPrint::shot_path(const String &id) {
	return String(DIR) + id + ".jpg";
}

bool PhotoPrint::forget_shot(const String &id) {
	Array list = read_json(ALBUM, Array());
	int i = list.find(id);
	if (i < 0) {
		return false;
	}
	list.remove_at(i);
	write_json(ALBUM, list);
	DirAccess::remove_absolute(shot_path(id));
	return true;
}

String PhotoPrint::make_print(const String &id, int long_px) {
	String out = String(DIR) + "print/" + id + "_" + String::num_int64(long_px) + ".webp";
	if (FileAccess::file_exists(out)) {
		return out;
	}
	Ref<Image> img = Image::load_from_file(shot_path(id));
	if (img.is_null() || img->is_empty()) {
		return String();
	}
	int w = img->get_width(), h = img->get_height();
	bool tall = h > w;

	int cw = w, ch = h;
	if (tall) {
		if (w * 3 > h * 2) {
			cw = h * 2 / 3;
		} else {
			ch = w * 3 / 2;
		}
	} else if (w * 2 > h * 3) {
		cw = h * 3 / 2;
	} else {
		ch = w * 2 / 3;
	}
	Ref<Image> cut = img->get_region(Rect2i((w - cw) / 2, (h - ch) / 2, cw, ch));
	int lw = tall ? long_px * 2 / 3 : long_px;
	int lh = tall ? long_px : long_px * 2 / 3;
	cut->resize(lw, lh, Image::INTERPOLATE_LANCZOS);
	DirAccess::make_dir_recursive_absolute(String(DIR) + "print");
	if (cut->save_webp(out, true, 0.85f) != OK) {
		return String();
	}
	return out;
}

void PhotoPrint::order(const String &id, const String &size, const String &frame, const String &mount, int ready_day) {
	Array list = read_json(ORDERS, Array());
	Dictionary o;
	o["photo"] = id;
	o["size"] = size;
	o["frame"] = frame;
	o["mount"] = mount;
	o["ready"] = ready_day;
	list.push_back(o);
	write_json(ORDERS, list);
}

Array PhotoPrint::orders() {
	return read_json(ORDERS, Array());
}

Array PhotoPrint::due(int day) {
	Array list = read_json(ORDERS, Array());
	Array keep, out;
	for (int i = 0; i < list.size(); i++) {
		Dictionary o = list[i];
		if ((int)o.get("ready", 0) <= day) {
			out.push_back(o);
		} else {
			keep.push_back(o);
		}
	}
	if (!out.is_empty()) {
		write_json(ORDERS, keep);
	}
	return out;
}

namespace {
struct Build {
	PackedVector3Array v, n;
	PackedVector2Array uv;
	PackedInt32Array idx;

	void quad(const Vector3 &a, const Vector3 &b, const Vector3 &c, const Vector3 &d, const Vector3 &nrm,
			const Vector2 &ua, const Vector2 &ub, const Vector2 &uc, const Vector2 &ud) {
		int s = v.size();
		v.append(a);
		v.append(b);
		v.append(c);
		v.append(d);
		for (int i = 0; i < 4; i++) {
			n.append(nrm);
		}
		uv.append(ua);
		uv.append(ub);
		uv.append(uc);
		uv.append(ud);

		idx.append(s);
		idx.append(s + 2);
		idx.append(s + 1);
		idx.append(s);
		idx.append(s + 3);
		idx.append(s + 2);
	}

	void bar(const Vector3 &lo, const Vector3 &hi, int along) {
		float len = along == 0 ? hi.x - lo.x : hi.y - lo.y;
		float u1 = len / 0.2f;
		Vector2 a0(0, 0), a1(u1, 0), a2(u1, 1), a3(0, 1);
		Vector2 s0(0, 0.9f), s1(u1, 0.9f), s2(u1, 1), s3(0, 1);
		if (along == 0) {
			quad(Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z),
					Vector3(0, 0, 1), a0, a1, a2, a3);
			quad(Vector3(lo.x, hi.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z),
					Vector3(0, 1, 0), s0, s1, s2, s3);
			quad(Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z),
					Vector3(0, -1, 0), s0, s1, s2, s3);
		} else {
			quad(Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z),
					Vector3(0, 0, 1), Vector2(0, 1), Vector2(0, 0), Vector2(u1, 0), Vector2(u1, 1));
		}

		if (along == 0) {
			quad(Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, lo.y, hi.z), Vector3(lo.x, hi.y, hi.z), Vector3(lo.x, hi.y, lo.z),
					Vector3(-1, 0, 0), s0, s3, s2, s1);
			quad(Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z),
					Vector3(1, 0, 0), s0, s3, s2, s1);
		} else {
			quad(Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, lo.y, hi.z), Vector3(lo.x, hi.y, hi.z), Vector3(lo.x, hi.y, lo.z),
					Vector3(-1, 0, 0), s0, s3, s2, s1);
			quad(Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z),
					Vector3(1, 0, 0), s0, s3, s2, s1);
		}
	}

	void turn(const Basis &b, const Vector3 &pivot, int from) {
		for (int i = from; i < v.size(); i++) {
			v.set(i, pivot + b.xform(v[i] - pivot));
			n.set(i, b.xform(n[i]));
		}
	}

	void add_to(Ref<ArrayMesh> &m) {
		Array arr;
		arr.resize(Mesh::ARRAY_MAX);
		arr[Mesh::ARRAY_VERTEX] = v;
		arr[Mesh::ARRAY_NORMAL] = n;
		arr[Mesh::ARRAY_TEX_UV] = uv;
		arr[Mesh::ARRAY_INDEX] = idx;
		m->add_surface_from_arrays(Mesh::PRIMITIVE_TRIANGLES, arr);
	}
};
}

Ref<ArrayMesh> PhotoPrint::frame_mesh(float pic_w, float pic_h, float border, float depth, bool stand) {
	Build fr, pic;
	float W = pic_w * 0.5f + border, H = pic_h + 2.0f * border;
	float x0 = -W, x1 = W;
	float i0 = -pic_w * 0.5f, i1 = pic_w * 0.5f;
	fr.bar(Vector3(x0, 0, 0), Vector3(x1, border, depth), 0);
	fr.bar(Vector3(x0, H - border, 0), Vector3(x1, H, depth), 0);
	fr.bar(Vector3(x0, border, 0), Vector3(i0, H - border, depth), 1);
	fr.bar(Vector3(i1, border, 0), Vector3(x1, H - border, depth), 1);

	float pz = depth * 0.45f;
	pic.quad(Vector3(i0, border, pz), Vector3(i1, border, pz), Vector3(i1, H - border, pz), Vector3(i0, H - border, pz),
			Vector3(0, 0, 1), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0));

	fr.quad(Vector3(x1, 0, 0.002f), Vector3(x0, 0, 0.002f), Vector3(x0, H, 0.002f), Vector3(x1, H, 0.002f),
			Vector3(0, 0, -1), Vector2(0, 0.9f), Vector2(1, 0.9f), Vector2(1, 1), Vector2(0, 1));
	if (stand) {
		Basis tilt(Vector3(1, 0, 0), Math::deg_to_rad(-14.0f));
		Vector3 pivot(0, 0, depth);
		fr.turn(tilt, pivot, 0);
		pic.turn(tilt, pivot, 0);

		float top_y = H * 0.62f * Math::cos(Math::deg_to_rad(14.0f));
		float top_z = depth - H * 0.62f * Math::sin(Math::deg_to_rad(14.0f));
		float foot_z = top_z - H * 0.42f;
		float sw = Math::max(border * 0.6f, 0.012f);
		Vector3 a(-sw, 0, foot_z), b(sw, 0, foot_z), c(sw, top_y, top_z), d(-sw, top_y, top_z);
		Vector3 nrm = (c - b).cross(a - b).normalized();
		fr.quad(a, b, c, d, -nrm, Vector2(0, 0.9f), Vector2(0.2f, 0.9f), Vector2(0.2f, 1), Vector2(0, 1));
		fr.quad(b, a, d, c, nrm, Vector2(0, 0.9f), Vector2(0.2f, 0.9f), Vector2(0.2f, 1), Vector2(0, 1));
	}
	Ref<ArrayMesh> m;
	m.instantiate();
	fr.add_to(m);
	pic.add_to(m);
	return m;
}

Ref<Image> PhotoPrint::finish(const Ref<Image> &image, const Dictionary &params) {
	if (image.is_null() || image->is_empty()) {
		return image;
	}
	Ref<Image> img = image->duplicate();
	if (img->is_compressed()) {
		img->decompress();
	}
	img->convert(Image::FORMAT_RGB8);
	const float fade = (float)params.get("fade", 0.0);
	const float gloss = (float)params.get("gloss", 0.0);
	const int border = (int)params.get("border", 0);
	const Color tint = params.get("tint", Color(1, 1, 1));
	const int w = img->get_width(), h = img->get_height();
	const float half = std::sqrt((float)w * w + (float)h * h) * 0.5f;
	const float pr = (0.96f + (0.86f - 0.96f) * 0.5f * fade) * tint.r;
	const float pg = (0.94f + (0.80f - 0.94f) * 0.5f * fade) * tint.g;
	const float pb = (0.89f + (0.66f - 0.89f) * 0.5f * fade) * tint.b;
	PackedByteArray px = img->get_data();
	uint8_t *d = px.ptrw();
	auto to8 = [](float v) -> uint8_t {
		v = v < 0.0f ? 0.0f : (v > 1.0f ? 1.0f : v);
		return (uint8_t)std::lround(v * 255.0f);
	};
	for (int y = 0; y < h; y++) {
		for (int x = 0; x < w; x++) {
			uint8_t *p = d + (size_t(y) * w + x) * 3;
			if (x < border || y < border || x >= w - border || y >= h - border) {
				p[0] = to8(pr);
				p[1] = to8(pg);
				p[2] = to8(pb);
				continue;
			}
			float r = p[0] / 255.0f * tint.r, g = p[1] / 255.0f * tint.g, b = p[2] / 255.0f * tint.b;
			const float lum = r * 0.3f + g * 0.59f + b * 0.11f;
			const float m = 0.45f * fade;
			r += (lum - r) * m;
			g += (lum - g) * m;
			b += (lum - b) * m;
			r = r * (1.0f - 0.2f * fade) + 0.09f * fade;
			g = g * (1.0f - 0.2f * fade) + 0.09f * fade;
			b = b * (1.0f - 0.2f * fade) + 0.09f * fade;
			const float dx = x - w * 0.5f, dy = y - h * 0.5f;
			const float dd = std::sqrt(dx * dx + dy * dy) / half;
			const float v = 1.0f - 0.22f * fade * dd * dd;
			r *= v;
			g *= v;
			b *= v;
			if (gloss > 0.0f) {
				const float k = 1.0f + 0.12f * gloss;
				const float u = ((float)x / w + (float)y / h) * 0.5f;
				const float t = (u - 0.3f) / 0.08f;
				const float sh = 0.05f * gloss * std::exp(-t * t);
				r = (r - 0.5f) * k + 0.5f + sh;
				g = (g - 0.5f) * k + 0.5f + sh;
				b = (b - 0.5f) * k + 0.5f + sh;
			}
			p[0] = to8(r);
			p[1] = to8(g);
			p[2] = to8(b);
		}
	}
	img->set_data(w, h, false, Image::FORMAT_RGB8, px);
	return img;
}
