#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace godot {

class Stock : public RefCounted {
	GDCLASS(Stock, RefCounted)

	static bool known(const String &id);
	static int cap();
	static int uses_of(const String &id);
	static void changed(const String &id);

protected:
	static void _bind_methods();

public:
	static int count(const String &id);
	static int add(const String &id, int n);
	static bool has(const Dictionary &needs);
	static bool take(const Dictionary &needs);
	static bool use(const String &id);
	static Dictionary all();
	static void watch(const Callable &cb);
	static void unwatch(const Callable &cb);
	static void fill(int n);
	static void clear();
};

}
