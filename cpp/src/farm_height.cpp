#include "farm_height.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>

#include <algorithm>
#include <cmath>

using namespace godot;

namespace {
double smooth(double a, double b, double x) {
	if (a == b) return a;
	const double t = std::clamp((x - a) / (b - a), 0.0, 1.0);
	return t * t * (3.0 - 2.0 * t);
}
}

void FarmHeight::configure(const Dictionary &d) {
	noise.instantiate();
	noise->set_seed(int(d.get("seed", 7)));
	noise->set_frequency(double(d.get("frequency", 0.045)));
	flat = d.get("flat", Rect2());
	ditch_z = d.get("ditch_z", 6.6);
	pond_c = d.get("pond_c", Vector2());
	pond_r = d.get("pond_r", Vector2(1, 1));
	pads.clear();
	sinks.clear();
	const Array p = d.get("pads", Array());
	for (int i = 0; i < p.size(); i++) {
		const Array a = p[i];
		pads.push_back({Rect2(a[0]), double(a[1])});
	}
	const Array s = d.get("sinks", Array());
	for (int i = 0; i < s.size(); i++) {
		const Array a = s[i];
		sinks.push_back({Rect2(a[0]), double(a[1])});
	}
}

double FarmHeight::height(double x, double z) const {
	const double dx = std::max(std::max(flat.position.x - x, x - (flat.position.x + flat.size.x)), 0.0);
	const double dz = std::max(std::max(flat.position.y - z, z - (flat.position.y + flat.size.y)), 0.0);
	const double out = smooth(0.0, 3.0, std::sqrt(dx * dx + dz * dz));
	double h = (double(noise.is_valid() ? noise->get_noise_2d(x, z) : 0.0f) * 0.9 + 0.35) * out;
	h += smooth(-7.0, -15.0, z) * 2.4;
	for (const Pad &pd : pads) {
		const Rect2 &r = pd.r;
		const double ex = std::max(std::max(r.position.x - x, x - (r.position.x + r.size.x)), 0.0);
		const double ez = std::max(std::max(r.position.y - z, z - (r.position.y + r.size.y)), 0.0);
		h *= smooth(0.0, pd.edge, std::sqrt(ex * ex + ez * ez));
	}
	h *= 1.0 - std::exp(-std::pow((z - ditch_z) / 1.3, 2.0));
	for (const Pad &sk : sinks) {
		const Rect2 &r = sk.r;
		const double e = std::max(std::max(r.position.x - x, x - (r.position.x + r.size.x)),
				std::max(r.position.y - z, z - (r.position.y + r.size.y)));
		h -= sk.edge * (1.0 - smooth(-0.25, 0.0, e));
	}
	h -= 0.62 * std::exp(-std::pow((z - ditch_z) / 0.75, 2.0));
	const double qx = (x - pond_c.x) / pond_r.x, qz = (z - pond_c.y) / pond_r.y;
	const double w = 1.0 - smooth(0.6, 1.25, qx * qx + qz * qz);
	return h + (-0.62 - h) * w;
}

PackedFloat32Array FarmHeight::grid(double x0, double z0, double step, int nx, int nz) const {
	PackedFloat32Array out;
	out.resize(nx * nz);
	float *o = out.ptrw();
	for (int j = 0; j < nz; j++)
		for (int i = 0; i < nx; i++) o[j * nx + i] = float(height(x0 + i * step, z0 + j * step));
	return out;
}

void FarmHeight::_bind_methods() {
	ClassDB::bind_method(D_METHOD("configure", "d"), &FarmHeight::configure);
	ClassDB::bind_method(D_METHOD("height", "x", "z"), &FarmHeight::height);
	ClassDB::bind_method(D_METHOD("grid", "x0", "z0", "step", "nx", "nz"), &FarmHeight::grid);
}
