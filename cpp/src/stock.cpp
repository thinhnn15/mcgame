#include "stock.h"
#include "progress.h"

#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

static const char *FINISH_PATH = "res://data/home/finish.json";

namespace {

Dictionary &rules() {
	static Dictionary *d = nullptr;
	if (d == nullptr) {
		d = new Dictionary();
		if (FileAccess::file_exists(FINISH_PATH)) {
			Variant v = JSON::parse_string(FileAccess::get_file_as_string(FINISH_PATH));
			if (v.get_type() == Variant::DICTIONARY)
				*d = v;
		}
	}
	return *d;
}

}

bool Stock::known(const String &id) {
	String base = id.get_slice(":", 0);
	if (id.contains(":") && id.get_slice(":", 1) != "le")
		return false;
	Array rows = Progress::s->unlocks.get("items", Array());
	for (int i = 0; i < rows.size(); i++) {
		Dictionary r = rows[i];
		if (String(r.get("id", "")) == base)
			return String(r.get("type", "")) == "material";
	}
	return false;
}

int Stock::cap() {
	Dictionary st = rules().get("stock", Dictionary());
	return (int)st.get("cap_each", 99);
}

int Stock::uses_of(const String &id) {
	Dictionary paint = rules().get("paint", Dictionary());
	Dictionary uses = paint.get("uses", Dictionary());
	return (int)uses.get(id, 0);
}

void Stock::changed(const String &id) {
	Progress::save();
	int n = count(id);
	Array w = Progress::s->stock_watch.duplicate();
	for (int i = 0; i < w.size(); i++) {
		Callable cb = w[i];
		if (cb.is_valid())
			cb.call(id, n);
	}
}

int Stock::count(const String &id) {
	Progress::load_saved();
	return (int)Progress::s->stock.get(id, 0);
}

int Stock::add(const String &id, int n) {
	Progress::load_saved();
	if (!known(id)) {
		UtilityFunctions::push_warning("Stock: '" + id + "' is not a material (unlocks.json type material)");
		return 0;
	}
	int now = count(id);
	int put = n > 0 ? MIN(n, cap() - now) : MAX(n, -now);
	if (put == 0)
		return 0;
	if (now + put <= 0)
		Progress::s->stock.erase(id);
	else
		Progress::s->stock[id] = now + put;
	changed(id);
	return put;
}

bool Stock::has(const Dictionary &needs) {
	Progress::load_saved();
	Array ids = needs.keys();
	for (int i = 0; i < ids.size(); i++) {
		if (count(ids[i]) < (int)needs[ids[i]])
			return false;
	}
	return true;
}

bool Stock::take(const Dictionary &needs) {
	if (!has(needs))
		return false;
	Array ids = needs.keys();
	for (int i = 0; i < ids.size(); i++) {
		String id = ids[i];
		int left = count(id) - (int)needs[id];
		if (left <= 0)
			Progress::s->stock.erase(id);
		else
			Progress::s->stock[id] = left;
	}
	Progress::save();
	for (int i = 0; i < ids.size(); i++)
		changed(ids[i]);
	return true;
}

bool Stock::use(const String &id) {
	Progress::load_saved();
	String le = id + String(":le");
	int left = count(le);
	if (left > 0) {
		if (left == 1)
			Progress::s->stock.erase(le);
		else
			Progress::s->stock[le] = left - 1;
		changed(le);
		return true;
	}
	if (count(id) < 1)
		return false;
	Dictionary one;
	one[id] = 1;
	take(one);
	int per = uses_of(id);
	if (per > 1) {
		Progress::s->stock[le] = per - 1;
		changed(le);
	}
	return true;
}

Dictionary Stock::all() {
	Progress::load_saved();
	return Progress::s->stock.duplicate();
}

void Stock::watch(const Callable &cb) {
	Progress::load_saved();
	if (!Progress::s->stock_watch.has(cb))
		Progress::s->stock_watch.push_back(cb);
}

void Stock::unwatch(const Callable &cb) {
	Progress::load_saved();
	Progress::s->stock_watch.erase(cb);
}

void Stock::fill(int n) {
	Progress::load_saved();
	Array rows = Progress::s->unlocks.get("items", Array());
	for (int i = 0; i < rows.size(); i++) {
		Dictionary r = rows[i];
		if (String(r.get("type", "")) == "material")
			Progress::s->stock[r["id"]] = MIN(n, cap());
	}
	Progress::save();
}

void Stock::clear() {
	Progress::load_saved();
	Progress::s->stock = Dictionary();
	Progress::save();
}

void Stock::_bind_methods() {
	ClassDB::bind_static_method("Stock", D_METHOD("count", "id"), &Stock::count);
	ClassDB::bind_static_method("Stock", D_METHOD("add", "id", "n"), &Stock::add);
	ClassDB::bind_static_method("Stock", D_METHOD("has", "needs"), &Stock::has);
	ClassDB::bind_static_method("Stock", D_METHOD("take", "needs"), &Stock::take);
	ClassDB::bind_static_method("Stock", D_METHOD("use", "id"), &Stock::use);
	ClassDB::bind_static_method("Stock", D_METHOD("all"), &Stock::all);
	ClassDB::bind_static_method("Stock", D_METHOD("watch", "cb"), &Stock::watch);
	ClassDB::bind_static_method("Stock", D_METHOD("unwatch", "cb"), &Stock::unwatch);
	ClassDB::bind_static_method("Stock", D_METHOD("fill", "n"), &Stock::fill);
	ClassDB::bind_static_method("Stock", D_METHOD("clear"), &Stock::clear);
}
