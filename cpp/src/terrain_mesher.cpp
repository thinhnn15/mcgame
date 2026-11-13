#include "terrain_mesher.h"

#include <godot_cpp/classes/mesh.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <vector>

using namespace godot;

void TerrainMesher::_bind_methods() {
	ClassDB::bind_static_method("TerrainMesher", D_METHOD("grid_mesh", "heights", "mats", "n", "half", "pal", "road_sdf", "rail_sdf", "x0", "z0", "cells", "step", "sink", "centre", "skirt"), &TerrainMesher::grid_mesh);
}

static const int NEIGHBOURS[12][2] = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 2, 0 }, { -2, 0 }, { 0, 2 }, { 0, -2 }, { 3, 0 }, { -3, 0 }, { 0, 3 }, { 0, -3 } };

Ref<ArrayMesh> TerrainMesher::grid_mesh(const PackedFloat32Array &heights, const PackedByteArray &mats, int n, int half,
		const Dictionary &pal, const PackedByteArray &road_sdf, const PackedByteArray &rail_sdf,
		int x0, int z0, int cells, int step, float sink, const Vector3 &centre, float skirt) {
	Ref<ArrayMesh> m;
	m.instantiate();
	ERR_FAIL_COND_V(heights.size() < n * n || mats.size() < n * n, m);
	const float *h = heights.ptr();
	const uint8_t *mt = mats.ptr();
	const bool road_on = road_sdf.size() == n * n;
	const bool rail_on = rail_sdf.size() == n * n;
	const uint8_t *rd = road_on ? road_sdf.ptr() : nullptr;

	Color palette[256];
	const Color magenta(1, 0, 1);
	for (int i = 0; i < 256; i++) {
		palette[i] = pal.has(i) ? (Color)pal[i] : (pal.has((double)i) ? (Color)pal[(double)i] : magenta);
	}
	auto height_at = [&](int gx, int gz) -> float {
		gx = gx < 0 ? 0 : (gx > n - 1 ? n - 1 : gx);
		gz = gz < 0 ? 0 : (gz > n - 1 ? n - 1 : gz);
		return h[gz * n + gx];
	};
	auto colour_at = [&](int gx, int gz) -> Color {

		int mat = mt[gz * n + gx];

		if (mat == ROAD && road_on && rd[gz * n + gx] < 96) {
			for (const int *d : NEIGHBOURS) {
				int x = gx + d[0];
				int z = gz + d[1];
				x = x < 0 ? 0 : (x > n - 1 ? n - 1 : x);
				z = z < 0 ? 0 : (z > n - 1 ? n - 1 : z);
				int o = mt[z * n + x];
				if (o != ROAD) {
					return palette[o];
				}
			}
			return palette[0];
		}
		if (mat == BALLAST && rail_on) {
			for (const int *d : NEIGHBOURS) {
				int x = gx + d[0];
				int z = gz + d[1];
				x = x < 0 ? 0 : (x > n - 1 ? n - 1 : x);
				z = z < 0 ? 0 : (z > n - 1 ? n - 1 : z);
				int o = mt[z * n + x];
				if (o != BALLAST) {
					return palette[o];
				}
			}
			return palette[BALLAST];
		}
		return palette[mat];
	};
	const int k = cells + 1;
	const int grid_count = k * k;
	PackedVector3Array verts;
	PackedVector3Array norms;
	PackedColorArray cols;
	PackedInt32Array idx;
	verts.resize(grid_count + 4 * k);
	norms.resize(grid_count + 4 * k);
	cols.resize(grid_count + 4 * k);
	idx.resize(cells * cells * 6 + 4 * (k - 1) * 6);
	Vector3 *vp = verts.ptrw();
	Vector3 *np = norms.ptrw();
	Color *cp = cols.ptrw();
	int32_t *ip = idx.ptrw();
	int v = 0;
	for (int j = 0; j < k; j++) {
		for (int i = 0; i < k; i++) {
			int gx = MIN(x0 + i * step, n - 1);
			int gz = MIN(z0 + j * step, n - 1);
			float hh = h[gz * n + gx];
			vp[v] = Vector3((float)(gx - half), hh - sink, (float)(gz - half)) - centre;
			float hl = height_at(gx - step, gz);
			float hr = height_at(gx + step, gz);
			float hd = height_at(gx, gz - step);
			float hu = height_at(gx, gz + step);
			np[v] = Vector3(hl - hr, 2.0f * step, hd - hu).normalized();
			cp[v] = colour_at(gx, gz);
			v++;
		}
	}
	int t = 0;
	for (int j = 0; j < cells; j++) {
		for (int i = 0; i < cells; i++) {
			int a = j * k + i;
			ip[t++] = a;
			ip[t++] = a + 1;
			ip[t++] = a + k;
			ip[t++] = a + 1;
			ip[t++] = a + k + 1;
			ip[t++] = a + k;
		}
	}

	std::vector<int> edge(k);
	for (int e = 0; e < 4; e++) {
		for (int i = 0; i < k; i++) {
			switch (e) {
				case 0: edge[i] = i; break;
				case 1: edge[i] = k * k - 1 - i; break;
				case 2: edge[i] = (k - 1 - i) * k; break;
				default: edge[i] = i * k + cells; break;
			}
		}
		int base = v;
		for (int i = 0; i < k; i++) {
			int src = edge[i];
			vp[v] = vp[src] - Vector3(0, skirt, 0);
			np[v] = np[src];
			cp[v] = cp[src];
			v++;
		}
		for (int s = 0; s < k - 1; s++) {
			int a = edge[s];
			int b = edge[s + 1];
			ip[t++] = a;
			ip[t++] = base + s;
			ip[t++] = b;
			ip[t++] = b;
			ip[t++] = base + s;
			ip[t++] = base + s + 1;
		}
	}
	Array arr;
	arr.resize(Mesh::ARRAY_MAX);
	arr[Mesh::ARRAY_VERTEX] = verts;
	arr[Mesh::ARRAY_NORMAL] = norms;
	arr[Mesh::ARRAY_COLOR] = cols;
	arr[Mesh::ARRAY_INDEX] = idx;
	m->add_surface_from_arrays(Mesh::PRIMITIVE_TRIANGLES, arr);
	return m;
}
