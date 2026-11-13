#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace godot {

class HomeWork : public RefCounted {
	GDCLASS(HomeWork, RefCounted)

	static Dictionary entry(const String &id);
	static bool page_open(const Dictionary &e, const Array &done);
	static bool with_tho(const Dictionary &e);
	static void add_done(const String &id);
	static Dictionary finish_job(const String &id, bool from_story);
	static void deliver_found();
	static void clear_booking();
	static void migrate();
	static void advance(Dictionary b);

protected:
	static void _bind_methods();

public:
	static Array done();
	static int level();
	static Array pages();
	static Dictionary check(const String &id);
	static bool book(const String &id, int start = -1);
	static Dictionary booked();
	static bool cancel();
	static void sync();
	static Dictionary finish(const String &id);
};

}
