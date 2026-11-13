#include "tea_rows.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>

#include <cmath>

using namespace godot;

namespace {
uint32_t mix(uint32_t a, uint32_t b) {
	uint32_t h = a * 0x9E3779B1u ^ (b + 0x7F4A7C15u + (a << 6) + (a >> 2));
	h ^= h >> 15;
	h *= 0x2C1B3C6Du;
	h ^= h >> 12;
	return h;
}
}

bool TeaRows::ready(const Dictionary &cfg, int last, int today) {
	return today - last >= MAX(1, (int)cfg.get("every", 2));
}

Dictionary TeaRows::pick(const Dictionary &cfg, int seed, int today, double hour, bool wet, bool with_ba) {
	const Array y = cfg.get("yield", Array());
	int lo = 2, hi = 3;
	if (y.size() >= 2) {
		lo = MAX(1, (int)y[0]);
		hi = MAX(lo, (int)y[1]);
	}
	int n = lo + (int)(mix((uint32_t)seed, (uint32_t)today) % (uint32_t)(hi - lo + 1));
	const bool dew = !wet && hour < (double)cfg.get("dew_until", 8.0);
	if (dew) n += (int)cfg.get("dew_bonus", 1);
	if (with_ba) n += (int)cfg.get("ba_bonus", 1);
	Dictionary out;
	out["n"] = n;
	out["dew"] = dew;
	out["ba"] = with_ba;
	return out;
}

Dictionary TeaRows::roast(const Dictionary &cfg, const PackedFloat32Array &offsets) {
	const Dictionary r = cfg.get("roast", Dictionary());
	const double window = (double)r.get("window", 0.18);
	int good = 0;
	for (int i = 0; i < offsets.size(); i++) {
		if (std::fabs((double)offsets[i]) <= window) good++;
	}
	Dictionary out;
	out["good"] = good;
	out["fine"] = good >= (int)r.get("good_for_fine", 2);
	return out;
}

void TeaRows::_bind_methods() {
	ClassDB::bind_static_method("TeaRows", D_METHOD("ready", "cfg", "last", "today"), &TeaRows::ready);
	ClassDB::bind_static_method("TeaRows", D_METHOD("pick", "cfg", "seed", "today", "hour", "wet", "with_ba"), &TeaRows::pick);
	ClassDB::bind_static_method("TeaRows", D_METHOD("roast", "cfg", "offsets"), &TeaRows::roast);
}
