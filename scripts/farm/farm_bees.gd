class_name FarmBees
extends Node3D

const CALM := 30.0
const ENTRANCE := Vector3(0.0, 0.2, 0.14)
const FRONT := Vector3(0.0, 0.0, 0.75)
const SIDE := Vector3(-0.55, 0.0, -0.05)
const BEES_MIN := 3
const BEES_MAX := 8
const BEE_SCALE := 3.4
const BUMP_SECS := 45.0
const BUMP := Vector3(0.15, 0.15, 0.30)
const BUMP_ROT := Vector3(0.0, 0.55, 0.2)
const PLASTER := "res://props/farm/fx/bang_ca_nhan.png"

var plot
var apiary = null
var bees: Array = []
var _hive_n := -1
var _flowers_at := -1.0
var _out := false
var _bump: Node3D = null
var _bump_t := 0.0

func setup(the_plot) -> void:
	plot = the_plot
	if ClassDB.class_exists("Apiary"):
		apiary = ClassDB.instantiate("Apiary")

func enabled() -> bool:
	return apiary != null

func hives() -> Array:
	return plot.pens.pens.filter(func(p) -> bool: return p.kind == "to_ong")

static func allowed() -> int:
	if not Progress.is_open("to_ong"):
		return 0
	return 1 + int(Progress.is_open("to_ong_2")) + int(Progress.is_open("to_ong_3"))

func _local(p, v: Vector3) -> Vector3:
	return p.node.global_transform * v

func _flowers(at: Vector3, points: PackedVector3Array = PackedVector3Array()) -> Dictionary:
	var out := {}
	var table: Dictionary = Crops.table()
	for c: Vector2i in plot.land.crops:
		var cr: Dictionary = plot.land.crops[c]
		var row: Dictionary = table.get(cr.crop, {})
		if row.is_empty():
			continue
		if not apiary.flowering(cr.crop, int(cr.stage), (row["models"] as Array).size()):
			continue
		var w: Vector3 = plot.land.cell_pos(c, FarmLand.TOP + 0.25)
		if Vector2(w.x - at.x, w.z - at.z).length() > apiary.range():
			continue
		var k: String = apiary.honey_of(cr.crop)
		out[k] = int(out.get(k, 0)) + 1
		points.append(w)
	return out

func pollinated(c: Vector2i) -> bool:
	if not enabled():
		return false
	var w: Vector3 = plot.land.cell_pos(c, 0.0)
	for p in hives():
		var h: Vector3 = p.node.global_position
		if Vector2(w.x - h.x, w.z - h.z).length() <= apiary.range():
			return randf() < 0.5
	return false

func step(delta: float, frozen: bool) -> void:
	if not enabled():
		return
	var hs := hives()
	var hour: float = Clock.hour()
	var out: bool = hs.size() > 0 and hour >= 6.0 and hour < 18.0 and not plot.raining and not frozen
	if hs.size() != _hive_n or out != _out or absf(Clock.minute - _flowers_at) > 30.0:
		_rebuild(hs, out)
	if out:
		var ent := PackedVector3Array()
		for p in hs:
			ent.append(_local(p, ENTRANCE))
		apiary.set_hives(ent)
		apiary.step(delta, bees)
		if OS.get_environment("MC_BEE_LOG") != "" and Engine.get_process_frames() % 60 == 0:
			print("bees: %d hives %d bees, first %s, hive %s" % [hs.size(), bees.size(),
				bees[0].global_position if bees.size() > 0 else "-", hs[0].node.global_position])
	if _bump:
		_bump_t -= delta
		var k := clampf(_bump_t / 6.0, 0.0, 1.0)
		(_bump.get_child(0) as Node3D).scale = Vector3.ONE * maxf(k, 0.01)
		if _bump_t <= 0.0:
			_bump.queue_free()
			_bump = null

func _rebuild(hs: Array, out: bool) -> void:
	_hive_n = hs.size()
	_out = out
	_flowers_at = Clock.minute
	for b in bees:
		(b as Node).queue_free()
	bees.clear()
	apiary.clear_bees()
	if not out:
		return
	var pts := PackedVector3Array()
	var ent := PackedVector3Array()
	var counts := []
	for p in hs:
		ent.append(_local(p, ENTRANCE))
		var f := _flowers(p.node.global_position, pts)
		var n := 0
		for k in f:
			n += int(f[k])
		counts.append(n)
	apiary.set_hives(ent)
	apiary.set_flowers(pts)
	for i in hs.size():
		var full: bool = float(hs[i].data.get("fill", 0.0)) >= 1.0
		var n := clampi(BEES_MIN + int(counts[i]) / 2 + (2 if full else 0), BEES_MIN, BEES_MAX)
		for j in n:
			apiary.add_bee(i)
			var b := FarmAnimal.spawn(self, "ong", ent[i], randf() * TAU)
			b.scale = Vector3.ONE * BEE_SCALE
			b.play.call_deferred("Fly")
			bees.append(b)

func night() -> String:
	if not enabled():
		return ""
	var news := ""
	for p in hives():
		var was := float(p.data.get("fill", 0.0))
		var r: Dictionary = apiary.night(was, _flowers(p.node.global_position))
		p.data["fill"] = float(r["fill"])
		p.data["kind"] = String(r["kind"])
		if was < 1.0 and float(r["fill"]) >= 1.0:
			news = "BEE_T_FULL"
	_flowers_at = -999.0
	return news

func hint_at(pos: Vector3) -> String:
	if not enabled():
		return ""
	for p in hives():
		if p.held:
			continue
		if Vector2(pos.x - p.node.global_position.x, pos.z - p.node.global_position.z).length() < 1.3:
			return "BEE_HINT_FULL" if float(p.data.get("fill", 0.0)) >= 1.0 else "BEE_HINT"
	return ""

func use(pos: Vector3) -> bool:
	if not enabled():
		return false
	var hs := hives()
	for i in hs.size():
		var p = hs[i]
		if p.held:
			continue
		var c: Vector3 = p.node.global_position
		if Vector2(pos.x - c.x, pos.z - c.z).length() > 1.1:
			continue
		var f := _local(p, FRONT)
		if Vector2(pos.x - f.x, pos.z - f.z).length() < 0.5:
			_smoke(i, p)
		else:
			_open(i, p)
		return true
	return false

func _smoke(i: int, p) -> void:
	plot._busy = true
	if await plot._clip("Tool_Grain_Scatter", 24, 40):
		var at := _local(p, ENTRANCE + Vector3(0, 0.1, 0.25))
		for k in 3:
			plot._puff(at + Vector3(randf_range(-0.1, 0.1), 0.05 * k, 0), Color("cfcac0"), 10)
			await get_tree().create_timer(0.25).timeout
		apiary.calm(i, CALM)
		plot.hud.toast(tr("BEE_T_SMOKE"), 2.2)
	plot._busy = false

func _open(i: int, p) -> void:
	var fill := float(p.data.get("fill", 0.0))
	if fill < 1.0:
		var nights := ceili((1.0 - fill) / (1.0 / 3.0))
		plot.hud.toast(tr("BEE_T_NOT_YET") % [roundi(fill * 100.0), maxi(1, nights)], 2.8)
		return
	plot._busy = true
	if await plot._clip("Tool_Egg_Pick", 19, 46):
		var calm: bool = apiary.is_calm(i)
		var kind := String(p.data.get("kind", "bach_hoa"))
		var n: int = apiary.jars(_flowers(p.node.global_position))
		p.data["fill"] = 0.0
		plot._puff(_local(p, Vector3(0, 0.6, 0)), Color("f2b632"), 12)
		plot._gain("MAT_ONG_" + kind.to_upper(), n)
		plot._xp("thu_san_pham")
		if not calm:
			_sting(i)
		_flowers_at = -999.0
	plot._busy = false

func _sting(i: int) -> void:
	var hero: Node3D = plot.player
	apiary.anger(i, hero.global_position, 4.0)
	var ch = plot.player.chibi
	if ch:
		ch.emote("shocked")
		get_tree().create_timer(1.6).timeout.connect(func() -> void:
			if is_instance_valid(ch):
				ch.emote("pout"))
	plot.hud.toast(tr("BEE_T_STUNG"), 3.2)
	if _bump == null and ch and ch.skel:
		var head: int = ch.skel.find_bone("Head")
		if head >= 0:
			var att := BoneAttachment3D.new()
			att.bone_name = "Head"
			ch.skel.add_child(att)
			var m := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(0.11, 0.11)
			var mat := StandardMaterial3D.new()
			mat.albedo_texture = load(PLASTER)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			mat.alpha_scissor_threshold = 0.5
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			q.material = mat
			m.mesh = q
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			att.add_child(m)
			m.position = BUMP
			m.rotation = BUMP_ROT
			_bump = att
			_bump_t = BUMP_SECS
