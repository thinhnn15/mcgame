#include "cooking.h"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

Dictionary Cooking::take(const Dictionary &recipe, const Dictionary &have) {
	const Dictionary needs = recipe.get("needs", Dictionary());
	const Array keys = needs.keys();
	Dictionary out;
	for (int i = 0; i < keys.size(); i++) {
		const int need = (int)needs[keys[i]];
		if ((int)have.get(keys[i], 0) < need) {
			return Dictionary();
		}
		out[keys[i]] = need;
	}
	return out;
}

Array Cooking::menu(const Dictionary &recipes, const Array &open_ids, const Dictionary &have) {
	Array can_now, later;
	const Array ids = recipes.keys();
	for (int i = 0; i < ids.size(); i++) {
		const String id = ids[i];
		if (id.begins_with("_") || !open_ids.has(id)) {
			continue;
		}
		const Dictionary r = recipes[id];
		const Dictionary needs = r.get("needs", Dictionary());
		Dictionary nd;
		const Array keys = needs.keys();
		for (int k = 0; k < keys.size(); k++) {
			Array pair;
			pair.push_back((int)have.get(keys[k], 0));
			pair.push_back((int)needs[keys[k]]);
			nd[keys[k]] = pair;
		}
		Dictionary row;
		row["id"] = id;
		row["dish"] = r.get("dish", "");
		row["level"] = (int)r.get("level", 0);
		row["needs"] = nd;
		const bool can = !take(r, have).is_empty();
		row["can"] = can;
		(can ? can_now : later).push_back(row);
	}
	for (int i = 0; i < later.size(); i++) {
		can_now.push_back(later[i]);
	}
	return can_now;
}

int Cooking::xp_bonus(const Dictionary &recipe, int per_level) {
	return per_level * (int)recipe.get("level", 0);
}

Dictionary Cooking::cook(const Dictionary &pot, const Dictionary &recipes, const Array &open_ids, const Array &chosen) {
	Dictionary have;
	for (int i = 0; i < chosen.size(); i++) {
		have[chosen[i]] = (int)have.get(chosen[i], 0) + 1;
	}
	Dictionary out;
	out["used"] = have;
	String best;
	int best_level = -1, best_needs = 0;
	const Array ids = recipes.keys();
	for (int i = 0; i < ids.size(); i++) {
		const String id = ids[i];
		if (id.begins_with("_") || !open_ids.has(id)) continue;
		const Dictionary r = recipes[id];
		const Dictionary needs = r.get("needs", Dictionary());
		if (needs.is_empty() || take(r, have).is_empty()) continue;
		int n = 0;
		const Array nk = needs.keys();
		for (int k = 0; k < nk.size(); k++) n += (int)needs[nk[k]];

		const Dictionary tg = pot.get("tags", Dictionary());
		Array kinds;
		kinds.push_back("gia_vi");
		for (int k = 0; k < nk.size(); k++) {
			const Array t = tg.get(nk[k], Array());
			for (int q = 0; q < t.size(); q++) kinds.push_back(t[q]);
		}
		bool fits = true;
		const Array hk = have.keys();
		for (int k = 0; k < hk.size() && fits; k++) {
			if ((int)have[hk[k]] <= (int)needs.get(hk[k], 0)) continue;
			const Array t = tg.get(hk[k], Array());
			bool any = false;
			for (int q = 0; q < t.size(); q++) any = any || kinds.has(t[q]);
			fits = any;
		}
		if (!fits) continue;
		const int lv = (int)r.get("level", 0);
		if (lv > best_level || (lv == best_level && n > best_needs)) {
			best = id;
			best_level = lv;
			best_needs = n;
		}
	}
	const int extra_for_more = MAX(1, (int)pot.get("extra_for_more", 2));
	if (!best.is_empty()) {
		const Dictionary r = recipes[best];
		out["dish"] = r.get("dish", "");
		out["recipe"] = best;
		out["price"] = (int)r.get("price", 0);
		out["portions"] = 1 + ((chosen.size() - best_needs) >= extra_for_more ? 1 : 0);
		return out;
	}

	const Dictionary tags = pot.get("tags", Dictionary());
	Array present;
	for (int i = 0; i < chosen.size(); i++) {
		const Array t = tags.get(chosen[i], Array());
		if (t.is_empty()) {
			if (!present.has("khac")) present.push_back("khac");
		}
		for (int k = 0; k < t.size(); k++)
			if (!present.has(t[k])) present.push_back(t[k]);
	}
	const Array generic = pot.get("generic", Array());
	for (int g = 0; g < generic.size(); g++) {
		const Dictionary row = generic[g];
		const Array has = row.get("has", Array());
		bool ok = true;
		for (int k = 0; k < has.size() && ok; k++) ok = present.has(has[k]);
		if (ok && row.has("all")) {
			const Array all = row["all"];
			for (int k = 0; k < present.size() && ok; k++) ok = all.has(present[k]);
		}
		if (!ok) continue;
		out["dish"] = row.get("dish", "");
		out["recipe"] = "";
		out["price"] = (int)row.get("price", 0);
		out["portions"] = 1 + (chosen.size() >= 1 + extra_for_more * 2 ? 1 : 0);
		return out;
	}
	out["dish"] = "";
	out["recipe"] = "";
	out["price"] = 0;
	out["portions"] = 0;
	return out;
}

void Cooking::_bind_methods() {
	ClassDB::bind_static_method("Cooking", D_METHOD("cook", "pot", "recipes", "open_ids", "chosen"), &Cooking::cook);
	ClassDB::bind_static_method("Cooking", D_METHOD("menu", "recipes", "open_ids", "have"), &Cooking::menu);
	ClassDB::bind_static_method("Cooking", D_METHOD("take", "recipe", "have"), &Cooking::take);
	ClassDB::bind_static_method("Cooking", D_METHOD("xp_bonus", "recipe", "per_level"), &Cooking::xp_bonus);
}
