#include "pave_grid.h"

#include <godot_cpp/classes/mesh.hpp>
#include <godot_cpp/classes/multi_mesh.hpp>
#include <godot_cpp/classes/multi_mesh_instance3d.hpp>
#include <godot_cpp/core/class_db.hpp>

#include <cmath>
#include <limits>

using namespace godot;

void PaveGrid::_bind_methods() {
	ClassDB::bind_method(D_METHOD("add", "xf", "box"), &PaveGrid::add);
	ClassDB::bind_method(D_METHOD("add_multimesh", "mmi"), &PaveGrid::add_multimesh);
	ClassDB::bind_method(D_METHOD("top", "x", "y", "z"), &PaveGrid::top);
	ClassDB::bind_method(D_METHOD("count"), &PaveGrid::count);
	ClassDB::bind_method(D_METHOD("cell_count"), &PaveGrid::cell_count);
	ClassDB::bind_method(D_METHOD("clear"), &PaveGrid::clear);
}

void PaveGrid::add(const Transform3D &xf, const AABB &box) {
	Tile t;
	t.xf = xf;
	t.inv = xf.affine_inverse();
	t.x0 = box.position.x;
	t.x1 = box.position.x + box.size.x;
	t.z0 = box.position.z;
	t.z1 = box.position.z + box.size.z;
	t.top = (box.position.y + box.size.y) * 0.8f;
	const int32_t id = int32_t(tiles.size());
	tiles.push_back(t);

	float mnx = 1e30f, mxx = -1e30f, mnz = 1e30f, mxz = -1e30f;
	for (int i = 0; i < 4; i++) {
		const Vector3 w = xf.xform(Vector3((i & 1) ? t.x1 : t.x0, t.top, (i & 2) ? t.z1 : t.z0));
		mnx = std::fmin(mnx, w.x);
		mxx = std::fmax(mxx, w.x);
		mnz = std::fmin(mnz, w.z);
		mxz = std::fmax(mxz, w.z);
	}
	const int32_t cx0 = int32_t(std::floor(mnx / cell)), cx1 = int32_t(std::floor(mxx / cell));
	const int32_t cz0 = int32_t(std::floor(mnz / cell)), cz1 = int32_t(std::floor(mxz / cell));
	for (int32_t cx = cx0; cx <= cx1; cx++) {
		for (int32_t cz = cz0; cz <= cz1; cz++) {
			cells[key(cx, cz)].push_back(id);
		}
	}
}

int PaveGrid::add_multimesh(Object *obj) {
	MultiMeshInstance3D *mmi = Object::cast_to<MultiMeshInstance3D>(obj);
	if (mmi == nullptr) {
		return 0;
	}
	Ref<MultiMesh> mm = mmi->get_multimesh();
	if (mm.is_null() || mm->get_mesh().is_null()) {
		return 0;
	}
	const AABB box = mm->get_mesh()->get_aabb();
	const Transform3D g = mmi->get_global_transform();
	const int n = mm->get_instance_count();
	tiles.reserve(tiles.size() + n);
	for (int i = 0; i < n; i++) {
		add(g * mm->get_instance_transform(i), box);
	}
	return n;
}

float PaveGrid::top(float x, float y, float z) const {
	const auto it = cells.find(key(int32_t(std::floor(x / cell)), int32_t(std::floor(z / cell))));
	float best = -std::numeric_limits<float>::infinity();
	if (it == cells.end()) {
		return best;
	}
	const Vector3 q(x, y, z);
	for (const int32_t id : it->second) {
		const Tile &t = tiles[id];
		const Vector3 l = t.inv.xform(q);
		if (l.x >= t.x0 && l.x <= t.x1 && l.z >= t.z0 && l.z <= t.z1) {
			best = std::fmax(best, t.xf.xform(Vector3(l.x, t.top, l.z)).y);
		}
	}
	return best;
}
