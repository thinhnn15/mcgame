#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace godot {

class Progress : public RefCounted {
	GDCLASS(Progress, RefCounted)
	friend class Stock;

	struct State {
		Dictionary xp;
		Dictionary friends;
		Array moments;
		Dictionary today;
		bool rested_today = false;
		Dictionary rest_marks;
		Array opened;
		int money = 0;
		int owed = 0;
		Array on_open;
		Dictionary stock;
		Array stock_watch;
		Dictionary skills;
		Dictionary unlocks;
		Dictionary action_skill;
		bool loaded = false;
	};
	static State *s;

	static int add(const String &skill, double gain);
	static Array open_now();
	static void announce_now();

protected:
	static void _bind_methods();

public:
	static void init();
	static void finish();

	static void load_saved();
	static void save();
	static void reset();
	static void forget();
	static int act(const String &action);
	static Dictionary story(const Variant &what);
	static void moment(const String &id);
	static int befriend(const String &id, int pts);
	static int earn(int n);
	static void owe(int n);
	static int pay_owed();
	static bool spend(int n);
	static void rest(const String &mark);
	static void new_day();
	static int level(const String &skill);
	static int hearts(const String &id);
	static bool is_open(const String &item_id);
	static bool met(const Dictionary &unlock);
	static String skill_of(const String &action);
	static void announce();
	static void add_on_open(const Callable &cb);
	static void remove_on_open(const Callable &cb);
	static int money();
	static int owed();
	static Dictionary xp();
	static Dictionary friends();
	static Array moments();
	static Array opened();
	static Dictionary today();
	static bool rested_today();
	static Dictionary skills();
	static Dictionary unlocks();
};

}
