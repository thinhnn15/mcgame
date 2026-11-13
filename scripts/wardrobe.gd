class_name Wardrobe
extends RefCounted

const PALETTES := "res://data/wardrobe/palettes.json"
const JOBS := "res://data/wardrobe/jobs.json"
const SAVED := "res://data/wardrobe/saved_people.json"

const ONE_PIECE := ["dress", "sundress", "dress_maxi", "dress_office", "dress_tier", "pinafore", "overalls"]
const DARK_EYES := ["#3a2a24", "#3a2a24", "#7a4a2a"]
const FABRICS := "res://data/wardrobe/fabrics.json"
const FABRIC_IDS := {"vai": 0, "len": 1, "lua": 2, "da": 3, "kimloai": 4}
const WEAVE_DIR := "res://characters/weave/"
const WEAVE_DEPTH := {"da": 0.18, "len": 0.45}

static var _pal: Dictionary = {}
static var _jobs: Dictionary = {}
static var _fab: Dictionary = {}

static var fabrics_on := not OS.get_cmdline_user_args().has("--no-fabric")

static func _data() -> void:
	if _pal.is_empty():
		_pal = JSON.parse_string(FileAccess.get_file_as_string(PALETTES))
		_jobs = JSON.parse_string(FileAccess.get_file_as_string(JOBS))

static func job_ids() -> Array:
	_data()
	return _jobs["jobs"].keys()

static func job_name(job: String) -> String:
	_data()
	return str(_jobs["jobs"].get(job, {}).get("name", job))

static func presets(slot: String, shape: String) -> Array:
	"""The colourways of one item: its own list, else its slot's _any."""
	_data()
	var s: Dictionary = _pal.get(slot, {})
	return s.get(shape, s.get("_any", []))

static func garment(slot: String, shape: String, i: int) -> Dictionary:
	"""Colourway i of an item as a look garment ({"shape": ..., "color": ...})."""
	var ps := presets(slot, shape)
	var g := {"shape": shape, "design": ""}
	if not ps.is_empty():
		var p: Dictionary = ps[posmod(i, ps.size())]
		for k in p:
			if k != "name" and k != "tags":
				g[k] = p[k]
	return g

static func _pick_preset(slot: String, shape: String, tag: String, rng: RandomNumberGenerator) -> int:
	var ps := presets(slot, shape)
	if ps.is_empty():
		return 0
	var fit := []
	var free := []
	for i in ps.size():
		var tags: Array = ps[i].get("tags", [])
		if tags.has("uniform") and tag != "uniform":
			continue
		free.append(i)
		if tag == "" or tags.has(tag):
			fit.append(i)
	if fit.is_empty():
		fit = free if not free.is_empty() else range(ps.size())
	return fit[rng.randi_range(0, fit.size() - 1)]

static func _weighted(opts: Array, rng: RandomNumberGenerator) -> Array:
	"""One [shape, weight(, tag)] option, by weight."""
	var total := 0.0
	for o in opts:
		total += float(o[1])
	var r := rng.randf() * total
	for o in opts:
		r -= float(o[1])
		if r <= 0.0:
			return o
	return opts[-1]

static func _one(list: Array, rng: RandomNumberGenerator):
	return list[rng.randi_range(0, list.size() - 1)]

static func dress(job: String, seed: int) -> Dictionary:
	"""A whole villager of this job: figure (body, face, hair), garments in their colourways, extras."""
	_data()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var kits: Array = _jobs["jobs"][job]["kits"]
	var kit: Dictionary = _weighted(kits.map(func(k): return [k, k.get("w", 1)]), rng)[0]
	var fig: Dictionary = _jobs["figures"][kit["fig"]]
	var look := Looks.DEFAULT.duplicate(true)
	look.merge(fig.get("base", {}), true)
	look["hair"] = _one(fig["hair"], rng)
	look["hair_color"] = _one(_jobs["hair_colors"][fig["hair_color"]], rng)
	look["eye_style"] = _one(fig["eyes"], rng)
	look["eye_color"] = _one(DARK_EYES, rng)
	look["skin"] = _one(_jobs["skins"][kit.get("skin", "any")], rng)
	var face: String = _one(fig.get("faces", [""]), rng)
	if face != "":
		look["face"] = face
	for slot in ["top", "bottom", "shoes", "socks", "hat"]:
		if not kit.has(slot):
			continue
		var o: Array = _weighted(kit[slot], rng)
		var shape: String = o[0]
		if shape == "":
			look.erase(slot)
			continue
		if shape == "none":
			look[slot] = {"shape": "none"}
			continue
		var tag: String = o[2] if o.size() > 2 else ""
		look[slot] = garment(slot, shape, _pick_preset(slot, shape, tag, rng))
	if ONE_PIECE.has(str(look["top"].get("shape", ""))):
		look["bottom"] = {"shape": "none"}
	var wear: Dictionary = kit.get("wear", {})
	for kind in wear:
		if rng.randf() < float(wear[kind]):
			var p: Dictionary = _one(_pal["wear"][kind], rng)
			for k in p:
				if k != "name":
					look[k] = p[k]
	var umb: Dictionary = _one(_pal["wear"]["umbrella"], rng)
	look["umbrella"] = umb["umbrella"]
	look["job"] = job
	return look

static func look_for(id: String, l: Dictionary) -> Dictionary:
	"""A villager's look from its data: with "job", the job's draw (seeded by "seed" or the id), then the entry's
	own keys on top (a garment's keys merge, so {"top": {"color": ...}} only recolours); with "saved", a person
	kept from the fitting room (data/wardrobe/saved_people.json); without either, unchanged."""
	var look := {}
	if l.has("saved"):
		var all = JSON.parse_string(FileAccess.get_file_as_string(SAVED)) if FileAccess.file_exists(SAVED) else {}
		if not all is Dictionary or not all.has(str(l["saved"])):
			push_warning("wardrobe: no saved person '%s' in %s" % [l["saved"], SAVED])
			return l
		look = (all[str(l["saved"])]["look"] as Dictionary).duplicate(true)
	elif l.has("job"):
		look = dress(str(l["job"]), int(l.get("seed", hash(id))))
	else:
		return l
	for k in l:
		if k in ["job", "seed", "saved"]:
			continue
		if l[k] is Dictionary and look.get(k) is Dictionary and str(l[k].get("shape", look[k].get("shape"))) == str(look[k].get("shape")):
			look[k].merge(l[k], true)
		else:
			look[k] = l[k].duplicate(true) if l[k] is Dictionary else l[k]
	return look

static func fabric_of(slot: String, shape: String, spec: Dictionary) -> Array:
	"""[fabric, weave, gloss_b] of a garment (data/wardrobe/fabrics.json, after the OoT remake): its shape's entry
	or its slot's _any, the garment's own "fabric" / "weave" keys on top (a denim colourway brings "weave": "jean")."""
	if _fab.is_empty():
		_fab = JSON.parse_string(FileAccess.get_file_as_string(FABRICS))
	var s: Dictionary = _fab.get(slot, {})
	var f: Array = s.get(shape, s.get("_any", ["vai", "", 0.0])).duplicate()
	if spec.has("fabric"):
		f[0] = spec["fabric"]
	if spec.has("weave"):
		f[1] = spec["weave"]
	return f

static func set_fabric(m: ShaderMaterial, slot: String, spec: Dictionary, mname: String, kid := false) -> void:
	"""The fabric terms of one garment surface (shaders/toon.gdshaderinc TOON_FABRIC: toon_cloth, toon_wear)."""
	if not slot in ["top", "bottom", "shoes", "hat"] or not m.shader in [Chibi.TOON_CLOTH, Chibi.TOON_WEAR]:
		return
	if not fabrics_on:
		m.set_shader_parameter("fabric", 0)
		m.set_shader_parameter("gloss_b", 0.0)
		m.set_shader_parameter("has_weave", false)
		return
	var f := fabric_of(slot, str(spec.get("shape", "")), spec)
	var fab := int(FABRIC_IDS.get(str(f[0]), 0))
	var weave := str(f[1])
	if mname.ends_with("_Badge"):
		fab = FABRIC_IDS["kimloai"]
		weave = ""
	elif mname.ends_with("_Trim") and slot == "shoes":
		weave = ""
	m.set_shader_parameter("fabric", fab)
	m.set_shader_parameter("gloss_b", float(f[2]))
	var path := WEAVE_DIR + weave + ".png"
	var has := weave != "" and ResourceLoader.exists(path)
	m.set_shader_parameter("has_weave", has)
	if has:
		m.set_shader_parameter("weave_tex", load(path))

		var sc := float(_fab["weave_scale"].get(slot, 30.0)) * (Chibi.KID_SCALE if kid else 1.0)
		m.set_shader_parameter("weave_scale", Vector2(sc, sc))

		m.set_shader_parameter("weave_depth", WEAVE_DEPTH.get(weave, 0.3))

static func add_wear(c: Chibi, look: Dictionary) -> Array:
	"""The extras that are their own nodes (scripts/npc/glasses.gd, face_mask.gd, scarf.gd, neck_wear.gd)."""
	return [Glasses.add(c, look), FaceMask.add(c, look), Scarf.add(c, look), NeckWear.add(c, look)].filter(func(n): return n != null)
