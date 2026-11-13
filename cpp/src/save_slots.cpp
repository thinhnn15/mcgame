#include "save_slots.h"

#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

static const char *ENTRIES[] = { "save", "hero.json", "look.json", "bonds.json", "photos" };
static const int N_ENTRIES = 5;
static const char *JOURNAL = "user://slots.json";
static const char *META = "save/slot.json";
static const char *THUMB = "save/slot_thumb.png";
static const int THUMB_W = 384;
static const int THUMB_H = 216;

void SaveSlots::_bind_methods() {
	ClassDB::bind_static_method("SaveSlots", D_METHOD("recover"), &SaveSlots::recover);
	ClassDB::bind_static_method("SaveSlots", D_METHOD("active"), &SaveSlots::active);
	ClassDB::bind_static_method("SaveSlots", D_METHOD("info", "slot"), &SaveSlots::info);
	ClassDB::bind_static_method("SaveSlots", D_METHOD("all"), &SaveSlots::all);
	ClassDB::bind_static_method("SaveSlots", D_METHOD("use", "slot"), &SaveSlots::use);
	ClassDB::bind_static_method("SaveSlots", D_METHOD("erase", "slot"), &SaveSlots::erase);
	ClassDB::bind_static_method("SaveSlots", D_METHOD("touch", "seconds", "scene"), &SaveSlots::touch);
	ClassDB::bind_static_method("SaveSlots", D_METHOD("save_thumb", "image"), &SaveSlots::save_thumb);
	ClassDB::bind_static_method("SaveSlots", D_METHOD("dir_of", "slot"), &SaveSlots::dir_of);
	BIND_CONSTANT(COUNT);
}

static String abs_path(const String &p) {
	return ProjectSettings::get_singleton()->globalize_path(p);
}

static bool there(const String &p) {
	String a = abs_path(p);
	return FileAccess::file_exists(a) || DirAccess::dir_exists_absolute(a);
}

static Variant read_json(const String &p) {
	if (!FileAccess::file_exists(p)) {
		return Variant();
	}
	return JSON::parse_string(FileAccess::get_file_as_string(p));
}

static bool write_json(const String &p, const Dictionary &d) {
	DirAccess::make_dir_recursive_absolute(abs_path(p.get_base_dir()));

	String tmp = p + String(".tmp");
	{
		Ref<FileAccess> f = FileAccess::open(tmp, FileAccess::WRITE);
		ERR_FAIL_COND_V_MSG(f.is_null(), false, "SaveSlots: cannot write " + tmp);
		f->store_string(JSON::stringify(d, "\t"));
	}
	if (FileAccess::file_exists(p)) {
		DirAccess::remove_absolute(abs_path(p));
	}
	return DirAccess::rename_absolute(abs_path(tmp), abs_path(p)) == OK;
}

static void rm_tree(const String &p) {
	String a = abs_path(p);
	if (FileAccess::file_exists(a)) {
		DirAccess::remove_absolute(a);
		return;
	}
	if (!DirAccess::dir_exists_absolute(a)) {
		return;
	}
	Ref<DirAccess> d = DirAccess::open(a);
	if (d.is_valid()) {
		d->set_include_hidden(true);
		PackedStringArray files = d->get_files();
		for (int i = 0; i < files.size(); i++) {
			DirAccess::remove_absolute(a.path_join(files[i]));
		}
		PackedStringArray dirs = d->get_directories();
		for (int i = 0; i < dirs.size(); i++) {
			rm_tree(a.path_join(dirs[i]));
		}
	}
	DirAccess::remove_absolute(a);
}

static String slot_dir(int slot) {
	return "user://slots/" + String::num_int64(slot) + String("/");
}

static bool valid(int slot) {
	return slot >= 1 && slot <= SaveSlots::COUNT;
}

static void move_entry(const String &from, const String &to) {
	if (!there(from)) {
		return;
	}
	if (there(to)) {
		rm_tree(to);
	}
	DirAccess::make_dir_recursive_absolute(abs_path(to.get_base_dir()));
	Error e = DirAccess::rename_absolute(abs_path(from), abs_path(to));
	if (e != OK) {
		UtilityFunctions::push_error("SaveSlots: could not move " + from + String(" -> ") + to + String(" (") + String::num_int64(e) + String(")"));
	}
}

static void run_switch(int a, int b, int phase) {
	if (phase <= 1) {
		Dictionary j;
		j["version"] = 1;
		j["active"] = a;
		j["to"] = b;
		j["phase"] = 1;
		write_json(JOURNAL, j);
		for (int i = 0; i < N_ENTRIES; i++) {
			move_entry(String("user://") + ENTRIES[i], slot_dir(a) + ENTRIES[i]);
		}
	}
	Dictionary j2;
	j2["version"] = 1;
	j2["active"] = a;
	j2["to"] = b;
	j2["phase"] = 2;
	write_json(JOURNAL, j2);
	for (int i = 0; i < N_ENTRIES; i++) {
		move_entry(slot_dir(b) + ENTRIES[i], String("user://") + ENTRIES[i]);
	}
	DirAccess::remove_absolute(abs_path(slot_dir(b)));
	Dictionary done;
	done["version"] = 1;
	done["active"] = b;
	write_json(JOURNAL, done);
}

void SaveSlots::recover() {
	Variant v = read_json(JOURNAL);
	if (v.get_type() != Variant::DICTIONARY) {
		Dictionary d;
		d["version"] = 1;
		d["active"] = 1;
		write_json(JOURNAL, d);
		return;
	}
	Dictionary j = v;
	if (!j.has("to")) {
		return;
	}
	int a = (int)j.get("active", 1);
	int b = (int)j.get("to", 1);
	int phase = (int)j.get("phase", 1);
	if (!valid(a) || !valid(b)) {
		return;
	}
	UtilityFunctions::print("SaveSlots: finishing a switch ", a, " -> ", b, " (phase ", phase, ")");
	run_switch(a, b, phase);
}

int SaveSlots::active() {
	Variant v = read_json(JOURNAL);
	if (v.get_type() != Variant::DICTIONARY) {
		return 1;
	}
	int a = (int)((Dictionary)v).get("active", 1);
	return valid(a) ? a : 1;
}

String SaveSlots::dir_of(int slot) {
	return slot == active() ? String("user://") : slot_dir(slot);
}

Dictionary SaveSlots::info(int slot) {
	Dictionary r;
	r["slot"] = slot;
	if (!valid(slot)) {
		r["empty"] = true;
		return r;
	}
	String dir = dir_of(slot);
	r["active"] = slot == active();
	Variant story = read_json(dir + String("save/story.json"));
	Variant hero = read_json(dir + String("hero.json"));
	bool empty = story.get_type() != Variant::DICTIONARY && hero.get_type() != Variant::DICTIONARY;
	r["empty"] = empty;
	if (empty) {
		return r;
	}
	Dictionary s = story.get_type() == Variant::DICTIONARY ? (Dictionary)story : Dictionary();
	Dictionary h = hero.get_type() == Variant::DICTIONARY ? (Dictionary)hero : Dictionary();
	r["name"] = String(h.get("name", s.get("name", "")));
	r["gender"] = String(h.get("gender", ""));
	r["chapter"] = String(s.get("chapter", "office"));
	r["day"] = (int)s.get("day", 1);
	r["beat"] = String(s.get("beat", story.get_type() == Variant::DICTIONARY ? "prologue" : "done"));
	r["opening_done"] = story.get_type() == Variant::DICTIONARY ? (bool)s.get("opening_done", false) : true;
	Variant cl = read_json(dir + String("save/clock.json"));
	if (cl.get_type() == Variant::DICTIONARY && ((Dictionary)cl).has("day")) {
		r["day"] = MAX((int)r["day"], (int)((Dictionary)cl).get("day", 1));
	}
	Variant m = read_json(dir + String(META));
	Dictionary md = m.get_type() == Variant::DICTIONARY ? (Dictionary)m : Dictionary();
	r["playtime"] = (double)md.get("playtime", 0.0);
	r["saved_at"] = (int64_t)md.get("saved_at", 0);
	r["scene"] = String(md.get("scene", ""));
	r["thumb"] = FileAccess::file_exists(dir + String(THUMB)) ? dir + String(THUMB) : String();
	return r;
}

Array SaveSlots::all() {
	Array a;
	for (int i = 1; i <= COUNT; i++) {
		a.push_back(info(i));
	}
	return a;
}

bool SaveSlots::use(int slot) {
	ERR_FAIL_COND_V_MSG(!valid(slot), false, "SaveSlots: no slot " + String::num_int64(slot));
	int a = active();
	if (a == slot) {
		return true;
	}
	run_switch(a, slot, 1);
	return active() == slot;
}

void SaveSlots::erase(int slot) {
	ERR_FAIL_COND_MSG(!valid(slot), "SaveSlots: no slot " + String::num_int64(slot));
	if (slot == active()) {
		for (int i = 0; i < N_ENTRIES; i++) {
			rm_tree(String("user://") + ENTRIES[i]);
		}
	} else {
		rm_tree(slot_dir(slot));
	}
}

void SaveSlots::touch(double seconds, const String &scene) {
	String p = String("user://") + String(META);
	Variant m = read_json(p);
	Dictionary d = m.get_type() == Variant::DICTIONARY ? (Dictionary)m : Dictionary();
	d["version"] = 1;
	d["playtime"] = (double)d.get("playtime", 0.0) + MAX(0.0, seconds);
	d["saved_at"] = (int64_t)Time::get_singleton()->get_unix_time_from_system();
	if (!scene.is_empty()) {
		d["scene"] = scene;
	}
	write_json(p, d);
}

void SaveSlots::save_thumb(const Ref<Image> &image) {
	ERR_FAIL_COND(image.is_null() || image->is_empty());
	Ref<Image> img = image->duplicate();
	if (img->is_compressed()) {
		img->decompress();
	}
	img->convert(Image::FORMAT_RGB8);

	double k = MAX((double)THUMB_W / img->get_width(), (double)THUMB_H / img->get_height());
	int w = MAX(THUMB_W, (int)Math::round(img->get_width() * k));
	int h = MAX(THUMB_H, (int)Math::round(img->get_height() * k));
	img->resize(w, h, Image::INTERPOLATE_BILINEAR);
	Ref<Image> out = img->get_region(Rect2i((w - THUMB_W) / 2, (h - THUMB_H) / 2, THUMB_W, THUMB_H));
	String p = String("user://") + String(THUMB);
	DirAccess::make_dir_recursive_absolute(abs_path(p.get_base_dir()));
	out->save_png(p);
}
