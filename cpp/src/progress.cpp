#include "progress.h"
#include "mc_common.h"

#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

static const char *FILE_PATH = "user://save/progress.json";
static const char *SKILLS_PATH = "res://data/progression/skills.json";
static const char *UNLOCKS_PATH = "res://data/progression/unlocks.json";

Progress::State *Progress::s = nullptr;

void Progress::_bind_methods() {
	ClassDB::bind_static_method("Progress", D_METHOD("load_saved"), &Progress::load_saved);
	ClassDB::bind_static_method("Progress", D_METHOD("save"), &Progress::save);
	ClassDB::bind_static_method("Progress", D_METHOD("reset"), &Progress::reset);
	ClassDB::bind_static_method("Progress", D_METHOD("forget"), &Progress::forget);
	ClassDB::bind_static_method("Progress", D_METHOD("act", "action"), &Progress::act);
	ClassDB::bind_static_method("Progress", D_METHOD("story", "what"), &Progress::story);
	ClassDB::bind_static_method("Progress", D_METHOD("moment", "id"), &Progress::moment);
	ClassDB::bind_static_method("Progress", D_METHOD("friend", "id", "pts"), &Progress::befriend);
	ClassDB::bind_static_method("Progress", D_METHOD("earn", "n"), &Progress::earn);
	ClassDB::bind_static_method("Progress", D_METHOD("owe", "n"), &Progress::owe);
	ClassDB::bind_static_method("Progress", D_METHOD("pay_owed"), &Progress::pay_owed);
	ClassDB::bind_static_method("Progress", D_METHOD("spend", "n"), &Progress::spend);
	ClassDB::bind_static_method("Progress", D_METHOD("rest", "mark"), &Progress::rest);
	ClassDB::bind_static_method("Progress", D_METHOD("new_day"), &Progress::new_day);
	ClassDB::bind_static_method("Progress", D_METHOD("level", "skill"), &Progress::level);
	ClassDB::bind_static_method("Progress", D_METHOD("hearts", "id"), &Progress::hearts);
	ClassDB::bind_static_method("Progress", D_METHOD("is_open", "item_id"), &Progress::is_open);
	ClassDB::bind_static_method("Progress", D_METHOD("met", "unlock"), &Progress::met);
	ClassDB::bind_static_method("Progress", D_METHOD("skill_of", "action"), &Progress::skill_of);
	ClassDB::bind_static_method("Progress", D_METHOD("announce"), &Progress::announce);
	ClassDB::bind_static_method("Progress", D_METHOD("add_on_open", "cb"), &Progress::add_on_open);
	ClassDB::bind_static_method("Progress", D_METHOD("remove_on_open", "cb"), &Progress::remove_on_open);
	ClassDB::bind_static_method("Progress", D_METHOD("money"), &Progress::money);
	ClassDB::bind_static_method("Progress", D_METHOD("owed"), &Progress::owed);
	ClassDB::bind_static_method("Progress", D_METHOD("xp"), &Progress::xp);
	ClassDB::bind_static_method("Progress", D_METHOD("friends"), &Progress::friends);
	ClassDB::bind_static_method("Progress", D_METHOD("moments"), &Progress::moments);
	ClassDB::bind_static_method("Progress", D_METHOD("opened"), &Progress::opened);
	ClassDB::bind_static_method("Progress", D_METHOD("today"), &Progress::today);
	ClassDB::bind_static_method("Progress", D_METHOD("rested_today"), &Progress::rested_today);
	ClassDB::bind_static_method("Progress", D_METHOD("skills"), &Progress::skills);
	ClassDB::bind_static_method("Progress", D_METHOD("unlocks"), &Progress::unlocks);
}

void Progress::init() {
	if (s == nullptr) {
		s = memnew(State);
	}
}

void Progress::finish() {
	if (s != nullptr) {
		memdelete(s);
		s = nullptr;
	}
}

static Variant read_json(const String &path) {
	if (!FileAccess::file_exists(path)) {
		return Variant();
	}
	return JSON::parse_string(FileAccess::get_file_as_string(path));
}

void Progress::load_saved() {
	init();
	if (s->loaded) {
		return;
	}
	s->loaded = true;
	Variant sk = read_json(SKILLS_PATH);
	Variant un = read_json(UNLOCKS_PATH);
	s->skills = sk.get_type() == Variant::DICTIONARY ? (Dictionary)sk : Dictionary();
	s->unlocks = un.get_type() == Variant::DICTIONARY ? (Dictionary)un : Dictionary();
	Dictionary skills = s->skills.get("skills", Dictionary());
	Array names = skills.keys();
	for (int i = 0; i < names.size(); i++) {
		Dictionary one = skills[names[i]];
		Dictionary actions = one.get("actions", Dictionary());
		Array acts = actions.keys();
		for (int j = 0; j < acts.size(); j++) {
			s->action_skill[acts[j]] = names[i];
		}
	}
	Variant d = read_json(FILE_PATH);
	if (d.get_type() == Variant::DICTIONARY) {
		Dictionary dd = d;
		s->xp = dd.get("xp", Dictionary());
		s->friends = dd.get("friends", Dictionary());
		s->moments = Array(dd.get("moments", Array()));
		s->today = dd.get("today", Dictionary());
		s->rested_today = (bool)dd.get("rested_today", false);
		s->rest_marks = dd.get("rest_marks", Dictionary());
		s->opened = Array(dd.get("opened", Array()));
		s->money = (int)dd.get("money", 0);
		s->owed = (int)dd.get("owed", 0);
		s->stock = dd.get("stock", Dictionary());
	} else {
		s->opened = open_now();
	}
}

void Progress::save() {
	init();
	String path = FILE_PATH;
	DirAccess::make_dir_recursive_absolute(ProjectSettings::get_singleton()->globalize_path(path.get_base_dir()));
	Ref<FileAccess> f = FileAccess::open(path, FileAccess::WRITE);
	ERR_FAIL_COND_MSG(f.is_null(), "Progress: cannot write " + path);
	Dictionary d;
	d["version"] = 1;
	d["xp"] = s->xp;
	d["friends"] = s->friends;
	d["moments"] = s->moments;
	d["today"] = s->today;
	d["rested_today"] = s->rested_today;
	d["rest_marks"] = s->rest_marks;
	d["opened"] = s->opened;
	d["money"] = s->money;
	d["owed"] = s->owed;
	d["stock"] = s->stock;
	f->store_string(JSON::stringify(d, "\t"));
}

void Progress::reset() {
	load_saved();
	s->xp = Dictionary();
	s->friends = Dictionary();
	s->moments = Array();
	s->today = Dictionary();
	s->rested_today = false;
	s->rest_marks = Dictionary();
	s->opened = open_now();
	s->money = 0;
	s->owed = 0;
	s->stock = Dictionary();
	save();
}

void Progress::forget() {

	init();
	s->xp = Dictionary();
	s->friends = Dictionary();
	s->moments = Array();
	s->today = Dictionary();
	s->rested_today = false;
	s->rest_marks = Dictionary();
	s->opened = Array();
	s->money = 0;
	s->owed = 0;
	s->stock = Dictionary();
	s->loaded = false;
}

int Progress::act(const String &action) {

	load_saved();
	if (!s->action_skill.has(action)) {
		UtilityFunctions::push_warning("Progress: unknown action " + action);
		return 0;
	}
	String skill = s->action_skill[action];
	int n = (int)s->today.get(action, 0);
	s->today[action] = n + 1;
	Dictionary daily = s->skills.get("daily", Dictionary());
	Dictionary skills = s->skills["skills"];
	Dictionary one = skills[skill];
	Dictionary actions = one["actions"];
	double per = (double)actions[action];
	int full = (int)daily.get("full", 10);
	int half = (int)daily.get("half", 10);
	double gain = n < full ? per : (n < full + half ? per * 0.5 : (double)daily.get("after", 1));
	return add(skill, gain);
}

Dictionary Progress::story(const Variant &what) {

	load_saved();
	Dictionary d;
	if (what.get_type() == Variant::STRING || what.get_type() == Variant::STRING_NAME) {
		Dictionary story_xp = s->skills.get("story_xp", Dictionary());
		d = story_xp.get(what, Dictionary());
	} else if (what.get_type() == Variant::DICTIONARY) {
		d = what;
	}
	Dictionary got;
	Array keys = d.keys();
	for (int i = 0; i < keys.size(); i++) {
		String k = keys[i];
		if (!k.begins_with("_")) {
			got[k] = add(k, (double)d[keys[i]]);
		}
	}
	return got;
}

void Progress::moment(const String &id) {
	load_saved();
	if (!s->moments.has(id)) {
		s->moments.push_back(id);
		announce_now();
		save();
	}
}

int Progress::befriend(const String &id, int pts) {

	load_saved();
	Dictionary f = s->skills["friends"];
	int cap = (int)f["hearts_max"] * (int)f["points_per_heart"];
	s->friends[id] = MIN((int)s->friends.get(id, 0) + pts, cap);
	announce_now();
	save();
	return hearts(id);
}

int Progress::earn(int n) {

	load_saved();
	s->money += MAX(n, 0);
	save();
	return s->money;
}

void Progress::owe(int n) {

	load_saved();
	s->owed += MAX(n, 0);
	save();
}

int Progress::pay_owed() {

	load_saved();
	int n = s->owed;
	s->owed = 0;
	s->money += n;
	save();
	return n;
}

bool Progress::spend(int n) {

	load_saved();
	if (n > s->money) {
		return false;
	}
	s->money -= n;
	save();
	return true;
}

void Progress::rest(const String &mark) {

	load_saved();
	s->rest_marks[mark] = true;
	save();
}

void Progress::new_day() {
	load_saved();
	Dictionary r = s->skills["rested"];
	Array of = r["of"];
	int had = 0;
	for (int i = 0; i < of.size(); i++) {
		if ((bool)s->rest_marks.get(of[i], false)) {
			had++;
		}
	}
	s->rested_today = had >= (int)r["need"];
	s->rest_marks = Dictionary();
	s->today = Dictionary();
	save();
}

int Progress::add(const String &skill, double gain) {
	if (s->rested_today) {
		Dictionary r = s->skills["rested"];
		gain *= (double)r["mult"];
	}
	int g = (int)Math::round(gain);
	s->xp[skill] = (int)s->xp.get(skill, 0) + g;
	announce_now();
	save();
	return g;
}

int Progress::level(const String &skill) {
	load_saved();
	int lv = 0;
	int t = (int)s->xp.get(skill, 0);
	Array levels = s->skills.get("levels", Array());
	for (int i = 0; i < levels.size(); i++) {
		if (t >= (int)levels[i]) {
			lv = i;
		}
	}
	return lv;
}

int Progress::hearts(const String &id) {
	load_saved();
	Dictionary f = s->skills["friends"];
	return (int)s->friends.get(id, 0) / (int)f["points_per_heart"];
}

bool Progress::is_open(const String &item_id) {
	load_saved();
	Array items = s->unlocks.get("items", Array());
	for (int i = 0; i < items.size(); i++) {
		Dictionary row = items[i];
		if ((String)row["id"] == item_id) {
			return met(row["unlock"]);
		}
	}
	return false;
}

String Progress::skill_of(const String &action) {
	load_saved();
	return s->action_skill.get(action, "");
}

bool Progress::met(const Dictionary &u) {
	load_saved();
	if ((bool)u.get("start", false)) {
		return true;
	}
	if (u.has("skill")) {
		return level(u["skill"]) >= (int)u["level"];
	}
	if (u.has("friend")) {
		return hearts(u["friend"]) >= (int)u["hearts"];
	}
	if (u.has("chapter")) {
		Ref<Script> story = mc::Scripts::story_gd();
		Ref<Script> clock = mc::Scripts::clock_gd();
		if (story.is_null() || clock.is_null()) {
			return false;
		}
		String chapter = story->get("chapter");
		return chapter.begins_with("que_") ? (int)clock->call("chapter") >= (int)u["chapter"] : false;
	}
	if (u.has("moment")) {
		return s->moments.has(u["moment"]);
	}
	if (u.has("postgame")) {
		Ref<Script> clock = mc::Scripts::clock_gd();
		return clock.is_valid() ? (bool)clock->call("free_day") : false;
	}
	return false;
}

Array Progress::open_now() {
	Array out;
	Array items = s->unlocks.get("items", Array());
	for (int i = 0; i < items.size(); i++) {
		Dictionary row = items[i];
		if (met(row["unlock"])) {
			out.push_back(row["id"]);
		}
	}
	return out;
}

void Progress::announce_now() {

	Array items = s->unlocks.get("items", Array());
	for (int i = 0; i < items.size(); i++) {
		Dictionary row = items[i];
		if (!s->opened.has(row["id"]) && met(row["unlock"])) {
			s->opened.push_back(row["id"]);
			Array cbs = s->on_open.duplicate();
			for (int c = 0; c < cbs.size(); c++) {
				Callable cb = cbs[c];
				if (cb.is_valid()) {
					cb.call(row);
				}
			}
		}
	}
}

void Progress::announce() {
	load_saved();
	announce_now();
	save();
}

void Progress::add_on_open(const Callable &cb) {
	init();
	if (!s->on_open.has(cb)) {
		s->on_open.push_back(cb);
	}
}

void Progress::remove_on_open(const Callable &cb) {
	init();
	s->on_open.erase(cb);
}

int Progress::money() {
	load_saved();
	return s->money;
}

int Progress::owed() {
	load_saved();
	return s->owed;
}

Dictionary Progress::xp() {
	load_saved();
	return s->xp;
}

Dictionary Progress::friends() {
	load_saved();
	return s->friends;
}

Array Progress::moments() {
	load_saved();
	return s->moments;
}

Array Progress::opened() {
	load_saved();
	return s->opened;
}

Dictionary Progress::today() {
	load_saved();
	return s->today;
}

bool Progress::rested_today() {
	load_saved();
	return s->rested_today;
}

Dictionary Progress::skills() {
	load_saved();
	return s->skills;
}

Dictionary Progress::unlocks() {
	load_saved();
	return s->unlocks;
}
