#include "home_work.h"
#include "mc_common.h"
#include "progress.h"
#include "stock.h"

#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

namespace {

const char *UPGRADES_PATH = "res://data/home/upgrades.json";
const char *FINISH_PATH = "res://data/home/finish.json";
const char *DONE = "home_fixes_done";
const char *BOOKED = "home_work_booked";
const char *WORKED = "home_work_worked";
const char *DAY_FLAG = "lam_tho_ngay";
const char *RECEIVED = "home_received";
const char *BUILDING = "nha_dang_xay";
const char *BUILD_DAY = "nha_xay_ngay";
const char *BUILD_LAST = "nha_xay_cuoi";
const char *LEVELS_V = "home_levels_v";

Dictionary read_json(const char *path) {
	if (!FileAccess::file_exists(path))
		return Dictionary();
	Variant v = JSON::parse_string(FileAccess::get_file_as_string(path));
	return v.get_type() == Variant::DICTIONARY ? (Dictionary)v : Dictionary();
}

Dictionary &upgrades() {
	static Dictionary *d = nullptr;
	if (d == nullptr)
		d = new Dictionary(read_json(UPGRADES_PATH));
	return *d;
}

Dictionary &finish_rules() {
	static Dictionary *d = nullptr;
	if (d == nullptr)
		d = new Dictionary(read_json(FINISH_PATH));
	return *d;
}

Dictionary work_rules() {
	return upgrades().get("work", Dictionary());
}

Variant story_flag(const String &key, const Variant &def) {
	Ref<Script> st = mc::Scripts::story_gd();
	if (st.is_null())
		return def;
	st->call("load_saved");
	return st->call("flag", key, def);
}

void story_set(const String &key, const Variant &value) {
	Ref<Script> st = mc::Scripts::story_gd();
	if (st.is_valid())
		st->call("set_flag", key, value);
}

int clock_day() {
	Ref<Script> c = mc::Scripts::clock_gd();
	return c.is_valid() ? (int)c->get("day") : 1;
}

bool clock_wet() {
	Ref<Script> c = mc::Scripts::clock_gd();
	return c.is_valid() && !String(c->get("weather")).is_empty();
}

int level_of(const String &id) {
	return id.begins_with("nha_muc_") ? (int)id.trim_prefix("nha_muc_").to_int() : 0;
}

Ref<Script> script_at(const char *path) {
	return ResourceLoader::get_singleton()->load(path);
}

String hero_job() {
	Ref<Script> h = script_at("res://scripts/hero.gd");
	return h.is_valid() ? String(h->get("job")) : String("dev");
}

void kho_receive(const String &id) {
	Ref<Script> d = script_at("res://scripts/home/decor_room.gd");
	if (d.is_valid())
		d->call("receive", "nha_cu", id);
}

void mark_event_done(const String &event_id) {
	Ref<Script> h = script_at("res://scripts/home/home_events.gd");
	if (h.is_null())
		return;
	h->call("load_saved");
	Array done = h->get("done");
	if (!done.has(event_id)) {
		done.push_back(event_id);
		h->set("done", done);
		h->call("save");
	}
}

Dictionary unlock_row(const String &id) {
	Array rows = Progress::unlocks().get("items", Array());
	for (int i = 0; i < rows.size(); i++) {
		Dictionary r = rows[i];
		if (String(r.get("id", "")) == id)
			return r;
	}
	return Dictionary();
}

}

Dictionary HomeWork::entry(const String &id) {
	for (const char *list : { "levels", "fixes" }) {
		Array a = upgrades().get(list, Array());
		for (int i = 0; i < a.size(); i++) {
			Dictionary e = a[i];
			if (String(e.get("id", "")) == id)
				return e;
		}
	}
	return Dictionary();
}

bool HomeWork::with_tho(const Dictionary &e) {
	String tho = work_rules().get("tho", "chu_tam");
	Array h = e.get("helpers", Array());
	for (int i = 0; i < h.size(); i++) {
		Array one = h[i];
		if (one.size() > 0 && String(one[0]) == tho)
			return true;
	}
	return false;
}

bool HomeWork::page_open(const Dictionary &e, const Array &done) {
	Variant u = e.get("unlock", Variant());
	if (u.get_type() != Variant::STRING || !Progress::is_open(u))
		return false;
	String pre = unlock_row(u).get("needs", "");
	return pre.is_empty() || entry(pre).is_empty() || done.has(pre);
}

Array HomeWork::done() {
	Variant v = story_flag(DONE, Array());
	return v.get_type() == Variant::ARRAY ? ((Array)v).duplicate() : Array();
}

void HomeWork::add_done(const String &id) {
	Array d = done();
	if (!d.has(id)) {
		d.push_back(id);
		story_set(DONE, d);
	}
}

int HomeWork::level() {
	sync();
	Array d = done();
	int lv = 0;
	for (int i = 0; i < d.size(); i++) {
		String id = d[i];
		if (id.begins_with("nha_muc_"))
			lv = MAX(lv, (int)id.trim_prefix("nha_muc_").to_int());
	}
	return lv;
}

Array HomeWork::pages() {
	sync();
	Array d = done();
	Array out;
	for (const char *list : { "levels", "fixes" }) {
		Array a = upgrades().get(list, Array());
		for (int i = 0; i < a.size(); i++) {
			Dictionary e = a[i];
			String id = e.get("id", "");
			bool is_done = d.has(id);
			if (is_done || page_open(e, d)) {
				Dictionary p;
				p["id"] = id;
				p["kind"] = String(list) == "levels" ? "level" : "fix";
				p["done"] = is_done;
				out.push_back(p);
			}
		}
	}
	return out;
}

Dictionary HomeWork::check(const String &id) {
	Dictionary c;
	Dictionary e = entry(id);
	c["id"] = id;
	c["ok"] = false;
	if (e.is_empty() || e.get("unlock", Variant()).get_type() != Variant::STRING) {
		c["reason"] = "unknown";
		return c;
	}
	Array d = done();
	Dictionary b = booked();
	String reason = "";
	if (d.has(id))
		reason = "done";
	else if (!Progress::is_open(e["unlock"]))
		reason = "locked";
	else if (!page_open(e, d))
		reason = "needs";
	else if (e.has("job")) {
		Dictionary jobs = work_rules().get("jobs", Dictionary());
		if (String(jobs.get(e["job"], e["job"])) != hero_job())
			reason = "job";
	}
	if (reason.is_empty() && !b.is_empty())
		reason = String(b["id"]) == id ? "booked" : "busy";

	Dictionary needs, missing;
	Dictionary want = e.get("needs", Dictionary());
	Array mats = want.keys();
	for (int i = 0; i < mats.size(); i++) {
		int have = Stock::count(mats[i]);
		int need = want[mats[i]];
		Array pair;
		pair.push_back(have);
		pair.push_back(need);
		needs[mats[i]] = pair;
		if (have < need)
			missing[mats[i]] = need - have;
	}
	int fee = e.get("fee", 0);
	int money = Progress::money();
	c["days"] = MAX(1, (int)e.get("days", 1));
	if (reason.is_empty() && !missing.is_empty())
		reason = "materials";
	if (reason.is_empty() && money < fee)
		reason = "money";

	Array helpers;
	Array h = e.get("helpers", Array());
	for (int i = 0; i < h.size(); i++) {
		Array one = h[i];
		Dictionary p;
		String who = one[0];
		int min_hearts = one.size() > 1 ? (int)one[1] : 0;
		p["who"] = who;
		p["hearts"] = min_hearts;
		p["have"] = Progress::hearts(who);
		p["comes"] = Progress::hearts(who) >= min_hearts;
		helpers.push_back(p);
	}
	c["ok"] = reason.is_empty();
	c["reason"] = reason;
	c["needs"] = needs;
	c["missing"] = missing;
	c["fee"] = fee;
	c["money"] = money;
	c["money_ok"] = money >= fee;
	c["helpers"] = helpers;
	c["with_tho"] = with_tho(e);
	return c;
}

Dictionary HomeWork::booked() {
	Variant v = story_flag(BOOKED, Dictionary());
	return v.get_type() == Variant::DICTIONARY ? ((Dictionary)v).duplicate() : Dictionary();
}

bool HomeWork::book(const String &id, int start) {
	sync();
	Dictionary c = check(id);
	if (!(bool)c["ok"])
		return false;
	Dictionary e = entry(id);
	Dictionary needs = e.get("needs", Dictionary());
	int fee = e.get("fee", 0);
	if (!Stock::take(needs))
		return false;
	if (!Progress::spend(fee)) {
		Array m = needs.keys();
		for (int i = 0; i < m.size(); i++)
			Stock::add(m[i], needs[m[i]]);
		return false;
	}
	if (!with_tho(e)) {
		finish_job(id, false);
		return true;
	}
	Dictionary b;
	b["id"] = id;
	b["day"] = MAX(start, clock_day() + 1);
	b["days"] = MAX(1, (int)e.get("days", 1));
	b["built"] = 0;
	b["last"] = -1;
	b["dry"] = false;
	story_set(BOOKED, b);
	story_set(WORKED, false);
	story_set(DAY_FLAG, (int)b["day"]);
	Array helpers = c["helpers"];
	for (int i = 0; i < helpers.size(); i++) {
		Dictionary p = helpers[i];
		story_set("lam_tho_" + String(p["who"]), (bool)p["comes"]);
	}
	return true;
}

bool HomeWork::cancel() {
	Dictionary b = booked();
	if (b.is_empty() || clock_day() >= (int)b["day"])
		return false;
	Dictionary e = entry(b["id"]);
	Dictionary needs = e.get("needs", Dictionary());
	Array m = needs.keys();
	for (int i = 0; i < m.size(); i++)
		Stock::add(m[i], needs[m[i]]);
	Progress::earn(e.get("fee", 0));
	clear_booking();
	return true;
}

void HomeWork::clear_booking() {
	story_set(BOOKED, Dictionary());
	story_set(WORKED, false);
	story_set(DAY_FLAG, -1);
	if ((int)story_flag(BUILDING, 0) != 0)
		story_set(BUILDING, 0);
	if ((int)story_flag(BUILD_DAY, 0) != 0)
		story_set(BUILD_DAY, 0);
	if ((bool)story_flag(BUILD_LAST, false))
		story_set(BUILD_LAST, false);
}

void HomeWork::migrate() {

	if ((int)story_flag(LEVELS_V, 1) >= 2)
		return;
	static const int to[] = { 0, 1, 3, 5, 7 };
	Array d = done();
	Array out;
	bool changed = false;
	for (int i = 0; i < d.size(); i++) {
		String id = d[i];
		int n = level_of(id);
		if (n >= 2 && n <= 4) {
			id = "nha_muc_" + String::num_int64(to[n]);
			changed = true;
		}
		if (!out.has(id))
			out.push_back(id);
	}
	if (changed)
		story_set(DONE, out);
	int sl = story_flag("nha_muc", 0);
	if (sl >= 2 && sl <= 4)
		story_set("nha_muc", to[sl]);
	Dictionary b = booked();
	if (!b.is_empty()) {
		int n = level_of(b["id"]);
		if (n >= 2 && n <= 4) {
			b["id"] = "nha_muc_" + String::num_int64(to[n]);
			story_set(BOOKED, b);
		}
	}
	story_set(LEVELS_V, 2);
}

void HomeWork::advance(Dictionary b) {

	String id = b["id"];
	int today = clock_day();
	int start = b.get("day", today);
	int days = MAX(1, (int)b.get("days", 1));
	int built = b.get("built", 0);
	int last = b.get("last", -1);
	if (today < start || last == today)
		return;
	if (last >= start)
		built += ((bool)b.get("dry", false) ? 1 : 0) + MAX(0, today - 1 - last);
	else
		built += MAX(0, today - start);
	if (built >= days) {
		clear_booking();
		finish_job(id, false);
		return;
	}
	bool wet = clock_wet();
	b["built"] = built;
	b["last"] = today;
	b["dry"] = !wet;
	story_set(BOOKED, b);
	story_set(WORKED, false);
	story_set(DAY_FLAG, wet ? -1 : today);
	int lv = level_of(id);
	if (lv > 0) {
		story_set(BUILDING, lv);
		story_set(BUILD_DAY, built + 1);
		story_set(BUILD_LAST, !wet && built + 1 == days);
	}
}

void HomeWork::sync() {
	migrate();

	int story_level = story_flag("nha_muc", 0);
	Array d = done();
	for (int n = 1; n <= story_level; n++) {
		String id = "nha_muc_" + String::num_int64(n);
		if (!d.has(id) && !entry(id).is_empty())
			finish_job(id, true);
	}

	Dictionary b = booked();
	if (!b.is_empty()) {
		if (done().has(b["id"])) {
			Dictionary e = entry(b["id"]);
			Dictionary needs = e.get("needs", Dictionary());
			Array m = needs.keys();
			for (int i = 0; i < m.size(); i++)
				Stock::add(m[i], needs[m[i]]);
			Progress::earn(e.get("fee", 0));
			clear_booking();
		} else
			advance(b);
	}

	deliver_found();
}

void HomeWork::deliver_found() {
	Dictionary rep = finish_rules().get("repair", Dictionary());
	Array items = rep.get("items", Array());
	Array d = done();
	Variant rv = story_flag(RECEIVED, Array());
	Array got = rv.get_type() == Variant::ARRAY ? ((Array)rv).duplicate() : Array();
	bool changed = false;
	for (int i = 0; i < items.size(); i++) {
		Dictionary it = items[i];
		String id = it.get("id", "");
		String found = it.get("found", "");
		if (got.has(id))
			continue;
		bool now = false;
		if (found == "lau_don" || found.begins_with("nha_muc_"))
			now = d.has(found);
		else if (found.begins_with("ong_noi_") || found.begins_with("ba_noi_"))
			now = Progress::is_open(id);
		if (now) {
			kho_receive(id);
			got.push_back(id);
			changed = true;
		}
	}
	if (changed)
		story_set(RECEIVED, got);
}

Dictionary HomeWork::finish_job(const String &id, bool from_story) {
	Dictionary e = entry(id);
	Dictionary out;
	out["id"] = id;
	if (e.is_empty() || done().has(id))
		return out;
	add_done(id);
	Dictionary gives = e.get("gives", Dictionary());
	if (gives.has("moment"))
		Progress::moment(gives["moment"]);
	if (gives.has("flag"))
		story_set(gives["flag"], true);
	if (gives.has("moment"))
		out["moment"] = gives["moment"];
	if (!from_story) {
		Variant xp_key = e.get("story_xp", Variant());
		Dictionary xp = xp_key.get_type() == Variant::STRING ? Progress::story(xp_key)
															  : Progress::story(work_rules().get("fix_xp", Dictionary()));
		out["xp"] = xp;
		int pts = work_rules().get("helper_pts", 25);
		Array h = e.get("helpers", Array());
		Array came;
		for (int i = 0; i < h.size(); i++) {
			Array one = h[i];
			String who = one[0];
			if (Progress::hearts(who) >= (one.size() > 1 ? (int)one[1] : 0)) {
				Progress::befriend(who, pts);
				came.push_back(who);
			}
		}
		out["helpers"] = came;
		Variant ev = e.get("story_event", Variant());
		if (ev.get_type() == Variant::STRING)
			mark_event_done(ev);
	}
	deliver_found();
	return out;
}

Dictionary HomeWork::finish(const String &id) {
	return finish_job(id, false);
}

void HomeWork::_bind_methods() {
	ClassDB::bind_static_method("HomeWork", D_METHOD("done"), &HomeWork::done);
	ClassDB::bind_static_method("HomeWork", D_METHOD("level"), &HomeWork::level);
	ClassDB::bind_static_method("HomeWork", D_METHOD("pages"), &HomeWork::pages);
	ClassDB::bind_static_method("HomeWork", D_METHOD("check", "id"), &HomeWork::check);
	ClassDB::bind_static_method("HomeWork", D_METHOD("book", "id", "start"), &HomeWork::book, DEFVAL(-1));
	ClassDB::bind_static_method("HomeWork", D_METHOD("booked"), &HomeWork::booked);
	ClassDB::bind_static_method("HomeWork", D_METHOD("cancel"), &HomeWork::cancel);
	ClassDB::bind_static_method("HomeWork", D_METHOD("sync"), &HomeWork::sync);
	ClassDB::bind_static_method("HomeWork", D_METHOD("finish", "id"), &HomeWork::finish);
}
