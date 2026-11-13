#include "pattern_shop.h"

#include "progress.h"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

bool PatternShop::in_season(const Array &spans, int month, int day) {
	if (spans.size() < 2) {
		return true;
	}
	const Array a = spans[0];
	const Array b = spans[1];
	const int from = int(a[0]) * 100 + int(a[1]);
	const int to = int(b[0]) * 100 + int(b[1]);
	const int now = month * 100 + day;
	return from <= to ? (now >= from && now <= to) : (now >= from || now <= to);
}

Array PatternShop::stock(const Dictionary &prices, const Dictionary &seasons, int month, int day) {
	Array out;
	const Array keys = prices.keys();
	for (int i = 0; i < keys.size(); i++) {
		const String id = keys[i];
		if (id.begins_with("_") || !Progress::is_open(id)) {
			continue;
		}
		if (!in_season(seasons.get(id, Array()), month, day)) {
			continue;
		}
		Dictionary row;
		row["id"] = id;
		row["price"] = int(prices[id]);
		row["owned"] = owned(id);
		out.push_back(row);
	}
	return out;
}

bool PatternShop::priced(const Dictionary &prices, const String &id) {
	return !id.begins_with("_") && prices.has(id);
}

bool PatternShop::owned(const String &id) {
	return Progress::moments().has("mua_" + id);
}

String PatternShop::buy(const String &id, int price) {
	if (owned(id)) {
		return "owned";
	}
	if (!Progress::spend(price)) {
		return "money";
	}
	Progress::moment("mua_" + id);
	return "ok";
}

void PatternShop::_bind_methods() {
	ClassDB::bind_static_method("PatternShop", D_METHOD("in_season", "spans", "month", "day"), &PatternShop::in_season);
	ClassDB::bind_static_method("PatternShop", D_METHOD("stock", "prices", "seasons", "month", "day"), &PatternShop::stock);
	ClassDB::bind_static_method("PatternShop", D_METHOD("priced", "prices", "id"), &PatternShop::priced);
	ClassDB::bind_static_method("PatternShop", D_METHOD("owned", "id"), &PatternShop::owned);
	ClassDB::bind_static_method("PatternShop", D_METHOD("buy", "id", "price"), &PatternShop::buy);
}
