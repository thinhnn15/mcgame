#include "pen_work.h"

#include "home_work.h"
#include "mc_common.h"
#include "progress.h"
#include "stock.h"

#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

namespace {
const char *CATALOG = "res://data/farm/chuong.json";
const char *BOOKED = "pen_work_booked";
const char *BUILT = "pen_work_built";
const char *BUILDING = "chuong_dang_xay";
const char *BUILD_DAY = "chuong_xay_ngay";
const char *BUILD_LAST = "chuong_xay_cuoi";
const char *DAY_FLAG = "lam_tho_chuong_ngay";

Variant story_flag(const String &key, const Variant &def) {
	Ref<Script> st = mc::Scripts::story_gd();
	if (st.is_null()) {
		return def;
	}
	st->call("load_saved");
	return st->call("flag", key, def);
}

void story_set(const String &key, const Variant &value) {
	Ref<Script> st = mc::Scripts::story_gd();
	if (st.is_valid()) {
		st->call("set_flag", key, value);
	}
}

int clock_day() {
	Ref<Script> c = mc::Scripts::clock_gd();
	return c.is_valid() ? (int)c->get("day") : 1;
}

bool clock_wet() {
	Ref<Script> c = mc::Scripts::clock_gd();
	return c.is_valid() && !String(c->get("weather")).is_empty();
}
}

Dictionary *PenWork::cache = nullptr;

Dictionary PenWork::kinds() {
	if (!cache) {
		cache = new Dictionary();
		const String text = FileAccess::get_file_as_string(CATALOG);
		const Variant v = JSON::parse_string(text);
		if (v.get_type() == Variant::DICTIONARY) {
			*cache = Dictionary(v).get("kinds", Dictionary());
		}
	}
	return *cache;
}

void PenWork::finish() {
	delete cache;
	cache = nullptr;
}

Dictionary PenWork::kind(const String &id) {
	return kinds().get(id, Dictionary());
}

bool PenWork::home_busy() {
	return !HomeWork::booked().is_empty();
}

Dictionary PenWork::check(const String &kind_id) {
	Dictionary c;
	const Dictionary k = kind(kind_id);
	c["ok"] = false;
	c["reason"] = "";
	c["days"] = MAX(1, (int)k.get("days", 1));
	c["fee"] = (int)k.get("fee", 0);
	c["money"] = Progress::money();
	c["with_tho"] = true;
	Dictionary needs_out;
	const Dictionary needs = k.get("needs", Dictionary());
	const Array mk = needs.keys();
	bool have_all = true;
	for (int i = 0; i < mk.size(); i++) {
		const int have = Stock::count(mk[i]);
		const int need = int(needs[mk[i]]);
		Array pair;
		pair.push_back(have);
		pair.push_back(need);
		needs_out[mk[i]] = pair;
		if (have < need) {
			have_all = false;
		}
	}
	c["needs"] = needs_out;
	const bool money_ok = Progress::money() >= int(k.get("fee", 0));
	c["money_ok"] = money_ok;
	if (k.is_empty()) {
		c["reason"] = "locked";
		return c;
	}
	const String unlock = k.get("unlock", "");
	if (!unlock.is_empty() && !Progress::is_open(unlock)) {
		c["reason"] = "locked";
	} else if (home_busy() || !booked().is_empty()) {
		c["reason"] = "busy";
	} else if (!have_all) {
		c["reason"] = "materials";
	} else if (!money_ok) {
		c["reason"] = "money";
	} else {
		c["ok"] = true;
	}
	return c;
}

bool PenWork::book(const String &kind_id, const Vector2i &cell, int rot, int pen, int start) {
	sync();
	const Dictionary c = check(kind_id);
	if (!(bool)c["ok"]) {
		return false;
	}
	const Dictionary k = kind(kind_id);
	const Dictionary needs = k.get("needs", Dictionary());
	const int fee = k.get("fee", 0);
	if (!Stock::take(needs)) {
		return false;
	}
	if (!Progress::spend(fee)) {
		const Array m = needs.keys();
		for (int i = 0; i < m.size(); i++) {
			Stock::add(m[i], needs[m[i]]);
		}
		return false;
	}
	Dictionary b;
	b["kind"] = kind_id;
	Array cl;
	cl.push_back(cell.x);
	cl.push_back(cell.y);
	b["cell"] = cl;
	b["rot"] = rot;
	b["pen"] = pen;
	b["day"] = MAX(start, clock_day() + 1);
	b["days"] = MAX(1, (int)k.get("days", 1));
	b["built"] = 0;
	b["last"] = -1;
	b["dry"] = false;
	story_set(BOOKED, b);
	story_set(DAY_FLAG, (int)b["day"]);
	return true;
}

Dictionary PenWork::booked() {
	const Variant v = story_flag(BOOKED, Dictionary());
	return v.get_type() == Variant::DICTIONARY ? Dictionary(v) : Dictionary();
}

bool PenWork::cancel() {
	const Dictionary b = booked();
	if (b.is_empty() || clock_day() >= (int)b["day"]) {
		return false;
	}
	const Dictionary k = kind(b["kind"]);
	const Dictionary needs = k.get("needs", Dictionary());
	const Array m = needs.keys();
	for (int i = 0; i < m.size(); i++) {
		Stock::add(m[i], needs[m[i]]);
	}
	Progress::earn(k.get("fee", 0));
	clear_booking();
	return true;
}

void PenWork::clear_booking() {
	story_set(BOOKED, Dictionary());
	story_set(DAY_FLAG, -1);
	if (!String(story_flag(BUILDING, "")).is_empty()) {
		story_set(BUILDING, "");
	}
	if ((int)story_flag(BUILD_DAY, 0) != 0) {
		story_set(BUILD_DAY, 0);
	}
	if ((bool)story_flag(BUILD_LAST, false)) {
		story_set(BUILD_LAST, false);
	}
}

void PenWork::advance(Dictionary b) {
	const int today = clock_day();
	const int start = b.get("day", today);
	const int days = MAX(1, (int)b.get("days", 1));
	int built = b.get("built", 0);
	const int last = b.get("last", -1);
	if (today < start || last == today) {
		return;
	}
	if (last >= start) {
		built += ((bool)b.get("dry", false) ? 1 : 0) + MAX(0, today - 1 - last);
	} else {
		built += MAX(0, today - start);
	}
	if (built >= days) {
		Dictionary done;
		done["kind"] = b["kind"];
		done["cell"] = b["cell"];
		done["rot"] = b["rot"];
		done["pen"] = b.get("pen", -1);
		Variant bv = story_flag(BUILT, Array());
		Array list = bv.get_type() == Variant::ARRAY ? Array(bv) : Array();
		list.push_back(done);
		story_set(BUILT, list);
		clear_booking();
		return;
	}
	const bool wet = clock_wet();
	b["built"] = built;
	b["last"] = today;
	b["dry"] = !wet;
	story_set(BOOKED, b);
	story_set(DAY_FLAG, wet ? -1 : today);
	story_set(BUILDING, b["kind"]);
	story_set(BUILD_DAY, built + 1);
	story_set(BUILD_LAST, !wet && built + 1 == days);
}

void PenWork::sync() {
	const Dictionary b = booked();
	if (!b.is_empty()) {
		advance(b);
	}
}

bool PenWork::busy() {
	return home_busy() || !booked().is_empty();
}

Array PenWork::take_built() {
	const Variant v = story_flag(BUILT, Array());
	const Array out = v.get_type() == Variant::ARRAY ? Array(v).duplicate() : Array();
	if (!out.is_empty()) {
		story_set(BUILT, Array());
	}
	return out;
}

void PenWork::_bind_methods() {
	ClassDB::bind_static_method("PenWork", D_METHOD("check", "kind"), &PenWork::check);
	ClassDB::bind_static_method("PenWork", D_METHOD("book", "kind", "cell", "rot", "pen", "start"), &PenWork::book, DEFVAL(-1));
	ClassDB::bind_static_method("PenWork", D_METHOD("booked"), &PenWork::booked);
	ClassDB::bind_static_method("PenWork", D_METHOD("cancel"), &PenWork::cancel);
	ClassDB::bind_static_method("PenWork", D_METHOD("sync"), &PenWork::sync);
	ClassDB::bind_static_method("PenWork", D_METHOD("busy"), &PenWork::busy);
	ClassDB::bind_static_method("PenWork", D_METHOD("take_built"), &PenWork::take_built);
}
