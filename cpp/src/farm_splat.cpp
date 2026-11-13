#include "farm_splat.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/rect2.hpp>

#include <algorithm>
#include <cmath>
#include <vector>

using namespace godot;

namespace {
double smooth(double a, double b, double x) {
	if (a == b) return x < a ? 0.0 : 1.0;
	double t = std::clamp((x - a) / (b - a), 0.0, 1.0);
	return t * t * (3.0 - 2.0 * t);
}

double seg_dist(double px, double pz, double ax, double az, double bx, double bz) {
	const double abx = bx - ax, abz = bz - az;
	const double l2 = std::max(abx * abx + abz * abz, 1e-6);
	const double t = std::clamp(((px - ax) * abx + (pz - az) * abz) / l2, 0.0, 1.0);
	const double dx = px - (ax + abx * t), dz = pz - (az + abz * t);
	return std::sqrt(dx * dx + dz * dz);
}

double rect_e(const Rect2 &r, double x, double z) {
	return std::max(std::max(r.position.x - x, x - (r.position.x + r.size.x)),
			std::max(r.position.y - z, z - (r.position.y + r.size.y)));
}

uint8_t byte(double v) {
	return (uint8_t)std::lround(std::clamp(v, 0.0, 1.0) * 255.0);
}

struct Seg {
	double ax, az, bx, bz, half;
};
}

PackedByteArray FarmSplat::paint(double size, int px, const Array &paths, const Array &earth_rects, const Array &worn_circles,
		const Array &worn_rects, double ditch_z, const Vector2 &pond_c, const Vector2 &pond_r) {
	std::vector<Seg> segs;
	for (int i = 0; i < paths.size(); i++) {
		const Array pa = paths[i];
		const Array pts = pa[0];
		const double half = double(pa[1]) * 0.5;
		for (int k = 0; k + 1 < pts.size(); k++) {
			const Vector2 a = pts[k], b = pts[k + 1];
			segs.push_back({a.x, a.y, b.x, b.y, half});
		}
	}
	std::vector<Rect2> earth;
	for (int i = 0; i < earth_rects.size(); i++) earth.push_back(Rect2(Array(earth_rects[i])[0]));
	struct Circ { double x, z, r, w; };
	std::vector<Circ> circs;
	for (int i = 0; i < worn_circles.size(); i++) {
		const Array c = worn_circles[i];
		const Vector2 p = c[0];
		circs.push_back({p.x, p.y, double(c[1]), double(c[2])});
	}
	struct WRect { Rect2 r; double w; };
	std::vector<WRect> wrects;
	for (int i = 0; i < worn_rects.size(); i++) {
		const Array w = worn_rects[i];
		wrects.push_back({Rect2(w[0]), double(w[1])});
	}
	PackedByteArray out;
	out.resize(px * px * 4);
	uint8_t *o = out.ptrw();
	const double step = size / px;
	for (int j = 0; j < px; j++) {
		const double z = -size / 2 + (j + 0.5) * step;
		for (int i = 0; i < px; i++) {
			const double x = -size / 2 + (i + 0.5) * step;
			double r = 0.0;
			for (const Seg &s : segs) {
				const double d = seg_dist(x, z, s.ax, s.az, s.bx, s.bz);
				if (d > s.half + 0.3) continue;
				double track = 1.0 - smooth(s.half - 0.15, s.half + 0.3, d);
				if (s.half > 0.4) track *= 0.55 + 0.45 * smooth(0.08, 0.26, d);
				r = std::max(r, track);
			}
			for (const Rect2 &er : earth) r = std::max(r, 1.0 - smooth(-0.45, 0.2, rect_e(er, x, z)));
			double g = 0.0;
			for (const Circ &c : circs) {
				const double d = std::sqrt((x - c.x) * (x - c.x) + (z - c.z) * (z - c.z));
				g = std::max(g, (1.0 - smooth(c.r * 0.55, c.r, d)) * c.w);
			}
			for (const WRect &w : wrects) g = std::max(g, (1.0 - smooth(-0.3, 0.6, rect_e(w.r, x, z))) * w.w);
			double b = std::exp(-std::pow((z - ditch_z) / 1.8, 2.0));
			const double qx = (x - pond_c.x) / pond_r.x, qz = (z - pond_c.y) / pond_r.y;
			const double pe = qx * qx + qz * qz;
			b = std::max(b, std::exp(-std::pow((pe - 1.0) / 0.5, 2.0)));
			g = std::max(g, std::exp(-std::pow((pe - 1.02) / 0.09, 2.0)) * 0.7);
			uint8_t *p = o + (j * px + i) * 4;
			p[0] = byte(r);
			p[1] = byte(g);
			p[2] = byte(b);
			p[3] = 255;
		}
	}
	return out;
}

void FarmSplat::_bind_methods() {
	ClassDB::bind_static_method("FarmSplat",
			D_METHOD("paint", "size", "px", "paths", "earth_rects", "worn_circles", "worn_rects", "ditch_z", "pond_c", "pond_r"),
			&FarmSplat::paint);
}
