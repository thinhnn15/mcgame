#include "fruit_trees.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>

using namespace godot;

namespace {
int every_of(const Dictionary &kind) {
	return MAX(1, (int)kind.get("every", 3));
}

uint32_t mix(uint32_t a, uint32_t b) {
	uint32_t h = a * 0x9E3779B1u ^ (b + 0x7F4A7C15u + (a << 6) + (a >> 2));
	h ^= h >> 15;
	h *= 0x2C1B3C6Du;
	h ^= h >> 12;
	return h;
}
}

bool FruitTrees::in_season(const Dictionary &kind, int month) {
	const Array months = kind.get("months", Array());
	if (months.is_empty()) {
		return true;
	}
	for (int i = 0; i < months.size(); i++) {
		if ((int)months[i] == month) {
			return true;
		}
	}
	return false;
}

int FruitTrees::start(const Dictionary &kind, int seed, int today) {
	const int e = every_of(kind);
	return today - e + (int)(mix((uint32_t)seed, 17u) % (uint32_t)e);
}

bool FruitTrees::ripe(const Dictionary &kind, int last, int today, int month) {
	return in_season(kind, month) && today - last >= every_of(kind);
}

int FruitTrees::days_left(const Dictionary &kind, int last, int today, int month) {
	if (!in_season(kind, month)) {
		return -1;
	}
	return MAX(0, every_of(kind) - (today - last));
}

int FruitTrees::amount(const Dictionary &kind, int seed, int today) {
	const Array y = kind.get("yield", Array());
	int lo = 1, hi = 1;
	if (y.size() >= 2) {
		lo = MAX(1, (int)y[0]);
		hi = MAX(lo, (int)y[1]);
	}
	return lo + (int)(mix((uint32_t)seed, (uint32_t)today) % (uint32_t)(hi - lo + 1));
}

void FruitTrees::_bind_methods() {
	ClassDB::bind_static_method("FruitTrees", D_METHOD("in_season", "kind", "month"), &FruitTrees::in_season);
	ClassDB::bind_static_method("FruitTrees", D_METHOD("start", "kind", "seed", "today"), &FruitTrees::start);
	ClassDB::bind_static_method("FruitTrees", D_METHOD("ripe", "kind", "last", "today", "month"), &FruitTrees::ripe);
	ClassDB::bind_static_method("FruitTrees", D_METHOD("days_left", "kind", "last", "today", "month"), &FruitTrees::days_left);
	ClassDB::bind_static_method("FruitTrees", D_METHOD("amount", "kind", "seed", "today"), &FruitTrees::amount);
}
