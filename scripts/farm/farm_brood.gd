class_name FarmBrood
extends Node

const NIGHTS := 3
const NEED_EGGS := 3
const HATCH := [3, 5]
const NEED_LEVEL := 1
const GROW_NIGHTS := 5

var plot
var sitting := -1
var nights := 0
var chicks := []
var force := false
var grew := 0

func setup(p) -> void:
	plot = p

func broody(i: int) -> bool:
	return i == sitting

func night() -> String:
	grew = 0
	for c in chicks.duplicate():
		c.age = int(c.get("age", 0)) + 1
		if c.age >= GROW_NIGHTS and plot.hens.size() < plot.HEN_CAP:
			plot.add_hen(c.a.position)
			c.a.queue_free()
			chicks.erase(c)
			grew += 1
	if sitting >= 0:
		nights += 1
		if nights < NIGHTS:
			return ""
		var n := mini(randi_range(HATCH[0], HATCH[1]), plot.eggs)
		plot.eggs -= n
		for k in n:
			_add_chick(sitting)
		var h: Dictionary = plot.hens[sitting]
		h.a.play("Sit_End")
		h.wait = 1.5
		sitting = -1
		nights = 0
		return "FARM_T_HATCHED"
	if plot.eggs >= NEED_EGGS and plot.cock.size() > 0 and (force or Progress.level("chan_nuoi") >= NEED_LEVEL):
		sitting = randi() % plot.hens.size()
		nights = 0
		return "FARM_T_BROODY"
	return ""

func _add_chick(mum: int, age := 0) -> void:
	var h: Dictionary = plot.hens[mum]
	var ang := randf() * TAU
	var a := FarmAnimal.spawn(plot, "ga_con", h.a.position + Vector3(cos(ang), 0, sin(ang)) * 0.35, randf() * TAU)
	chicks.append({"a": a, "mum": mum, "off": Vector2(cos(ang), sin(ang)) * randf_range(0.25, 0.55), "wait": randf(),
		"age": age})

func step(delta: float, hidden: bool) -> void:
	if sitting >= 0:
		var h: Dictionary = plot.hens[sitting]
		h.inside = false
		h.a.visible = true
		h.a.position = plot.NEST + Vector3(0, 0.22, 0.05)
		h.a.rotation.y = 0.0
		if h.a._loop != "Sit_Keep":
			h.a.play("Sit_Keep")
	for c in chicks:
		var a: FarmAnimal = c.a
		var mum: Dictionary = plot.hens[c.mum]
		a.visible = not hidden and not mum.inside
		if not a.visible:
			a.position = mum.a.position
			continue
		var goal: Vector3 = mum.a.position + Vector3(c.off.x, 0, c.off.y)
		var to := goal - a.position
		to.y = 0
		if to.length() > 0.15:
			var run := to.length() > 1.0
			var sp: float = FarmAnimal.SPEED.get("ga_con", {"Walk": 0.2, "Run": 0.7})["Run" if run else "Walk"]
			a.position += to.normalized() * minf(sp * delta, to.length())
			a.rotation.y = lerp_angle(a.rotation.y, atan2(to.x, to.z), 1.0 - exp(-delta * 9.0))
			a.play("Run" if run else "Walk")
		else:
			c.wait -= delta
			if c.wait <= 0.0:
				c.wait = randf_range(1.0, 3.5)
				var ang := randf() * TAU
				c.off = Vector2(cos(ang), sin(ang)) * randf_range(0.25, 0.6)
				a.play("Peck" if randf() < 0.6 else "Idle")

func to_dict() -> Dictionary:
	var mums := []
	for c in chicks:
		mums.append([c.mum, int(c.get("age", 0))])
	return {"sitting": sitting, "nights": nights, "chicks": mums}

func from_dict(d: Dictionary) -> void:
	sitting = int(d.get("sitting", -1))
	nights = int(d.get("nights", 0))
	for m in d.get("chicks", []):
		var mum: int = int(m[0]) if m is Array else int(m)
		_add_chick(clampi(mum, 0, plot.hens.size() - 1), int(m[1]) if m is Array else 0)
