class_name Wake
extends Node2D
## Foam trail, V-shaped arms and bow wave. Sits just under the ship.

const LIFE := 3.4
const SPACING := 9.0

var _pts: Array[Dictionary] = []
var _last := Vector2(1e9, 1e9)
var _ship_pos := Vector2.ZERO
var _heading := 0.0
var _speed01 := 0.0
var _waves := 0.0
var _t := 0.0


func update_wake(ship_pos: Vector2, heading: float, speed01: float, waves: float, dt: float) -> void:
	_t += dt
	_ship_pos = ship_pos
	_heading = heading
	_speed01 = speed01
	_waves = waves
	for p in _pts:
		p["age"] += dt
	while _pts.size() > 0 and _pts[0]["age"] > LIFE:
		_pts.pop_front()
	var stern := ship_pos - Vector2.from_angle(heading) * 70.0
	if speed01 > 0.04 and stern.distance_to(_last) >= SPACING:
		_pts.append({"pos": stern, "age": 0.0, "dir": heading, "pow": speed01})
		_last = stern
	queue_redraw()


func clear() -> void:
	_pts.clear()
	_last = Vector2(1e9, 1e9)


func _draw() -> void:
	var n := _pts.size()
	if n >= 2:
		# Turbulent centre trail.
		for i in range(1, n):
			var a: Dictionary = _pts[i - 1]
			var b: Dictionary = _pts[i]
			var ka: float = a["age"] / LIFE
			var kb: float = b["age"] / LIFE
			var wa: float = lerpf(16.0, 54.0, ka) * (0.5 + 0.5 * float(a["pow"]))
			var wb: float = lerpf(16.0, 54.0, kb) * (0.5 + 0.5 * float(b["pow"]))
			var pa: Vector2 = a["pos"]
			var pb: Vector2 = b["pos"]
			var na := Vector2.from_angle(a["dir"] + PI * 0.5)
			var nb := Vector2.from_angle(b["dir"] + PI * 0.5)
			var alpha_a: float = 0.5 * (1.0 - ka) * (1.0 - ka) * float(a["pow"])
			var alpha_b: float = 0.5 * (1.0 - kb) * (1.0 - kb) * float(b["pow"])
			var edge := Color(1, 1, 1, 0.0)
			var ca := Color(1, 1, 1, alpha_a)
			var cb := Color(1, 1, 1, alpha_b)
			draw_primitive(PackedVector2Array([pa + na * wa * 0.5, pb + nb * wb * 0.5, pb, pa]), PackedColorArray([edge, edge, cb, ca]), PackedVector2Array())
			draw_primitive(PackedVector2Array([pa, pb, pb - nb * wb * 0.5, pa - na * wa * 0.5]), PackedColorArray([ca, cb, edge, edge]), PackedVector2Array())
		# Diverging V arms: soft strips that widen and fade.
		for side in [-1.0, 1.0]:
			for i in range(1, n):
				var p0: Dictionary = _pts[i - 1]
				var p1: Dictionary = _pts[i]
				var k0: float = float(p0["age"]) / LIFE
				var k1: float = float(p1["age"]) / LIFE
				var n0 := Vector2.from_angle(float(p0["dir"]) + PI * 0.5)
				var n1 := Vector2.from_angle(float(p1["dir"]) + PI * 0.5)
				var s0: float = 14.0 + k0 * 110.0 * (0.6 + 0.4 * float(p0["pow"]))
				var s1: float = 14.0 + k1 * 110.0 * (0.6 + 0.4 * float(p1["pow"]))
				var w0: float = 3.0 + k0 * 9.0
				var w1: float = 3.0 + k1 * 9.0
				var a0: float = 0.5 * pow(1.0 - k0, 2.0) * float(p0["pow"])
				var a1: float = 0.5 * pow(1.0 - k1, 2.0) * float(p1["pow"])
				var c0: Vector2 = (p0["pos"] as Vector2) + n0 * s0 * side
				var c1: Vector2 = (p1["pos"] as Vector2) + n1 * s1 * side
				var t0 := Color(1, 1, 1, 0.0)
				draw_primitive(PackedVector2Array([c0 - n0 * w0, c1 - n1 * w1, c1, c0]), PackedColorArray([t0, t0, Color(1, 1, 1, a1), Color(1, 1, 1, a0)]), PackedVector2Array())
				draw_primitive(PackedVector2Array([c0, c1, c1 + n1 * w1, c0 + n0 * w0]), PackedColorArray([Color(1, 1, 1, a0), Color(1, 1, 1, a1), t0, t0]), PackedVector2Array())

	# Bow wave: two foamy flares peeling away from the stem.
	if _speed01 > 0.05:
		var fwd := Vector2.from_angle(_heading)
		var nrm2 := fwd.rotated(PI * 0.5)
		var bow := _ship_pos + fwd * 80.0
		for s in [-1.0, 1.0]:
			var pts := PackedVector2Array()
			var cols2 := PackedColorArray()
			for i in range(0, 8):
				var f := i / 7.0
				var p: Vector2 = bow - fwd * f * 78.0 + nrm2 * s * (3.0 + f * 24.0 + sin(_t * 8.0 + f * 5.0) * 1.4)
				pts.append(p)
				cols2.append(Color(1, 1, 1, (0.75 - f * 0.55) * _speed01))
			draw_polyline_colors(pts, cols2, 4.5, true)
		# Foam cap at the stem.
		draw_circle(bow, 5.0 + 4.0 * _speed01, Color(1, 1, 1, 0.5 * _speed01))
