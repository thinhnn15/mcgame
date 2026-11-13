class_name WorkSite
extends Node3D

const PANEL := 1.56
const START_H := 7.0
const END_H := 17.0
const HAMMER_AT := Vector3(-1.9, 1.77, 2.9)
const MIX_AT := Vector3(-0.9, 0.0, 5.05)
const BUILDER := {
	"tho_ca": {"skin": "#c08a5e", "hair": "sidepart", "hair_color": "#2e2622",
		"top": {"shape": "tee", "design": "", "color": "#6f95d6", "color_b": "#6f95d6", "trim": "#5a7cb8", "pattern": "plain"},
		"bottom": {"shape": "rolled", "color": "#5d5a55", "color_b": "#5d5a55", "pattern": "plain", "trim": "#4a4744"},
		"shoes": {"shape": "sneakers", "color": "#8a7a68", "color_b": "#8a7a68", "pattern": "plain", "trim": "#6a5c4e"},
		"hat": {"shape": "nonla"}},
	"tho_phu": {"skin": "#b97f55", "hair": "sidepart", "hair_color": "#3a2e26",
		"top": {"shape": "tee", "design": "", "color": "#e0a65a", "color_b": "#e0a65a", "trim": "#c48a44", "pattern": "plain"},
		"bottom": {"shape": "rolled", "color": "#4f5b6b", "color_b": "#4f5b6b", "pattern": "plain", "trim": "#3e4856"},
		"shoes": {"shape": "sneakers", "color": "#8a7a68", "color_b": "#8a7a68", "pattern": "plain", "trim": "#6a5c4e"},
		"hat": {"shape": "helmet", "color": "#f2c230", "color_b": "#2a2a2e"}},
}

var target := 1
var _workers: Array[Chibi] = []
var _on := false
var _alive := true

static func add(yard: Node3D, target_level: int) -> WorkSite:
	var w := WorkSite.new()
	w.name = "WorkSite"
	w.target = target_level
	yard.add_child(w)
	return w

func _ready() -> void:
	_hoarding()
	_scaffolding()
	_materials()
	_spawn_builders()
	_set_on(_working())

func _exit_tree() -> void:
	_alive = false

func _runs() -> Array:
	var right := 4.7 if target >= 2 else 3.4
	return [
		[Vector3(-3.6, 0, -0.5), Vector3(-3.6, 0, 3.7), Vector3(-0.2, 0, 3.7)],
		[Vector3(1.4, 0, 3.7), Vector3(3.0, 0, 3.7), Vector3(right, 0, 2.6), Vector3(right, 0, -0.6)],
	]

func _hoarding() -> void:
	var xf := {"quay_bat": [], "quay_ton": []}
	var body := StaticBody3D.new()
	add_child(body)
	var k := 0
	for run: Array in _runs():
		for i in run.size() - 1:
			var a: Vector3 = run[i]
			var b: Vector3 = run[i + 1]
			var d := b - a
			var n := maxi(1, roundi(d.length() / PANEL))
			var yaw := atan2(-d.z, d.x)
			var basis := Basis(Vector3.UP, yaw).scaled_local(Vector3(d.length() / (n * PANEL), 1, 1))
			for j in n:
				var at := a + d * ((j + 0.5) / n)
				xf["quay_bat" if k % 3 != 1 else "quay_ton"].append(Transform3D(basis, at))
				k += 1
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(d.length(), 1.8, 0.15)
			cs.shape = bs
			cs.transform = Transform3D(Basis(Vector3.UP, yaw), (a + b) / 2.0 + Vector3(0, 0.9, 0))
			body.add_child(cs)
	for nm: String in xf:
		if not (xf[nm] as Array).is_empty():
			HomeKit._batch(self, nm, xf[nm])

func _scaffolding() -> void:
	for x in [-1.9, 1.9]:
		HomeKit.place(self, "gian_giao", Vector3(x, 0, 2.62))
	var ladder := HomeKit.place(self, "thang_tre", Vector3(0.75, 0, 3.4))
	ladder.rotation = Vector3(deg_to_rad(-14.0), 0, 0)

func _materials() -> void:
	HomeKit.place(self, "dong_gach", Vector3(2.0, 0, 4.4), 8.0)
	HomeKit.place(self, "dong_cat", Vector3(-2.3, 0, 4.7), -20.0)
	HomeKit.place(self, "chau_vua", Vector3(-0.9, 0, 4.45))
	HomeKit.place(self, "bao_xi_mang", Vector3(2.7, 0, 5.0), 25.0)

func _spawn_builders() -> void:
	for id: String in BUILDER:
		var look := Looks.DEFAULT.duplicate(true)
		var l: Dictionary = BUILDER[id]
		for key in l:
			look[key] = l[key].duplicate(true) if l[key] is Dictionary else l[key]
		var c := Chibi.new()
		c.name = id
		add_child(c)
		c.build(look)
		if not OS.get_cmdline_user_args().has("--no-merge"):
			ChibiMerge.merge(c)
		_workers.append(c)
	_workers[0].position = HAMMER_AT
	_workers[0].rotation.y = PI
	_workers[1].position = MIX_AT
	_workers[1].rotation.y = PI
	_hammer(_workers[0])
	_mix(_workers[1])

func _working() -> bool:

	if get_tree().get_first_node_in_group("hometown") == null:
		return Clock.hour() >= START_H and Clock.hour() < END_H and not Clock.raining()
	var h := VillageLife.hour()
	return h >= START_H and h < END_H and not VillageLife.raining()

func _set_on(on: bool) -> void:
	_on = on
	for c in _workers:
		c.visible = on
		c.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED

func _process(_d: float) -> void:
	var on := _working()
	if on != _on:
		_set_on(on)

func _still_on() -> bool:
	return _alive and _on

func _hammer(c: Chibi) -> void:
	c.hold("bua")
	while _alive:
		if not _on:
			await get_tree().create_timer(1.0).timeout
			continue
		for i in randi_range(3, 5):
			var impact := c.use_tool("Tool_Axe_Hit")
			if impact < 0.0:
				break
			await get_tree().create_timer(impact).timeout
			if not _alive:
				return
			if _on and c.is_inside_tree():
				Sound.play_at("step.wood", c.global_position + Vector3(0, 0.6, -0.4), 2.0, randf_range(1.35, 1.6))
			await get_tree().create_timer(0.55).timeout
		if not _alive:
			return
		await get_tree().create_timer(randf_range(1.5, 3.5)).timeout

func _mix(c: Chibi) -> void:
	while _alive:
		if not _on:
			await get_tree().create_timer(1.0).timeout
			continue
		Chores.pick_up(c, "cao_thoc")
		if not await Chores.run(c, "rake", randi_range(3, 4), _still_on):
			continue
		await Chores.idle(c, randf_range(4.0, 9.0), _still_on)
