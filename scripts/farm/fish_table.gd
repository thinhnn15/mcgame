class_name FishTable
extends RefCounted

const FILE := "res://data/fish/fish.json"
const MAX_KINDS := 6
const MAX_FISH := 12
const CHANCE := {"thuong": 1.0, "it": 0.75, "hiem": 0.45, "rat_hiem": 0.25}

static var rows: Array = []
static var _by_kind := {}

static func load_table() -> void:
	if not rows.is_empty():
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	rows = d["fish"] if d is Dictionary else []
	for r in rows:
		_by_kind[r["kind"]] = r

static func row(kind: String) -> Dictionary:
	load_table()
	return _by_kind.get(kind, {})

static func cm(kind: String) -> Vector2:
	var r := row(kind)
	return Vector2(r["cm"][0], r["cm"][1]) if not r.is_empty() else Vector2.ZERO

static func stock(spot: String, ctx: Dictionary) -> Array:
	load_table()
	var out := []
	var total := 0
	var pool := rows.filter(func(r): return spot in r["spots"] and _season(r, ctx))
	pool.shuffle()
	pool.sort_custom(func(a, b): return CHANCE[a["rarity"]] > CHANCE[b["rarity"]])
	for r in pool:
		if out.size() >= MAX_KINDS or total >= MAX_FISH:
			break
		if randf() > float(CHANCE[r["rarity"]]):
			continue
		var n := mini(randi_range(int(r["n"][0]), int(r["n"][1])), MAX_FISH - total)
		out.append([r["kind"], n])
		total += n
	return out

static func _season(r: Dictionary, ctx: Dictionary) -> bool:
	var months: Array = r.get("months", [])
	if not months.is_empty() and not int(ctx.get("month", 5)) in months:
		return false
	var days: Array = r.get("lunar_days", [])
	if not days.is_empty() and not int(ctx.get("lunar_day", 0)) in days:
		return false
	var w: Array = r.get("weather", [])
	return w.is_empty() or str(ctx.get("weather", "")) in w

static func biting(r: Dictionary, ctx: Dictionary) -> bool:
	if r.is_empty() or not Progress.is_open(r["unlock"]):
		return false
	var w := str(ctx.get("weather", ""))
	if r.get("after_rain", false) and (w != "" or ctx.get("after_rain", false)):
		return true
	if r.get("rain_any_hour", false) and w != "":
		return true
	var h := float(ctx.get("hour", 12.0))
	var hs: Array = r["hours"]
	for i in range(0, hs.size(), 2):
		var a := float(hs[i])
		var b := float(hs[i + 1])
		if (h >= a and h < b) if a <= b else (h >= a or h < b):
			return true
	return false
