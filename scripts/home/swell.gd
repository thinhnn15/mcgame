class_name Swell
extends RefCounted

const SW := [Vector4(0.94, 0.33, 7.0, 0.035), Vector4(0.55, -0.83, 4.3, 0.021), Vector4(-0.3, 0.95, 2.6, 0.011)]
const SPEED := [1.0, 0.8, 0.65]
const LIFT_K := 1.7

static func lift(x: float, z: float, depth := -1.0) -> float:
	if not WaterGrid.active:
		return 0.0
	var t := WaterGrid.time
	var y := 0.0
	for i in 3:
		var w: Vector4 = SW[i]
		var d := Vector2(w.x, w.y).normalized()
		var k := TAU / w.z
		var c := sqrt(9.8 / k) * float(SPEED[i])
		y += w.w * sin(k * (d.x * x + d.y * z - c * t))
	var shore := 1.0 if depth < 0.0 else smoothstep(0.15, 1.0, depth)
	return y * LIFT_K * shore
