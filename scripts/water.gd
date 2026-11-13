class_name Water
extends RefCounted

static var _bodies: Array = []

static func add(owner: Node, surface_y: float, bed: Callable, inside := Callable()) -> void:
	_bodies.append({"owner": owner, "y": surface_y, "bed": bed, "inside": inside, "surf": Callable()})

static func add_surface(owner: Node, surface_fn: Callable, bed: Callable) -> void:
	_bodies.append({"owner": owner, "y": NAN, "bed": bed, "inside": Callable(), "surf": surface_fn})

static func at(x: float, z: float) -> Vector2:
	var best := Vector2(NAN, 0.0)
	var i := 0
	while i < _bodies.size():
		var b: Dictionary = _bodies[i]
		if not is_instance_valid(b.owner) or not (b.owner as Node).is_inside_tree():
			_bodies.remove_at(i)
			continue
		i += 1
		if b.inside.is_valid() and not b.inside.call(x, z):
			continue
		var y: float = b.surf.call(x, z) if b.surf.is_valid() else b.y
		if is_nan(y):
			continue
		var d: float = y - b.bed.call(x, z)
		if d > best.y:
			best = Vector2(y, d)
	return best

static func mask_test(img: Image, cell: float, half: float) -> Callable:
	var data := img.get_data()
	var n := img.get_width()
	var m := img.get_height()
	return func(x: float, z: float) -> bool:
		var cx := int(floor((x + half) / cell))
		var cz := int(floor((z + half) / cell))
		return cx >= 0 and cz >= 0 and cx < n and cz < m and data[cz * n + cx] > 0
