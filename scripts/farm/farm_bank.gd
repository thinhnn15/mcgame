class_name FarmBank
extends Node

const CLIP := "Swim_ClimbOut"
const SRC := "res://characters/anims_extra/pond_climb.glb"
const LEDGE_H := 0.50
const FWD := 0.72
const E_IN := 0.80
const E_SET := 0.74
const E_FREE := 1.17
const PUSH := 0.22
const ARC_PAD := 4.0

var plot: Node3D
var in_pond := false
var climbing := false
var _push := 0.0

static func add(p: Node3D) -> FarmBank:
	var b := FarmBank.new()
	b.name = "FarmBank"
	b.plot = p
	b.process_physics_priority = 10
	p.add_child(b)
	return b

static func ensure_clip(anim: AnimationPlayer) -> bool:
	if anim == null or not anim.has_animation_library(""):
		return false
	if anim.has_animation(CLIP):
		return true
	if not ResourceLoader.exists(SRC):
		return false
	var sc: Node = (load(SRC) as PackedScene).instantiate()
	var ap := sc.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var ok := ap != null and ap.has_animation(CLIP)
	if ok:
		var a: Animation = ap.get_animation(CLIP).duplicate()
		a.loop_mode = Animation.LOOP_NONE
		anim.get_animation_library("").add_animation(CLIP, a)
	sc.free()
	return ok

static func on_stones(x: float, z: float) -> bool:
	var q := (Vector2(x, z) - FarmScenery.POND_C) / FarmScenery.POND_R
	var a := fposmod(rad_to_deg(atan2(q.y, q.x)), 360.0)
	for arc: Array in FarmYard.KE_ARCS:
		if a > float(arc[0]) - ARC_PAD and a < float(arc[1]) + ARC_PAD:
			return true
	return false

func _physics_process(delta: float) -> void:
	var hero: Player = plot.player
	if climbing or hero == null or not is_instance_valid(hero) or hero.riding():
		return
	var p := hero.global_position
	var e := FarmScenery.pond_e(p.x, p.z)
	if not in_pond:
		in_pond = e < E_SET
		_push = 0.0
		return
	if e > E_FREE:
		in_pond = false
		_push = 0.0
		return
	if e <= E_IN or not on_stones(p.x, p.z) or not hero.controls:
		_push = 0.0
		return

	var c := FarmScenery.POND_C
	var q := Vector2(p.x - c.x, p.z - c.y) * sqrt(E_IN / e)
	var at := Vector3(c.x + q.x, 0.0, c.y + q.y)
	at.y = maxf(p.y, plot.scenery.height_at(at.x, at.z))
	hero.global_position = at
	var out := Vector3(q.x / (FarmScenery.POND_R.x * FarmScenery.POND_R.x), 0.0, q.y / (FarmScenery.POND_R.y * FarmScenery.POND_R.y)).normalized()

	var want := Vector3(hero.velocity.x, 0.0, hero.velocity.z)
	if want.dot(out) > 0.25 and not plot._busy:
		_push += delta
		if _push >= PUSH:
			_push = 0.0
			_climb(hero, at, out)
	else:
		_push = 0.0

func _climb(hero: Player, at: Vector3, out: Vector3) -> void:
	if not ensure_clip(hero.chibi.anim):
		return
	climbing = true
	plot._busy = true
	hero.stop_going()
	hero.controls = false
	hero.velocity = Vector3.ZERO
	hero.set_physics_process(false)
	var land := at + out * FWD
	land.y = plot.scenery.height_at(land.x, land.z)
	hero.facing = atan2(out.x, out.z)
	hero.rotation.y = hero.facing
	hero.global_position = Vector3(at.x, land.y - LEDGE_H, at.z)
	var held: String = hero.chibi.tool
	if held != "":
		hero.chibi.hold("")
	hero.chibi.anim.speed_scale = 1.0
	hero.chibi.play(CLIP, 0.12)
	Sound.play_at("water.plop", at + Vector3(0, 0.3, 0), -3.0)
	plot._puff(Vector3(at.x, FarmScenery.WATER_Y + 0.05, at.z), Color("bfe3f2"), 12)
	var len: float = hero.chibi.anim.get_animation(CLIP).length
	await get_tree().create_timer(len - 0.02, false).timeout
	if not is_instance_valid(hero):
		return
	hero.global_position = land
	hero.chibi.play("Base_Wait", 0.0)
	hero.chibi.anim.seek(0.0, true)
	if held != "":
		hero.chibi.hold(held)
	hero.set_physics_process(true)
	hero.controls = true
	plot._busy = false
	in_pond = false
	climbing = false
