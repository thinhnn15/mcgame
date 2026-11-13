#include "room_shell.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

#include <algorithm>
#include <vector>

using namespace godot;

namespace {

struct Hole {
	float a0, a1, y0, y1;
};

struct Builder {
	PackedVector3Array v;
	PackedVector3Array n;
	PackedVector2Array uv2;
	PackedInt32Array idx;

	void quad(const Vector3 &a, const Vector3 &b, const Vector3 &c, const Vector3 &d, const Vector3 &nrm, int face) {
		const int k = v.size();
		const Vector3 p[4] = { a, b, c, d };
		for (const Vector3 &q : p) {
			v.push_back(q);
			n.push_back(nrm);
			uv2.push_back(Vector2(float(face), 0.0f));
		}
		const bool ccw = (b - a).cross(c - a).dot(nrm) > 0.0f;
		const int order[2][6] = { { 0, 1, 2, 0, 2, 3 }, { 0, 2, 1, 0, 3, 2 } };
		for (int i : order[ccw ? 1 : 0]) {
			idx.push_back(k + i);
		}
	}

	void wall(const Vector3 &o, const Vector3 &along, const Vector3 &in, float len, float h, float t, int face,
			const std::vector<Hole> &holes) {
		std::vector<float> as = { 0.0f, len };
		std::vector<float> ys = { 0.0f, h };
		for (const Hole &q : holes) {
			as.push_back(CLAMP(q.a0, 0.0f, len));
			as.push_back(CLAMP(q.a1, 0.0f, len));
			ys.push_back(CLAMP(q.y0, 0.0f, h));
			ys.push_back(CLAMP(q.y1, 0.0f, h));
		}
		auto tidy = [](std::vector<float> &s) {
			std::sort(s.begin(), s.end());
			s.erase(std::unique(s.begin(), s.end(), [](float x, float y) { return Math::abs(x - y) < 1e-4f; }), s.end());
		};
		tidy(as);
		tidy(ys);
		const Vector3 up(0, 1, 0);
		auto at = [&](float a, float y) { return o + along * a + up * y; };
		for (size_t i = 0; i + 1 < as.size(); i++) {
			for (size_t j = 0; j + 1 < ys.size(); j++) {
				const float am = (as[i] + as[i + 1]) * 0.5f;
				const float ym = (ys[j] + ys[j + 1]) * 0.5f;
				bool open = false;
				for (const Hole &q : holes) {
					if (am > q.a0 && am < q.a1 && ym > q.y0 && ym < q.y1) {
						open = true;
						break;
					}
				}
				if (!open) {
					quad(at(as[i], ys[j]), at(as[i + 1], ys[j]), at(as[i + 1], ys[j + 1]), at(as[i], ys[j + 1]), in, face);
				}
			}
		}
		const Vector3 out = -in * t;
		for (const Hole &q : holes) {
			const float a0 = CLAMP(q.a0, 0.0f, len), a1 = CLAMP(q.a1, 0.0f, len);
			const float y0 = CLAMP(q.y0, 0.0f, h), y1 = CLAMP(q.y1, 0.0f, h);
			quad(at(a0, y0), at(a0, y1), at(a0, y1) + out, at(a0, y0) + out, along, RoomShell::REVEAL);
			quad(at(a1, y0), at(a1, y1), at(a1, y1) + out, at(a1, y0) + out, -along, RoomShell::REVEAL);
			if (y0 > 1e-3f) {
				quad(at(a0, y0), at(a1, y0), at(a1, y0) + out, at(a0, y0) + out, up, RoomShell::REVEAL);
			}
			if (y1 < h - 1e-3f) {
				quad(at(a0, y1), at(a1, y1), at(a1, y1) + out, at(a0, y1) + out, -up, RoomShell::REVEAL);
			}
		}
	}

	void flat(float x0, float z0, float x1, float z1, float y, int face) {
		quad(Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1), Vector3(0, 1, 0), face);
	}

	void end_z(float x0, float x1, float z, float h, float nz) {
		quad(Vector3(x0, 0, z), Vector3(x1, 0, z), Vector3(x1, h, z), Vector3(x0, h, z), Vector3(0, 0, nz), RoomShell::EDGE);
	}
	void end_x(float z0, float z1, float x, float h, float nx) {
		quad(Vector3(x, 0, z0), Vector3(x, 0, z1), Vector3(x, h, z1), Vector3(x, h, z0), Vector3(nx, 0, 0), RoomShell::EDGE);
	}
};

}

int RoomShell::face_id(const String &name) {
	if (name == "back") {
		return BACK;
	}
	if (name == "left") {
		return LEFT;
	}
	if (name == "right") {
		return RIGHT;
	}
	if (name == "front") {
		return FRONT;
	}
	if (name == "floor") {
		return FLOOR;
	}
	return -1;
}

Ref<ArrayMesh> RoomShell::build(const Dictionary &spec) {
	const float x0 = spec.get("x0", -3.5), z0 = spec.get("z0", -2.5);
	const float x1 = spec.get("x1", 3.5), z1 = spec.get("z1", 2.5);
	const float h = spec.get("h", 2.6), t = spec.get("t", 0.2);
	PackedStringArray walls = spec.get("walls", PackedStringArray());
	if (walls.is_empty()) {
		walls.push_back("back");
		walls.push_back("left");
		walls.push_back("right");
	}
	const bool has_back = walls.has("back"), has_left = walls.has("left");
	const bool has_right = walls.has("right"), has_front = walls.has("front");

	std::vector<Hole> holes[4];
	const Array hs = spec.get("holes", Array());
	for (int i = 0; i < hs.size(); i++) {
		const Dictionary q = hs[i];
		const int f = face_id(q.get("face", ""));
		if (f < 0 || f > FRONT) {
			continue;
		}
		const float along = q.get("along", 0.0), w = q.get("w", 1.0);
		const float y = q.get("y", 0.0), hh = q.get("h", 1.0);
		holes[f].push_back(Hole{ along - w * 0.5f, along + w * 0.5f, y, y + hh });
	}

	Builder b;
	b.flat(x0, z0, x1, z1, 0.0f, FLOOR);
	const float w = x1 - x0, d = z1 - z0;
	if (has_back) {
		b.wall(Vector3(x0, 0, z0), Vector3(1, 0, 0), Vector3(0, 0, 1), w, h, t, BACK, holes[BACK]);
		b.flat(x0 - (has_left ? t : 0.0f), z0 - t, x1 + (has_right ? t : 0.0f), z0, h, EDGE);
		if (!has_left) {
			b.end_x(z0 - t, z0, x0, h, -1.0f);
		}
		if (!has_right) {
			b.end_x(z0 - t, z0, x1, h, 1.0f);
		}
	}
	if (has_left) {
		b.wall(Vector3(x0, 0, z0), Vector3(0, 0, 1), Vector3(1, 0, 0), d, h, t, LEFT, holes[LEFT]);
		b.flat(x0 - t, z0, x0, z1, h, EDGE);
		if (!has_front) {
			b.end_z(x0 - t, x0, z1, h, 1.0f);
		}
	}
	if (has_right) {
		b.wall(Vector3(x1, 0, z0), Vector3(0, 0, 1), Vector3(-1, 0, 0), d, h, t, RIGHT, holes[RIGHT]);
		b.flat(x1, z0, x1 + t, z1, h, EDGE);
		if (!has_front) {
			b.end_z(x1, x1 + t, z1, h, 1.0f);
		}
	}
	if (has_front) {
		b.wall(Vector3(x0, 0, z1), Vector3(1, 0, 0), Vector3(0, 0, -1), w, h, t, FRONT, holes[FRONT]);
		b.flat(x0 - (has_left ? t : 0.0f), z1, x1 + (has_right ? t : 0.0f), z1 + t, h, EDGE);
	}

	Array arr;
	arr.resize(Mesh::ARRAY_MAX);
	arr[Mesh::ARRAY_VERTEX] = b.v;
	arr[Mesh::ARRAY_NORMAL] = b.n;
	arr[Mesh::ARRAY_TEX_UV2] = b.uv2;
	arr[Mesh::ARRAY_INDEX] = b.idx;
	Ref<ArrayMesh> m;
	m.instantiate();
	m->add_surface_from_arrays(Mesh::PRIMITIVE_TRIANGLES, arr);
	return m;
}

void RoomShell::_bind_methods() {
	ClassDB::bind_static_method("RoomShell", D_METHOD("build", "spec"), &RoomShell::build);
	ClassDB::bind_static_method("RoomShell", D_METHOD("face_id", "name"), &RoomShell::face_id);
	BIND_CONSTANT(BACK);
	BIND_CONSTANT(LEFT);
	BIND_CONSTANT(RIGHT);
	BIND_CONSTANT(FRONT);
	BIND_CONSTANT(FLOOR);
	BIND_CONSTANT(EDGE);
	BIND_CONSTANT(REVEAL);
}
