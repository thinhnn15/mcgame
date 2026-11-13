#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector2i.hpp>

#include <cstdint>
#include <map>
#include <string>
#include <unordered_map>
#include <vector>

namespace godot {

class FarmSoil : public RefCounted {
	GDCLASS(FarmSoil, RefCounted)

public:
	static constexpr int WEED_NIGHTS = 3;

private:
	enum Soil : uint8_t { CO = 0, XOI, KHO, UOT, NONE };
	struct Bed {
		int i, j0, n;
	};
	struct Crop {
		String id;
		int stage = 0, grown = 0;
	};
	struct Row {
		int stages = 1;
		std::vector<int> days;
		int regrow_to = -1;
		int lo = 1, hi = 1;
		bool big = false;
	};
	std::vector<Bed> beds;
	std::vector<std::vector<uint8_t>> soil;
	std::vector<std::vector<int>> fallow;
	std::map<int64_t, Crop> crops;
	std::map<int64_t, int64_t> cover;
	std::unordered_map<std::string, Row> table;
	uint32_t seed = 0x2545F491u;

	static int64_t key(const Vector2i &c) { return (int64_t(c.x) << 32) ^ int64_t(uint32_t(c.y)); }
	static Vector2i cell_of(int64_t k) { return Vector2i(int32_t(k >> 32), int32_t(uint32_t(k & 0xffffffffu))); }
	static Soil soil_of(const String &s);
	static String name_of(uint8_t s);
	bool valid(const Vector2i &pc) const;
	void rebuild_cover();
	const Row *row(const String &id) const;
	int rnd(int lo, int hi);

protected:
	static void _bind_methods();

public:
	void set_crop_table(const Dictionary &t);
	void setup(const Array &defs, const String &state);
	Vector2i piece_of(const Vector2i &c) const;
	Vector2i twin(const Vector2i &c) const;
	Vector2i resolve(const Vector2i &c) const;
	String state_at(const Vector2i &c) const;
	bool has_crop(const Vector2i &c) const;
	bool ripe(const Vector2i &c) const;
	bool hoe(const Vector2i &c);
	bool sow(const Vector2i &c, const String &crop);
	bool water(const Vector2i &c);
	String dig(const Vector2i &c);
	void plant(const Vector2i &c, const String &crop, int stage);
	Dictionary harvest(const Vector2i &c);
	void rain();
	void next_day();
	Array row_of(const Vector2i &c, int n, int dir) const;
	Dictionary soil_dict() const;
	Dictionary crops_dict() const;
	Dictionary fallow_dict() const;
	Dictionary to_dict() const;
	void from_dict(const Dictionary &d);
	int weed_nights() const { return WEED_NIGHTS; }
};

}
