class_name ChopTree
extends Node3D

const TREE := "res://props/tree_round.glb"
const STUMP := "res://props/tree_round_stump.glb"
const COLORS := {"mTreeTrunk": Color("a3734b"), "mTreeLeaf": Color("7fc96c"), "mTreeCut": Color("f2d9ad")}
const HITS := 3
const LEAF := Color("7fc96c")
const CHIP := Color("e9c58f")

var model: Node3D
var ap: AnimationPlayer
var hits := 0
var felled := false
var _solid: StaticBody3D

signal felled_down(logs: Array)

func _ready() -> void:
	model = load(TREE).instantiate()
	add_child(model)
	_paint(model)
	ap = model.find_child("AnimationPlayer", true, false)
	_solid = _collider(0.22, 1.5)

func _paint(n: Node) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var src: Material = mi.mesh.surface_get_material(s)
			var m := ShaderMaterial.new()
			m.shader = Props.TOON
			m.set_shader_parameter("base_color", COLORS.get(src.resource_name if src else "", Color("b0b0b0")))
			mi.set_surface_override_material(s, m)

func _collider(r: float, h: float) -> StaticBody3D:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = r
	sh.height = h
	cs.shape = sh
	cs.position.y = h * 0.5
	sb.add_child(cs)
	add_child(sb)
	return sb

func hit(chopper: Node3D, blade: Vector3) -> void:
	"""One axe hit from chopper (the player), the blade at world point blade."""
	if felled:
		return
	hits += 1
	_burst(blade, CHIP, Props.box(Vector3(0.05, 0.03, 0.02)), 10, (chopper.global_position - blade).normalized(), 2.6, 9.8, 0.55)
	if hits < HITS:
		ap.stop()
		ap.play("Tree_Shake")
		_leaves(4)
		return
	_fell(chopper)

func _fell(chopper: Node3D) -> void:
	felled = true

	var fwd := global_position - chopper.global_position
	fwd.y = 0.0
	var their_left := Vector3.UP.cross(fwd.normalized())

	var l := global_transform.basis.inverse() * their_left
	var dir := Vector3(signf(l.x), 0, 0) if absf(l.x) >= absf(l.z) else Vector3(0, 0, signf(l.z))
	var clip := "Tree_Fall_%s%s" % ["P" if dir.x + dir.z > 0 else "N", "X" if dir.x != 0 else "Z"]
	ap.stop()
	ap.play(clip)
	_leaves(8)
	var stump: Node3D = load(STUMP).instantiate()
	add_child(stump)
	_paint(stump)
	_solid.queue_free()
	_solid = _collider(0.2, 0.28)
	await ap.animation_finished

	var landed := global_transform * (dir * 1.6 + Vector3(0, 0.4, 0))
	_burst(landed, Color("fbf7ee"), Props.sphere(0.12), 14, Vector3.UP, 1.4, 0.5, 0.7)
	var tw := create_tween()
	tw.tween_property(model, "scale", Vector3(0.01, 0.01, 0.01), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(model.queue_free)
	var logs := []
	for i in 3:
		logs.append(_log(landed, i))
	felled_down.emit(logs)

func _log(from: Vector3, i: int) -> Node3D:
	"""A little log that hops out of the puff and settles on the grass."""
	var lg := Node3D.new()
	get_parent().add_child(lg)
	var wood := Props.mesh(lg, Props.cyl(0.075, 0.075, 0.3), COLORS["mTreeTrunk"], Vector3.ZERO, Vector3(0, 0, 90))
	Props.mesh(lg, Props.cyl(0.062, 0.062, 0.302), COLORS["mTreeCut"], Vector3.ZERO, Vector3(0, 0, 90))
	wood.scale = Vector3(1, 0.98, 1)
	var a := TAU * (float(i) / 3.0) + 0.6
	var to := Vector3(from.x, 0.075, from.z) + Vector3(cos(a), 0, sin(a)) * 0.55
	lg.global_position = Vector3(from.x, 0.4, from.z)
	lg.rotation.y = a
	var tw := lg.create_tween().set_parallel()
	tw.tween_property(lg, "global_position:x", to.x, 0.45)
	tw.tween_property(lg, "global_position:z", to.z, 0.45)
	var up := lg.create_tween()
	up.tween_property(lg, "global_position:y", 0.75, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	up.tween_property(lg, "global_position:y", to.y, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	return lg

func _leaves(n: int) -> void:
	var p := _burst(global_position + Vector3(0, 1.7, 0), LEAF, _leaf_mesh(), n, Vector3.UP, 0.8, 1.2, 1.6)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.7, 0.3, 0.7)
	p.angular_velocity_min = -180.0
	p.angular_velocity_max = 180.0
	var lm := StandardMaterial3D.new()
	lm.albedo_color = LEAF
	lm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	lm.cull_mode = BaseMaterial3D.CULL_DISABLED
	(p.mesh as PrimitiveMesh).material = lm

func _leaf_mesh() -> Mesh:
	var q := QuadMesh.new()
	q.size = Vector2(0.1, 0.07)
	return q

func _burst(at: Vector3, c: Color, m: Mesh, n: int, dir: Vector3, speed: float, gravity: float, life: float) -> CPUParticles3D:
	"""A one-shot spray of small toon pieces (chips, leaves, a puff of dust)."""
	var p := CPUParticles3D.new()
	p.emitting = false
	(m as PrimitiveMesh).material = Props.mat(c)
	p.mesh = m
	p.amount = n
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = life
	p.direction = dir
	p.spread = 55.0
	p.initial_velocity_min = speed * 0.6
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -gravity, 0)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(0.7, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	get_parent().add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(life + 0.5).timeout.connect(p.queue_free)
	return p
