class_name FarmWild
extends Node

const SPARROWS := 5
const FROGS := [70.0, 112.0, 28.0]
const FENCE_TOP := 0.9

const SIZE := {"chim_se": 1.4, "ech": 1.5}

var plot
var core = null
var animals: Array[FarmAnimal] = []
var _clips: Array[String] = []
var _hero_was := Vector3.INF
var _hero_speed := 0.0

static func enabled() -> bool:
	return ClassDB.class_exists("FarmCritters")

static func add(p) -> FarmWild:
	if not enabled():
		return null
	var w := FarmWild.new()
	w.name = "FarmWild"
	p.add_child(w)
	w._setup(p)
	return w

func _setup(p) -> void:
	plot = p
	core = ClassDB.instantiate("FarmCritters")
	var s = plot.scenery
	var on_ground := func(x: float, z: float) -> Vector3: return Vector3(x, s.height_at(x, z), z)

	var spots := PackedVector3Array()
	var h := FarmYard.HENS
	for i in 9:
		for j in 7:
			var x := h.position.x - 1.0 + (h.size.x + 0.6) * (i + 0.5) / 9.0
			var z := h.position.y + 0.3 + (h.size.y - 0.6) * (j + 0.5) / 7.0
			if x > 4.7 and z < -0.4:
				continue
			spots.append(on_ground.call(x, z))
	core.set_ground(spots)

	var perches := PackedVector3Array()
	var lines := [[Vector2(h.end.x, h.position.y), Vector2(h.end.x, h.end.y)],
		[Vector2(h.position.x + 2.6, h.end.y), Vector2(h.end.x, h.end.y)],
		[Vector2(-0.1, FarmYard.FRONT_Z), Vector2(3.9, FarmYard.FRONT_Z)]]
	for l: Array in lines:
		var a: Vector2 = l[0]
		var b: Vector2 = l[1]
		var n := int(a.distance_to(b) / 0.3)
		for k in n + 1:
			var q := a.lerp(b, float(k) / n)
			perches.append(on_ground.call(q.x, q.y) + Vector3(0, FENCE_TOP, 0))
	core.set_perches(perches)
	for i in SPARROWS:
		var at: Vector3 = spots[(i * 11 + 5) % spots.size()]
		core.add_sparrow(at)
		_spawn("chim_se", at)
	var c := FarmScenery.POND_C
	var r := FarmScenery.POND_R
	for deg: float in FROGS:
		var d := Vector2(cos(deg_to_rad(deg)), sin(deg_to_rad(deg)))

		var out := 0.15
		while out < 1.2 and s.height_at(c.x + d.x * (r.x + out), c.y + d.y * (r.y + out)) < FarmScenery.WATER_Y + 0.1:
			out += 0.05
		var bank := Vector2(c.x + d.x * (r.x + out + 0.08), c.y + d.y * (r.y + out + 0.08))
		var wet := Vector2(c.x + d.x * (r.x - 0.55), c.y + d.y * (r.y - 0.55))
		core.add_frog(on_ground.call(bank.x, bank.y), Vector3(wet.x, FarmScenery.WATER_Y - 0.01, wet.y))
		_spawn("ech", on_ground.call(bank.x, bank.y))

func _spawn(kind: String, at: Vector3) -> void:
	var a := FarmAnimal.spawn(plot, kind, at, randf() * TAU)
	a.scale *= SIZE.get(kind, 1.0)
	animals.append(a)
	_clips.append("")

func _process(delta: float) -> void:
	if core == null or delta <= 0.0:
		return
	var hero: Vector3 = plot.player.global_position
	if _hero_was != Vector3.INF:
		var v := Vector2(hero.x - _hero_was.x, hero.z - _hero_was.z).length() / delta
		_hero_speed = lerpf(_hero_speed, minf(v, 8.0), 1.0 - exp(-delta * 8.0))
	_hero_was = hero
	if not plot.player.visible:
		hero = Vector3(1e4, 0, 1e4)
	var h := Clock.hour()
	var day := h >= 5.6 and h < 18.6
	core.step(delta, hero, _hero_speed)
	for i in animals.size():
		var a := animals[i]
		var sparrow := a.kind == "chim_se"
		a.visible = day or not sparrow
		if not a.visible:
			continue
		a.position = core.pos(i)
		a.rotation.y = core.yaw(i)
		var cl: String = core.clip(i)
		if cl != _clips[i]:
			_clips[i] = cl
			a.play(cl, 0.08 if sparrow else 0.15)
		match String(core.take_event(i)):
			"flush":
				Sound.play_at("animal.wing_flaps", a.global_position + Vector3(0, 0.3, 0), -8.0)
				Sound.play_at("nature.sparrow", a.global_position + Vector3(0, 0.4, 0), 4.0)
			"splash":
				plot._puff(a.global_position + Vector3(0, 0.03, 0), Color("dcefff"), 6)
				Sound.play_at("water.splash", a.global_position, -16.0, 1.6)
