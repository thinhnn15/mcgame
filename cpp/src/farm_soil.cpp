#include "farm_soil.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>

#include <algorithm>

using namespace godot;

void FarmSoil::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_crop_table", "table"), &FarmSoil::set_crop_table);
	ClassDB::bind_method(D_METHOD("setup", "defs", "state"), &FarmSoil::setup);
	ClassDB::bind_method(D_METHOD("piece_of", "c"), &FarmSoil::piece_of);
	ClassDB::bind_method(D_METHOD("twin", "c"), &FarmSoil::twin);
	ClassDB::bind_method(D_METHOD("resolve", "c"), &FarmSoil::resolve);
	ClassDB::bind_method(D_METHOD("state_at", "c"), &FarmSoil::state_at);
	ClassDB::bind_method(D_METHOD("has_crop", "c"), &FarmSoil::has_crop);
	ClassDB::bind_method(D_METHOD("ripe", "c"), &FarmSoil::ripe);
	ClassDB::bind_method(D_METHOD("hoe", "c"), &FarmSoil::hoe);
	ClassDB::bind_method(D_METHOD("sow", "c", "crop"), &FarmSoil::sow);
	ClassDB::bind_method(D_METHOD("water", "c"), &FarmSoil::water);
	ClassDB::bind_method(D_METHOD("dig", "c"), &FarmSoil::dig);
	ClassDB::bind_method(D_METHOD("plant", "c", "crop", "stage"), &FarmSoil::plant);
	ClassDB::bind_method(D_METHOD("harvest", "c"), &FarmSoil::harvest);
	ClassDB::bind_method(D_METHOD("rain"), &FarmSoil::rain);
	ClassDB::bind_method(D_METHOD("next_day"), &FarmSoil::next_day);
	ClassDB::bind_method(D_METHOD("row_of", "c", "n", "dir"), &FarmSoil::row_of);
	ClassDB::bind_method(D_METHOD("soil_dict"), &FarmSoil::soil_dict);
	ClassDB::bind_method(D_METHOD("crops_dict"), &FarmSoil::crops_dict);
	ClassDB::bind_method(D_METHOD("fallow_dict"), &FarmSoil::fallow_dict);
	ClassDB::bind_method(D_METHOD("to_dict"), &FarmSoil::to_dict);
	ClassDB::bind_method(D_METHOD("from_dict", "d"), &FarmSoil::from_dict);
	ClassDB::bind_method(D_METHOD("weed_nights"), &FarmSoil::weed_nights);
}

FarmSoil::Soil FarmSoil::soil_of(const String &s) {
	if (s == "co") return CO;
	if (s == "xoi") return XOI;
	if (s == "kho") return KHO;
	if (s == "uot") return UOT;
	return NONE;
}

String FarmSoil::name_of(uint8_t s) {
	switch (s) {
		case CO: return "co";
		case XOI: return "xoi";
		case KHO: return "kho";
		case UOT: return "uot";
		default: return "";
	}
}

int FarmSoil::rnd(int lo, int hi) {
	seed ^= seed << 13;
	seed ^= seed >> 17;
	seed ^= seed << 5;
	if (hi <= lo) return lo;
	return lo + int(seed % uint32_t(hi - lo + 1));
}

void FarmSoil::set_crop_table(const Dictionary &t) {
	table.clear();
	const Array ids = t.keys();
	for (int i = 0; i < ids.size(); i++) {
		const String id = ids[i];
		const Variant v = t[id];
		if (v.get_type() != Variant::DICTIONARY) continue;
		const Dictionary d = v;
		Row r;
		const Array models = d.get("models", Array());
		r.stages = std::max(1, int(models.size()));
		const Array days = d.get("days", Array());
		for (int k = 0; k < days.size(); k++) r.days.push_back(int(days[k]));
		const Variant rg = d.get("regrow_to", Variant());
		r.regrow_to = rg.get_type() == Variant::NIL ? -1 : int(rg);
		const Array h = d.get("harvest", Array());
		if (h.size() >= 2) {
			r.lo = int(h[0]);
			r.hi = int(h[1]);
		}
		const Array fp = d.get("footprint", Array());
		r.big = fp.size() >= 2 && (int(fp[0]) >= 2 || int(fp[1]) >= 2);
		table[id.utf8().get_data()] = r;
	}
}

const FarmSoil::Row *FarmSoil::row(const String &id) const {
	auto it = table.find(id.utf8().get_data());
	return it == table.end() ? nullptr : &it->second;
}

void FarmSoil::setup(const Array &defs, const String &state) {
	beds.clear();
	soil.clear();
	fallow.clear();
	crops.clear();
	cover.clear();
	const uint8_t s = soil_of(state);
	for (int b = 0; b < defs.size(); b++) {
		const Array d = defs[b];
		Bed bed{int(d[0]), int(d[1]), int(d[2])};
		beds.push_back(bed);
		soil.emplace_back(bed.n, s);
		fallow.emplace_back(bed.n, 0);
	}
}

bool FarmSoil::valid(const Vector2i &pc) const {
	return pc.x >= 0 && pc.x < int(beds.size()) && pc.y >= 0 && pc.y < beds[pc.x].n;
}

Vector2i FarmSoil::piece_of(const Vector2i &c) const {
	for (int b = 0; b < int(beds.size()); b++) {
		const Bed &d = beds[b];
		if ((c.x == d.i || c.x == d.i + 1) && c.y >= d.j0 && c.y < d.j0 + d.n) return Vector2i(b, c.y - d.j0);
	}
	return Vector2i(-1, -1);
}

Vector2i FarmSoil::twin(const Vector2i &c) const {
	const Vector2i pc = piece_of(c);
	if (pc.x < 0) return c;
	const int i = beds[pc.x].i;
	return Vector2i(c.x == i ? i + 1 : i, c.y);
}

String FarmSoil::state_at(const Vector2i &c) const {
	const Vector2i pc = piece_of(c);
	return valid(pc) ? name_of(soil[pc.x][pc.y]) : String();
}

bool FarmSoil::has_crop(const Vector2i &c) const { return crops.count(key(c)) > 0 || cover.count(key(c)) > 0; }

Vector2i FarmSoil::resolve(const Vector2i &c) const {
	auto it = cover.find(key(c));
	return it == cover.end() ? c : cell_of(it->second);
}

void FarmSoil::rebuild_cover() {
	cover.clear();
	for (const auto &kv : crops) {
		const Row *r = row(kv.second.id);
		if (r == nullptr || !r->big) continue;
		const Vector2i a = cell_of(kv.first);
		for (int dx = 0; dx < 2; dx++)
			for (int dy = 0; dy < 2; dy++)
				if (dx || dy) cover[key(a + Vector2i(dx, dy))] = kv.first;
	}
}

bool FarmSoil::ripe(const Vector2i &c) const {
	auto it = crops.find(key(resolve(c)));
	if (it == crops.end()) return false;
	const Row *r = row(it->second.id);
	return r != nullptr && it->second.stage >= r->stages - 1;
}

bool FarmSoil::hoe(const Vector2i &c) {
	const Vector2i pc = piece_of(c);
	if (!valid(pc) || has_crop(c) || has_crop(twin(c))) return false;
	soil[pc.x][pc.y] = XOI;
	return true;
}

bool FarmSoil::sow(const Vector2i &c, const String &crop) {
	const Vector2i pc = piece_of(c);
	if (!valid(pc) || soil[pc.x][pc.y] == CO || has_crop(c)) return false;
	const Row *r = row(crop);
	if (r != nullptr && r->big) {
		const Bed &b = beds[pc.x];
		const int k = pc.y + 1 < b.n ? pc.y : pc.y - 1;
		if (k < 0 || b.n < 2) return false;
		if (soil[pc.x][k] == CO || soil[pc.x][k + 1] == CO) return false;
		const Vector2i a(b.i, b.j0 + k);
		for (int dx = 0; dx < 2; dx++)
			for (int dy = 0; dy < 2; dy++)
				if (has_crop(a + Vector2i(dx, dy))) return false;
		crops[key(a)] = Crop{crop, 0, 0};
		rebuild_cover();
		return true;
	}
	crops[key(c)] = Crop{crop, 0, 0};
	return true;
}

bool FarmSoil::water(const Vector2i &c) {
	const Vector2i pc = piece_of(c);
	if (!valid(pc) || soil[pc.x][pc.y] == CO || soil[pc.x][pc.y] == UOT) return false;
	soil[pc.x][pc.y] = UOT;
	return true;
}

String FarmSoil::dig(const Vector2i &c) {
	Vector2i cc = resolve(has_crop(c) ? c : twin(c));
	auto it = crops.find(key(cc));
	if (it == crops.end()) return String();
	const String id = it->second.id;
	const Row *r = row(id);
	const bool big = r != nullptr && r->big;
	crops.erase(it);
	for (int dy = 0; dy < (big ? 2 : 1); dy++) {
		const Vector2i pc = piece_of(cc + Vector2i(0, dy));
		if (valid(pc)) {
			soil[pc.x][pc.y] = XOI;
			fallow[pc.x][pc.y] = 0;
		}
	}
	if (big) rebuild_cover();
	return id;
}

void FarmSoil::plant(const Vector2i &c, const String &crop, int stage) {
	crops[key(c)] = Crop{crop, stage, 0};
	rebuild_cover();
}

Dictionary FarmSoil::harvest(const Vector2i &c) {
	Dictionary got;
	if (!ripe(c)) return got;
	auto it = crops.find(key(resolve(c)));
	const Row *r = row(it->second.id);
	got["crop"] = it->second.id;
	got["n"] = rnd(r->lo, r->hi);
	if (r->regrow_to >= 0) {
		it->second.stage = r->regrow_to;
		it->second.grown = 0;
	} else {
		const bool big = r->big;
		crops.erase(it);
		if (big) rebuild_cover();
	}
	return got;
}

void FarmSoil::rain() {
	for (auto &bed : soil)
		for (auto &s : bed)
			if (s != CO) s = UOT;
}

void FarmSoil::next_day() {
	for (auto &kv : crops) {
		Crop &cr = kv.second;
		const Vector2i pc = piece_of(cell_of(kv.first));
		const Row *r = row(cr.id);
		bool wet = valid(pc) && soil[pc.x][pc.y] == UOT;
		if (!wet && r != nullptr && r->big) {
			const Vector2i pc2 = piece_of(cell_of(kv.first) + Vector2i(0, 1));
			wet = valid(pc2) && soil[pc2.x][pc2.y] == UOT;
		}
		if (!wet) continue;
		if (r == nullptr || cr.stage >= int(r->days.size())) continue;
		cr.grown += 1;
		if (cr.grown >= r->days[cr.stage]) {
			cr.stage += 1;
			cr.grown = 0;
		}
	}
	for (int b = 0; b < int(beds.size()); b++) {
		const Bed &d = beds[b];
		for (int k = 0; k < d.n; k++) {
			uint8_t &s = soil[b][k];
			if (s == CO) {
				fallow[b][k] = 0;
				continue;
			}
			const int row_j = d.j0 + k;
			const bool empty = !has_crop(Vector2i(d.i, row_j)) && !has_crop(Vector2i(d.i + 1, row_j));
			if (!empty || s == XOI) {
				fallow[b][k] = 0;
				continue;
			}
			if (++fallow[b][k] >= WEED_NIGHTS) {
				s = CO;
				fallow[b][k] = 0;
			}
		}
	}
	for (auto &bed : soil)
		for (auto &s : bed)
			if (s == UOT || s == XOI) s = KHO;
}

Array FarmSoil::row_of(const Vector2i &c, int n, int dir) const {
	Array out;
	const Vector2i pc = piece_of(c);
	if (!valid(pc)) {
		out.push_back(c);
		return out;
	}
	const Bed &b = beds[pc.x];
	for (int m = 0; m < n; m++) {
		const int k = pc.y + m * dir;
		if (k >= 0 && k < b.n) out.push_back(Vector2i(b.i, b.j0 + k));
	}
	const int want = std::min(n, b.n);
	for (int m = 1; out.size() < want && m <= b.n; m++) {
		const int k = pc.y - m * dir;
		if (k >= 0 && k < b.n) out.push_back(Vector2i(b.i, b.j0 + k));
	}
	return out;
}

Dictionary FarmSoil::soil_dict() const {
	Dictionary d;
	for (int b = 0; b < int(beds.size()); b++)
		for (int k = 0; k < beds[b].n; k++) d[Vector2i(b, k)] = name_of(soil[b][k]);
	return d;
}

Dictionary FarmSoil::crops_dict() const {
	Dictionary d;
	for (const auto &kv : crops) {
		Dictionary cr;
		cr["crop"] = kv.second.id;
		cr["stage"] = kv.second.stage;
		cr["grown"] = kv.second.grown;
		d[cell_of(kv.first)] = cr;
	}
	return d;
}

Dictionary FarmSoil::fallow_dict() const {
	Dictionary d;
	for (int b = 0; b < int(beds.size()); b++)
		for (int k = 0; k < beds[b].n; k++)
			if (fallow[b][k] > 0) d[Vector2i(b, k)] = fallow[b][k];
	return d;
}

Dictionary FarmSoil::to_dict() const {
	Dictionary s, c, f;
	for (int b = 0; b < int(beds.size()); b++)
		for (int k = 0; k < beds[b].n; k++) {
			const String kk = String::num_int64(b) + "," + String::num_int64(k);
			s[kk] = name_of(soil[b][k]);
			if (fallow[b][k] > 0) f[kk] = fallow[b][k];
		}
	for (const auto &kv : crops) {
		const Vector2i cell = cell_of(kv.first);
		Dictionary cr;
		cr["crop"] = kv.second.id;
		cr["stage"] = kv.second.stage;
		cr["grown"] = kv.second.grown;
		c[String::num_int64(cell.x) + "," + String::num_int64(cell.y)] = cr;
	}
	Dictionary out;
	out["soil"] = s;
	out["crops"] = c;
	out["fallow"] = f;
	return out;
}

void FarmSoil::from_dict(const Dictionary &d) {
	const Dictionary s = d.get("soil", Dictionary());
	const Array sk = s.keys();
	for (int i = 0; i < sk.size(); i++) {
		const PackedStringArray v = String(sk[i]).split(",");
		if (v.size() < 2) continue;
		const Vector2i pc(v[0].to_int(), v[1].to_int());
		if (valid(pc)) soil[pc.x][pc.y] = soil_of(String(s[sk[i]]));
	}
	for (auto &bed : fallow) std::fill(bed.begin(), bed.end(), 0);
	const Dictionary f = d.get("fallow", Dictionary());
	const Array fk = f.keys();
	for (int i = 0; i < fk.size(); i++) {
		const PackedStringArray v = String(fk[i]).split(",");
		if (v.size() < 2) continue;
		const Vector2i pc(v[0].to_int(), v[1].to_int());
		if (valid(pc)) fallow[pc.x][pc.y] = int(f[fk[i]]);
	}
	crops.clear();
	const Dictionary c = d.get("crops", Dictionary());
	const Array ck = c.keys();
	for (int i = 0; i < ck.size(); i++) {
		const PackedStringArray v = String(ck[i]).split(",");
		if (v.size() < 2) continue;
		const Dictionary cr = c[ck[i]];
		crops[key(Vector2i(v[0].to_int(), v[1].to_int()))] =
				Crop{String(cr.get("crop", "")), int(cr.get("stage", 0)), int(cr.get("grown", 0))};
	}
	rebuild_cover();
}
