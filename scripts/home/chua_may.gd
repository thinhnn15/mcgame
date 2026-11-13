class_name ChuaMay
extends Node3D

signal rang
signal rang_too_soon
signal through_door(up: bool)

const K := 0.78
const L1 := 3.0
const L2 := 6.5
const HALL := Vector3(0, L1, -34.0)
const BELL_TOWER := Vector3(-12.0, L1, -21.0)
const BELL_YAW := 30.0
const WELL := Vector3(12.0, L1, -21.0)
const BURNER := Vector3(0, L1, -24.5)
const TOWER := Vector3(0, L2, -64.0)
const BALCONY := 25.26
const BALCONY_IN := 5.02
const BALCONY_OUT := 7.02
const NEAR := 1.7
const DEEP := 12.0

var stair_drop := 20.0
var bell_rest := 0.0
var locked := false
var _last_toll := -1000.0

var hero: Player
var cam: OrbitCam
var striker: Node3D
var _tower: Node3D
var _bell_tower: Node3D
var _swinging := false
var _moving := false
var _hint: Label
var _fade: ColorRect
var _hall: Node3D
var _cam_out := Vector2.ZERO
var _world: Node3D
var _see := []

static func add_to_map(world: Node3D, p: Vector3) -> ChuaMay:
	var chua := ChuaMay.new()
	chua.name = "ChuaThapMay"
	var t: Dictionary = {}
	var lay = world.get("layout")
	if lay is Dictionary:
		t = lay.get("temple", {})
	var o := Vector3(p.x, 22.0, p.z)
	var foot_y := 2.0
	if t.has("o"):
		o = Vector3(t["o"][0], t["o"][1], t["o"][2])
		foot_y = float(t["stair"][-1][1])
	chua.position = o
	chua.stair_drop = o.y - foot_y
	chua._world = world
	world.add_child(chua)
	chua.build(true)
	chua._far_ranges()
	ChuaSuKien.register()
	return chua

func _far_ranges() -> void:
	for gi: GeometryInstance3D in find_children("*", "GeometryInstance3D", true, false):
		if gi.visibility_range_end > 0.0 or _tower.is_ancestor_of(gi):
			continue
		var big := 0.0
		if gi is MeshInstance3D and (gi as MeshInstance3D).mesh:
			var size := (gi as MeshInstance3D).mesh.get_aabb().size * gi.global_transform.basis.get_scale()
			big = maxf(size.x, maxf(size.y, size.z))
		gi.visibility_range_end = 600.0 if big > 4.0 else 120.0
		gi.visibility_range_end_margin = 8.0

func build(with_terraces := true) -> void:
	if with_terraces:
		_terraces()
	ChuaMayBac.build(self, stair_drop)
	var gate := HomeKit.place(self, "tam_quan_may", Vector3.ZERO, 0.0)
	_gate_solid(gate)

	_shade(Furniture.place(gate, "ho_phap_thien", Vector3(-5.15, 1.7, 0) * K, 90.0, false))
	_shade(Furniture.place(gate, "ho_phap_ac", Vector3(5.15, 1.7, 0) * K, -90.0, false))
	var arhats := [1, 5, 3, 7, 2, 6, 4, 8]
	var corridors: Array[Node3D] = []
	for i in 2:
		var sx := -1.0 if i == 0 else 1.0
		var c := HomeKit.place(self, "hanh_lang_may", Vector3(sx * 7.5, 0.0, -9.0), -90.0 * sx)
		corridors.append(c)
		_corridor_solid(c)
		for k in 4:
			var n: int = arhats[i * 4 + k]
			_shade(Furniture.place(c, "la_han_%d" % n, Vector3(-7.2 + 3.6 * (k + 0.5), 1.1, -1.35) * K, (n * 37 % 30) - 15.0, false), 30.0)
	_bell_tower = HomeKit.place(self, "gac_chuong", BELL_TOWER, BELL_YAW)
	_bell_solid(_bell_tower)
	striker = Furniture.place(_bell_tower, "chay_chuong", Vector3(1.9, 5.65, 0) * K, 0.0, false)
	var well := HomeKit.place(self, "gieng_ngoc", WELL, 0.0)
	_well(well)
	Furniture.place(self, "lu_huong_lon", BURNER, 0.0, true)
	_smoke(BURNER + Vector3(0, 1.36, 0), 16, 0.45, 0.4, 5.0)
	var hall := HomeKit.place(self, "chinh_dien_may", HALL, 0.0)
	_hall = hall
	_hall_solid(hall)

	for it: Array in [["tuong_phat", 0.0], ["hao_quang", -0.55]]:
		var s := Furniture.place(hall, it[0], Vector3(0, 2.6, -2.875) * K + Vector3(0, 0, it[1] * 1.3), 0.0, false)
		s.scale = Vector3.ONE * 1.3
		_shade(s, 60.0)
	Furniture.place(hall, "le_vat_chua", Vector3(0, 2.2, -0.55) * K, 0.0, false)
	_smoke(HALL + Vector3(0, 2.2 * K + 0.5, -0.55 * K), 7, 0.16, 0.2, 3.2)
	_tower = HomeKit.place(self, "thap_may", TOWER, 0.0)
	_tower_solid(_tower)
	ChuaMayCanh.dress(self)
	for n: Node3D in [gate, _bell_tower, _hall, _tower] + corridors:
		_see_setup(n)
	_ui()
	TouchControls.add_action(self, _touch_act, 10)

func _unhandled_input(e: InputEvent) -> void:
	if hero == null or not hero.controls:
		return
	if locked:
		return
	if (e is InputEventKey and e.pressed and not e.echo and e.physical_keycode in [KEY_E, KEY_F]) \
			or (e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_X):
		var act := _near()
		if not act.is_empty():
			act["run"].call()

func _process(_delta: float) -> void:
	if hero == null and _world != null:
		hero = _world.get("player") as Player
		if hero != null and _world.get("cam") is OrbitCam:
			cam = _world.get("cam")
	if hero == null:
		return
	_steep_steps()
	_see_through(_delta)
	var act := _near()
	_hint.text = ("F: " + str(act["label"])) if not act.is_empty() and not locked else ""
	_hall_camera()

var _floor_out := -1.0

func _steep_steps() -> void:
	var p := to_local(hero.global_position)
	var on := p.x > -26.0 and p.x < 26.0 and p.z > -82.0 and p.z < 33.0 and p.y > -3.0
	if on and _floor_out < 0.0:
		_floor_out = hero.floor_max_angle
		hero.floor_max_angle = maxf(hero.floor_max_angle, deg_to_rad(46.0))
	elif not on and _floor_out >= 0.0:
		hero.floor_max_angle = _floor_out
		_floor_out = -1.0

func _see_setup(n: Node3D) -> void:
	var box := AABB()
	var meshes := []
	var inv := n.global_transform.affine_inverse()
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var b: AABB = (inv * mi.global_transform) * mi.mesh.get_aabb()
		box = b if meshes.is_empty() else box.merge(b)
		meshes.append(mi)
	_see.append([n, box, meshes, 0.0])

func _see_through(delta: float) -> void:
	var c := get_viewport().get_camera_3d()
	if c == null:
		return
	var eye := c.global_position
	var head := hero.global_position + Vector3(0, 0.9, 0)
	for e: Array in _see:
		var n: Node3D = e[0]
		var inv := n.global_transform.affine_inverse()
		var box: AABB = (e[1] as AABB).grow(0.3 if e[3] > 0.0 else 0.0)
		var hit := box.intersects_segment(inv * eye, inv * (head + (eye - head).normalized() * 0.6)) != null
		var f := move_toward(e[3], 0.72 if hit else 0.0, delta * 3.0)
		if f == e[3]:
			continue
		var was: float = e[3]
		e[3] = f
		for mi: MeshInstance3D in e[2]:
			if not is_instance_valid(mi):
				continue
			for si in mi.mesh.get_surface_count():
				var m := mi.get_surface_override_material(si)
				if m == null and si == 0:
					m = mi.material_override
				if was == 0.0 and not mi.has_meta("solid_%d" % si) and m is ShaderMaterial:
					var fm := HomeKit.fade_material(m)
					if fm == null:
						continue
					mi.set_meta("solid_%d" % si, m)
					if mi.get_surface_override_material(si) != null:
						mi.set_surface_override_material(si, fm)
					else:
						mi.material_override = fm
				if f == 0.0 and mi.has_meta("solid_%d" % si):
					var solid: Material = mi.get_meta("solid_%d" % si)
					if mi.get_surface_override_material(si) != null:
						mi.set_surface_override_material(si, solid)
					else:
						mi.material_override = solid
					mi.remove_meta("solid_%d" % si)
			mi.set_instance_shader_parameter("fade", f)

func _hall_camera() -> void:
	if cam == null:
		return
	var p := _hall.to_local(hero.global_position) / K
	var inside := absf(p.x) < 9.0 and p.z > -4.4 and p.z < 3.6 and p.y > 0.8
	if inside and _cam_out == Vector2.ZERO:
		_cam_out = Vector2(cam.dist, cam.pitch)
		cam.dist = 3.6
		cam.pitch = deg_to_rad(12.0)
	elif not inside and _cam_out != Vector2.ZERO:
		cam.dist = _cam_out.x
		cam.pitch = _cam_out.y
		_cam_out = Vector2.ZERO

func _touch_act() -> Dictionary:
	return _near()

func _near() -> Dictionary:
	if _swinging or _moving or hero == null:
		return {}
	var p := hero.global_position
	var rope := striker.to_global(Vector3(0.74, -2.9, 0))
	if Vector2(p.x - rope.x, p.z - rope.z).length() < NEAR and absf(p.y - rope.y) < 1.5:
		return {"label": tr("TC_BELL"), "run": ring_bell}
	if p.distance_to(_tower.to_global(Vector3(0, 2.4, 6.6 + 0.9) * K)) < NEAR + 0.6:
		return {"label": tr("TC_TOWER_UP"), "run": func(): _through_door(true)}
	if p.distance_to(_tower.to_global(Vector3(0, BALCONY, BALCONY_IN + 0.6) * K)) < NEAR:
		return {"label": tr("TC_TOWER_DOWN"), "run": func(): _through_door(false)}
	return {}

func ring_bell() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_toll < bell_rest:
		rang_too_soon.emit()
		return
	_swinging = true
	var tw := create_tween()
	tw.tween_property(striker, "rotation:z", deg_to_rad(24.0), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(0.15)
	tw.tween_property(striker, "rotation:z", deg_to_rad(-1.5), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		Sound.play_at("temple.bell", _bell_tower.to_global(Vector3(0, 3.6, 0) * K))
		_last_toll = Time.get_ticks_msec() / 1000.0
		rang.emit())
	tw.tween_property(striker, "rotation:z", deg_to_rad(9.0), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(striker, "rotation:z", deg_to_rad(-2.0), 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(striker, "rotation:z", deg_to_rad(3.0), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(striker, "rotation:z", 0.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func(): _swinging = false)

func _through_door(up: bool) -> void:
	_moving = true
	hero.controls = false
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.45)
	tw.tween_callback(func():

		var at := Vector3(0, BALCONY + 0.05, BALCONY_IN + 1.0) if up else Vector3(0, 2.45, 6.6 + 1.6)
		var face := PI / 2 if up else 0.0
		hero.velocity = Vector3.ZERO
		hero.global_position = _tower.to_global(at * K)
		hero.rotation.y = face
		hero.facing = face
		hero.reset_physics_interpolation()
		if cam != null:
			cam.follow(hero, -PI / 2 if up else PI))
	tw.tween_interval(0.5 if up else 0.3)
	tw.tween_property(_fade, "color:a", 0.0, 0.5)
	tw.tween_callback(func():
		hero.controls = true
		_moving = false
		through_door.emit(up))

func _ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 22)
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_top = -90
	_hint.offset_left = -200
	_hint.offset_right = 200
	layer.add_child(_hint)

func _shade(n: Node3D, far := 45.0) -> void:
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = far
		mi.visibility_range_end_margin = 4.0

func _well(well: Node3D) -> void:
	"""Giếng Ngọc's water (tools/hometown/gieng_ngoc.py: inner radius 4.0, surface 0.45 design m), jade-green."""
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 4.0 * K
	cm.bottom_radius = 4.0 * K
	cm.height = 0.02
	cm.radial_segments = 32
	cm.rings = 1
	mi.mesh = cm
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/home_water.gdshader")
	m.set_shader_parameter("noise_tex", load("res://props/farm/ground/noise.png"))
	m.set_shader_parameter("has_depth", false)
	m.set_shader_parameter("shallow_col", Color("5fae9a"))
	m.set_shader_parameter("deep_col", Color("2f7a72"))
	m.set_shader_parameter("shore_col", Color("8fcab4"))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, 0.45 * K, 0)
	well.add_child(mi)
	var b := _body(well)
	for i in 16:
		var t := TAU * (i + 0.5) / 16
		_box(b, Vector3(2 * 4.3 * tan(PI / 16) + 0.2, 1.7, 0.6), Vector3(4.3 * cos(t), 0.85, 4.3 * sin(t)), -rad_to_deg(t) + 90.0)

static var _puff: Texture2D

func _smoke(at: Vector3, amount: int, spread: float, alpha: float, life: float) -> void:
	"""Incense smoke: a few soft puffs rising, widening and fading, drifting a little with the breeze."""
	if _puff == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0.55))
		g.set_color(1, Color(1, 1, 1, 0.0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(0.5, 0.0)
		gt.width = 64
		gt.height = 64
		_puff = gt
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.position = at
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = spread * 0.3
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 6.0
	pm.initial_velocity_min = 0.22
	pm.initial_velocity_max = 0.32
	pm.gravity = Vector3(0.05, 0.03, 0.02)
	pm.damping_min = 0.02
	pm.damping_max = 0.05
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.3))
	sc.add_point(Vector2(1, 1.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	pm.scale_min = spread
	pm.scale_max = spread * 1.4
	var cr := Gradient.new()
	cr.set_color(0, Color(0.92, 0.92, 0.95, 0.0))
	cr.add_point(0.15, Color(0.92, 0.92, 0.95, alpha))
	cr.set_color(cr.get_point_count() - 1, Color(0.92, 0.92, 0.95, 0.0))
	var crt := GradientTexture1D.new()
	crt.gradient = cr
	pm.color_ramp = crt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var sm := StandardMaterial3D.new()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	sm.albedo_texture = _puff
	sm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	q.material = sm
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-2, -0.5, -2), Vector3(4, 4, 4))
	add_child(p)

func _body(n: Node3D) -> StaticBody3D:
	var b := StaticBody3D.new()
	n.add_child(b)
	return b

func _box(b: StaticBody3D, size: Vector3, centre: Vector3, yaw := 0.0) -> void:
	var s := BoxShape3D.new()
	s.size = size * K
	var cs := CollisionShape3D.new()
	cs.shape = s
	cs.position = centre * K
	cs.rotation.y = deg_to_rad(yaw)
	b.add_child(cs)

func _cyl(b: StaticBody3D, r: float, y0: float, h: float, x: float, z: float) -> void:
	var s := CylinderShape3D.new()
	s.radius = r * K
	s.height = h * K
	var cs := CollisionShape3D.new()
	cs.shape = s
	cs.position = Vector3(x, y0 + h / 2.0, z) * K
	b.add_child(cs)

func _ramp(b: StaticBody3D, lo: Vector3, hi: Vector3, width: float, scale_k := K) -> void:
	var a := lo * scale_k
	var c := hi * scale_k
	var fwd := (c - a).normalized()
	var up := (Vector3.UP - fwd * fwd.dot(Vector3.UP)).normalized()
	var s := BoxShape3D.new()
	s.size = Vector3(width * scale_k, 0.2, (c - a).length() + 0.3)
	var cs := CollisionShape3D.new()
	cs.shape = s
	cs.transform = Transform3D(Basis(up.cross(fwd), up, fwd), (a + c) / 2.0 - up * 0.1)
	b.add_child(cs)

func _oct(b: StaticBody3D, a: float, y0: float, h: float) -> void:
	for yaw in [0.0, 45.0]:
		_box(b, Vector3(2 * a, h, 2 * a), Vector3(0, y0 + h / 2.0, 0), yaw)

func _terraces() -> void:
	"""The temple's three stone platforms - the forecourt, the main yard, the tower's - going DEEP down into the hill
	(their sides are the retaining walls the hill shows), and the flights between them (built metres), solid."""
	var stone := ChuaMayCanh.stone()
	var b := _body(self)
	for t: Array in [[0.0, -14.0, 31.0, 48.0], [L1, -48.0, -14.0, 44.0], [L2, -79.0, -49.0, 30.0]]:
		var size := Vector3(t[3], DEEP + t[0], t[2] - t[1])
		var c := Vector3(0, (t[0] - DEEP) / 2.0, (t[1] + t[2]) / 2.0)
		_slab(c, size, stone)
		_box(b, size / K, c / K)
	_steps(Vector3(0, 0, -5.5), 9.0, L1, 6.0, stone)
	_ramp(b, Vector3(0, 0, -5.5), Vector3(0, L1, -14.5), 6.0, 1.0)
	_steps(Vector3(0, L1, -43.0), 6.0, L2 - L1, 6.0, stone)
	_ramp(b, Vector3(0, L1, -43.0), Vector3(0, L2, -49.0), 6.0, 1.0)

func _gate_solid(n: Node3D) -> void:
	"""tam_quan_may.py: the platform (P 0.8) with steps front and back on the middle bay, the columns, the brick
	end walls, the guardians' pedestals."""
	var b := _body(n)
	_box(b, Vector3(19, 0.8, 8.4), Vector3(0, 0.4, 0))
	for sz in [-1.0, 1.0]:
		_ramp(b, Vector3(0, 0, sz * 5.45), Vector3(0, 0.8, sz * 4.2), 5.4)
	for x in [-7.3, -3.0, 3.0, 7.3]:
		for z in [-2.6, 2.6]:
			_cyl(b, 0.4, 0.8, 5.4, x, z)
	for sx in [-1.0, 1.0]:
		_box(b, Vector3(0.62, 4.1, 5.8), Vector3(sx * 7.65, 0.8 + 2.05, 0))
		_box(b, Vector3(2.2, 0.9, 2.0), Vector3(sx * 5.15, 0.8 + 0.45, 0))

func _corridor_solid(n: Node3D) -> void:
	"""hanh_lang_may.py: the stone floor (0.4, a ramp along its open side), the back wall, the pedestals, the columns."""
	var b := _body(n)
	_box(b, Vector3(14.4, 0.4, 5.2), Vector3(0, 0.2, 0))
	_ramp(b, Vector3(0, 0, 3.3), Vector3(0, 0.4, 2.6), 14.4)
	_box(b, Vector3(14.4, 3.8, 0.62), Vector3(0, 1.9, -2.15))
	for k in 4:
		_box(b, Vector3(1.3, 0.7, 0.9), Vector3(-7.2 + 3.6 * (k + 0.5), 0.75, -1.35))
	for k in 5:
		_cyl(b, 0.34, 0.4, 3.4, -7.2 + 3.6 * k, 1.9)

func _bell_solid(n: Node3D) -> void:
	"""gac_chuong.py: the two-step octagonal plinth (FL 1.0) and its front stair, the balustrade (open at the
	stair), the eight columns, the bell."""
	var b := _body(n)
	_oct(b, 7.2, 0.0, 0.55)
	_oct(b, 6.6, 0.55, 0.45)
	_ramp(b, Vector3(0, 0, 7.95), Vector3(0, 1.0, 6.6), 3.0)
	var r := 6.35 / cos(PI / 8)
	for i in 8:
		if i == 1:
			continue
		var t0 := deg_to_rad(22.5 + 45 * i)
		var t1 := deg_to_rad(22.5 + 45 * (i + 1))
		var p0 := Vector2(r * cos(t0), r * sin(t0))
		var p1 := Vector2(r * cos(t1), r * sin(t1))
		var m := (p0 + p1) / 2.0
		_box(b, Vector3(p0.distance_to(p1), 1.2, 0.3), Vector3(m.x, 1.6, m.y), -rad_to_deg(atan2(p1.y - p0.y, p1.x - p0.x)))
	for i in 8:
		var t := deg_to_rad(22.5 + 45 * i)
		_cyl(b, 0.42, 1.0, 5.0, 4.2 * cos(t), 4.2 * sin(t))
	_cyl(b, 1.0, 1.0, 3.7, 0, 0)

func _hall_solid(n: Node3D) -> void:
	"""chinh_dien_may.py: the platform (P 1.2), its steps and front balustrade, the brick walls, the shut end bays
	and the posts between the doors, the verandah's columns, the altar and the offering table."""
	var b := _body(n)
	_box(b, Vector3(22, 1.2, 14.8), Vector3(0, 0.6, 0.6))
	_ramp(b, Vector3(0, 0, 9.6), Vector3(0, 1.2, 8.0), 10.8)
	for sx in [-1.0, 1.0]:
		_box(b, Vector3(5.5, 1.1, 0.3), Vector3(sx * 8.15, 1.75, 8.1))
		_box(b, Vector3(0.5, 5.2, 8.0), Vector3(sx * 9.0, 3.8, -0.4))
		_box(b, Vector3(3.6, 5.2, 0.3), Vector3(sx * 7.2, 3.8, 3.55))
	_box(b, Vector3(18.5, 5.2, 0.5), Vector3(0, 3.8, -4.4))
	for k in 6:
		_box(b, Vector3(0.4, 5.2, 0.4), Vector3(-9.0 + 3.6 * k, 3.8, 3.6))
		_cyl(b, 0.42, 1.2, 5.6, -9.0 + 3.6 * k, 6.2)
	_box(b, Vector3(12.24, 1.4, 2.8), Vector3(0, 1.9, -3.0))
	_box(b, Vector3(4.4, 1.0, 1.0), Vector3(0, 1.7, -0.55))

func _tower_solid(n: Node3D) -> void:
	"""thap_may.py: the two-tier terrace (1.3 + 1.1) with a flight of steps on each side, the first storey (apothem
	6.6), and up at the fifth storey the balcony walkway with its balustrade, the wall behind it."""
	var b := _body(n)
	_box(b, Vector3(20, 2.4, 20), Vector3(0, 1.2, 0))
	for side in 4:
		var yaw := 90.0 * side
		var d := Vector2(cos(deg_to_rad(yaw)), -sin(deg_to_rad(yaw)))
		for u in [-1.0, 1.0]:
			var c := Vector3(d.x * 11.5 + (-d.y) * u * 7.25, 0.65, d.y * 11.5 + d.x * u * 7.25)
			_box(b, Vector3(3.0, 1.3, 11.5), c, yaw)
		_ramp(b, Vector3(d.x * 13.6, 0, d.y * 13.6), Vector3(d.x * 10.0, 2.4, d.y * 10.0), 3.6)
	_oct(b, 6.6, 2.4, 8.0)
	_oct(b, BALCONY_OUT, BALCONY - 0.3, 0.3)
	_oct(b, BALCONY_IN, BALCONY, 4.0)
	var side_len := 2.0 * BALCONY_OUT * tan(PI / 8)
	for i in 8:
		var t := deg_to_rad(45.0 * i)
		_box(b, Vector3(side_len + 0.3, 1.3, 0.3), Vector3((BALCONY_OUT - 0.1) * cos(t), BALCONY + 0.65,
			(BALCONY_OUT - 0.1) * sin(t)), -rad_to_deg(t) + 90.0)

func _slab(centre: Vector3, size: Vector3, side: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = side
	mi.position = centre
	add_child(mi)

func _steps(at: Vector3, run: float, rise: float, width: float, m: Material) -> void:
	var n := int(rise / 0.18)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var bm := BoxMesh.new()
		bm.size = Vector3(width, rise * (i + 1) / n, run / n)
		st.append_from(bm, 0, Transform3D(Basis(), Vector3(0, bm.size.y / 2, -run * (i + 0.5) / n)))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	mi.position = at
	add_child(mi)
