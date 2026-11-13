class_name HomeTerrain
extends Node3D

const NEAR_STEP := 1
const NEAR_CHUNK := 32
const NEAR_R := 64.0
const NEAR_FREE := 110.0
const NEAR_PER_FRAME := 3
const MID_STEP := 4
const MID_BLOCK := 128
const MID_R := 340.0
const MID_SINK := 0.25
const FAR_STEP := 16
const FAR_BLOCK := 512
const FAR_SINK := 0.8
const SKIRT := 1.6

var focus: Node3D
var heights: PackedFloat32Array
var mats: PackedByteArray
var n := 0
var half := 0
var pal := {}
var near := {}
var _want: Array[Vector2i] = []
var _mat_near: ShaderMaterial
var _mat_mid: ShaderMaterial
var _mat_far: ShaderMaterial
var _tick := 0.0

var road_sdf: Texture2D = null
var road_sdf_data: PackedByteArray
var rail_sdf: Texture2D = null
var rail_sdf_data: PackedByteArray

func setup(h: PackedFloat32Array, mat_img: Image, size: int, half_size: int, palette: Dictionary, player: Node3D) -> void:
	heights = h
	var img := mat_img.duplicate() as Image
	img.convert(Image.FORMAT_L8)
	mats = img.get_data()
	n = size
	half = half_size
	pal = palette
	focus = player
	var sh := preload("res://shaders/greybox_terrain.gdshader")
	_mat_near = ShaderMaterial.new()
	_mat_near.shader = sh

	if OS.get_environment("MC_FILL_RING_OLD") != "1" and not OS.get_cmdline_user_args().has("--groundao-bake"):
		_mat_near.shader = preload("res://scripts/home/shader_copy.gd").with_define(sh, "TERR_NO_RING")
	_mat_mid = ShaderMaterial.new()
	_mat_mid.shader = sh
	_mat_mid.set_shader_parameter("ring", Vector2(NEAR_R - 16.0, MID_R))
	_mat_far = ShaderMaterial.new()
	_mat_far.shader = sh
	_mat_far.set_shader_parameter("ring", Vector2(MID_R - 40.0, 100000.0))

	_mat_mid.set_shader_parameter("depth_push", MID_SINK)
	_mat_far.set_shader_parameter("depth_push", FAR_SINK)
	if OS.get_environment("MC_FILL_TERR_OLD") == "1":
		for m in [_mat_near, _mat_mid, _mat_far]:
			m.set_shader_parameter("fill_skip", false)
	if road_sdf:
		var rc: Color = pal.get(ROAD, Color.WHITE)
		for m in [_mat_near, _mat_mid, _mat_far]:
			m.set_shader_parameter("road_sdf", road_sdf)
			m.set_shader_parameter("road_on", true)
			m.set_shader_parameter("road_col", Vector3(rc.r, rc.g, rc.b))
			m.set_shader_parameter("grid_n", float(n))
			m.set_shader_parameter("grid_half", float(half))
	if rail_sdf:
		var bc: Color = pal.get(BALLAST, Color.GRAY)
		for m in [_mat_near, _mat_mid, _mat_far]:
			m.set_shader_parameter("rail_sdf", rail_sdf)
			m.set_shader_parameter("rail_on", true)
			m.set_shader_parameter("ballast_col", Vector3(bc.r, bc.g, bc.b))
			m.set_shader_parameter("grid_n", float(n))
			m.set_shader_parameter("grid_half", float(half))
	if ResourceLoader.exists("res://props/farm/ground/grass_detail.png"):
		var gt: Texture2D = load("res://props/farm/ground/grass_detail.png")
		for m in [_mat_near, _mat_mid]:
			m.set_shader_parameter("grass_tex", gt)
			m.set_shader_parameter("has_grass_tex", true)
	if ResourceLoader.exists("res://props/hometown/karst/rock_tile.png"):
		var rt: Texture2D = load("res://props/hometown/karst/rock_tile.png")
		for m in [_mat_near, _mat_mid]:
			m.set_shader_parameter("rock_tex", rt)
			m.set_shader_parameter("has_rock", true)
	var cells := (n - 1) / FAR_BLOCK
	for bz in cells:
		for bx in cells:
			_add_block(bx * FAR_BLOCK, bz * FAR_BLOCK, FAR_BLOCK / FAR_STEP, FAR_STEP, 0.0, _mat_far, 0.0)
	cells = (n - 1) / MID_BLOCK
	for bz in cells:
		for bx in cells:
			_add_block(bx * MID_BLOCK, bz * MID_BLOCK, MID_BLOCK / MID_STEP, MID_STEP, 0.0, _mat_mid,
				MID_R + MID_BLOCK * 0.71)
	_update_near(1000)

func _add_block(x0: int, z0: int, cells: int, step: int, sink: float, m: ShaderMaterial, end: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := Vector3(x0 + cells * step * 0.5 - half, 0, z0 + cells * step * 0.5 - half)
	mi.mesh = _grid_mesh(x0, z0, cells, step, sink, c)
	mi.material_override = m
	mi.position = c
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if end > 0.0:
		mi.visibility_range_end = end
	add_child(mi)
	return mi

const ROAD := 3
const BALLAST := 11

func set_all(param: String, value: Variant) -> void:
	"""One shader parameter on the near, mid and far ground (03/11: the Núi Rồng zone)."""
	for m in [_mat_near, _mat_mid, _mat_far]:
		m.set_shader_parameter(param, value)

func height_at_grid(gx: int, gz: int) -> float:
	return heights[clampi(gz, 0, n - 1) * n + clampi(gx, 0, n - 1)]

func _grid_mesh(x0: int, z0: int, cells: int, step: int, sink: float, centre: Vector3) -> ArrayMesh:
	var road := road_sdf_data if road_sdf else PackedByteArray()
	var rail := rail_sdf_data if rail_sdf else PackedByteArray()
	return TerrainMesher.grid_mesh(heights, mats, n, half, pal, road, rail, x0, z0, cells, step, sink, centre, SKIRT)

func _update_near(budget: int) -> void:
	var p := focus.global_position
	var cells := (n - 1) / NEAR_CHUNK
	var pc := Vector2i(floori((p.x + half) / NEAR_CHUNK), floori((p.z + half) / NEAR_CHUNK))
	var reach := ceili(NEAR_R / NEAR_CHUNK) + 1
	_want.clear()
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var c := pc + Vector2i(dx, dz)
			if c.x < 0 or c.y < 0 or c.x >= cells or c.y >= cells or near.has(c):
				continue
			if _rect_dist(c, p) < NEAR_R:
				_want.append(c)
	_want.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _rect_dist(a, p) < _rect_dist(b, p))
	for c in _want.slice(0, budget):
		near[c] = _add_block(c.x * NEAR_CHUNK, c.y * NEAR_CHUNK, NEAR_CHUNK / NEAR_STEP, NEAR_STEP, 0.0, _mat_near, 0.0)
	for c: Vector2i in near.keys():
		if _rect_dist(c, p) > NEAR_FREE:
			near[c].queue_free()
			near.erase(c)

func _rect_dist(c: Vector2i, p: Vector3) -> float:
	var x0 := c.x * NEAR_CHUNK - half
	var z0 := c.y * NEAR_CHUNK - half
	var dx := maxf(maxf(x0 - p.x, p.x - (x0 + NEAR_CHUNK)), 0.0)
	var dz := maxf(maxf(z0 - p.z, p.z - (z0 + NEAR_CHUNK)), 0.0)
	return Vector2(dx, dz).length()

func _process(delta: float) -> void:
	if focus == null:
		return
	var f := focus.global_position
	_mat_mid.set_shader_parameter("focus", f)
	_mat_far.set_shader_parameter("focus", f)
	_tick += delta
	if _tick > 0.1:
		_tick = 0.0
		_update_near(NEAR_PER_FRAME)
