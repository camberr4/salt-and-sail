class_name Ambient
extends Node2D
## Life on the sea: gull flocks circling land, dolphin pods racing the ship.
## Pure decoration, cheap, drawn in one pass.

var gen: WorldGen
var fx: Fx
var ship_pos := Vector2.ZERO
var calm := 1.0      # 0 in storms, 1 in fair weather
var night := 0.0

var _gulls: Array[Dictionary] = []
var _pods: Array[Dictionary] = []
var _spawn_gull := 2.0
var _spawn_pod := 18.0
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	z_index = 6


func clear() -> void:
	_gulls.clear()
	_pods.clear()


func update(dt: float, p_ship_pos: Vector2, ship_dir: Vector2) -> void:
	_t += dt
	ship_pos = p_ship_pos
	if gen == null:
		return
	_spawn_gull -= dt
	if _spawn_gull <= 0.0:
		_spawn_gull = _rng.randf_range(2.5, 6.0)
		if _gulls.size() < 12 and calm > 0.5 and night < 0.5:
			_try_spawn_gulls()
	_spawn_pod -= dt
	if _spawn_pod <= 0.0:
		_spawn_pod = _rng.randf_range(28.0, 55.0)
		if _pods.size() < 2 and calm > 0.5:
			_try_spawn_pod(ship_dir)
	_update_gulls(dt)
	_update_pods(dt)
	queue_redraw()


# ------------------------------------------------------------------ gulls

func _try_spawn_gulls() -> void:
	for attempt in 8:
		var p := ship_pos + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(500.0, 1100.0)
		if gen.in_bounds(p, 200.0) and gen.height_at(p) > WorldGen.SEA + 0.04:
			var count := _rng.randi_range(3, 5)
			var spin := 1.0 if _rng.randf() < 0.5 else -1.0
			var radius := _rng.randf_range(90.0, 190.0)
			for i in count:
				_gulls.append({
					"c": p,
					"a": _rng.randf() * TAU,
					"r": radius * _rng.randf_range(0.8, 1.2),
					"sp": spin * _rng.randf_range(0.5, 0.8),
					"ph": _rng.randf() * 10.0,
					"life": _rng.randf_range(22.0, 40.0),
					"pos": p,
					"dir": 0.0,
				})
			return


func _update_gulls(dt: float) -> void:
	var i := 0
	while i < _gulls.size():
		var g := _gulls[i]
		g["life"] -= dt
		g["a"] += g["sp"] * dt
		var r: float = g["r"] * (1.0 + 0.22 * sin(g["ph"] + _t * 0.35))
		var np: Vector2 = (g["c"] as Vector2) + Vector2.from_angle(g["a"]) * r
		g["dir"] = ((np - (g["pos"] as Vector2)).angle()) if np != g["pos"] else g["dir"]
		g["pos"] = np
		if g["life"] <= 0.0 or ship_pos.distance_to(g["c"]) > 2600.0:
			_gulls.remove_at(i)
		else:
			i += 1


# ----------------------------------------------------------------- dolphins

func _try_spawn_pod(ship_dir: Vector2) -> void:
	for attempt in 8:
		var side := 1.0 if _rng.randf() < 0.5 else -1.0
		var off := ship_dir * _rng.randf_range(250.0, 500.0) + ship_dir.rotated(PI * 0.5) * side * _rng.randf_range(380.0, 560.0)
		var p := ship_pos + off
		if not gen.in_bounds(p, 400.0) or gen.height_at(p) > WorldGen.SEA - 0.1:
			continue
		var dir := (ship_pos + ship_dir * 200.0 - p).normalized().rotated(_rng.randf_range(-0.5, 0.5))
		var pod := {"dolphins": [], "life": 10.0}
		for i in _rng.randi_range(2, 3):
			pod["dolphins"].append({
				"pos": p + dir.rotated(PI * 0.5) * (i * 42.0 - 40.0) - dir * i * 30.0,
				"dir": dir,
				"ph": _rng.randf() * 0.5,
				"sp": _rng.randf_range(175.0, 215.0),
				"in_air": false,
			})
		_pods.append(pod)
		return


func _update_pods(dt: float) -> void:
	var i := 0
	while i < _pods.size():
		var pod := _pods[i]
		pod["life"] -= dt
		for d in pod["dolphins"]:
			d["pos"] += (d["dir"] as Vector2) * d["sp"] * dt
			d["ph"] += dt / 1.7
			var ph := fmod(d["ph"], 1.0)
			var air := ph < 0.5
			if air != d["in_air"]:
				d["in_air"] = air
				if fx != null:
					fx.splash(d["pos"], 0.55)
		if pod["life"] <= 0.0:
			_pods.remove_at(i)
		else:
			i += 1


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	for pod in _pods:
		for d in pod["dolphins"]:
			_draw_dolphin(d, clampf(pod["life"] * 0.5, 0.0, 1.0))
	for g in _gulls:
		_draw_gull(g)


func _draw_dolphin(d: Dictionary, fade: float) -> void:
	var ph := fmod(d["ph"], 1.0)
	var h := sin(ph / 0.5 * PI) if ph < 0.5 else 0.0
	var dir: Vector2 = d["dir"]
	var pos: Vector2 = d["pos"]
	var n := dir.rotated(PI * 0.5)
	var scale_f := 1.0 + 0.4 * h
	var length := 54.0 * scale_f
	var width := 15.0 * scale_f
	var alpha := (1.0 if h > 0.0 else 0.28) * fade
	if h > 0.0:
		var sh := pos + Vector2(10, 18) * h
		_dolphin_shape(sh, dir, length, width, Color(0, 0.1, 0.18, 0.25 * fade))
	var lift := Vector2(0, -22.0 * h)
	_dolphin_shape(pos + lift, dir, length, width, Color(0.34 if h > 0 else 0.1, 0.5 if h > 0 else 0.3, 0.64 if h > 0 else 0.5, alpha))
	if h > 0.0:
		_dolphin_shape(pos + lift + n * -1.5, dir, length * 0.9, width * 0.45, Color(0.88, 0.94, 0.97, 0.9 * fade))


func _dolphin_shape(c: Vector2, dir: Vector2, length: float, width: float, col: Color) -> void:
	var n := dir.rotated(PI * 0.5)
	var pts := PackedVector2Array()
	var segs := 9
	for i in range(segs + 1):
		var u := lerpf(-0.5, 0.5, float(i) / segs)
		var w := width * pow(maxf(1.0 - pow(absf(u * 2.0), 2.2), 0.0), 0.7) * (1.0 if u > -0.2 else 0.6)
		pts.append(c + dir * u * length + n * w * 0.5)
	for i in range(segs, -1, -1):
		var u := lerpf(-0.5, 0.5, float(i) / segs)
		var w := width * pow(maxf(1.0 - pow(absf(u * 2.0), 2.2), 0.0), 0.7) * (1.0 if u > -0.2 else 0.6)
		pts.append(c + dir * u * length - n * w * 0.5)
	if pts.size() >= 3:
		SafeDraw.poly(self, pts, col)
	# Tail flukes and dorsal fin.
	var tail := c - dir * length * 0.5
	SafeDraw.poly(self, PackedVector2Array([tail, tail - dir * 8.0 + n * 9.0, tail - dir * 4.0, tail - dir * 8.0 - n * 9.0]), col)
	SafeDraw.poly(self, PackedVector2Array([c - dir * 2.0 + n * width * 0.15, c - dir * 11.0, c + dir * 5.0]), col)


func _draw_gull(g: Dictionary) -> void:
	var pos: Vector2 = g["pos"]
	var dir := Vector2.from_angle(g["dir"])
	var n := dir.rotated(PI * 0.5)
	var flap := sin(_t * 8.0 + g["ph"])
	var glide := sin(_t * 0.7 + g["ph"]) > 0.55
	var wing := 0.0 if glide else flap * 0.55
	# Shadow on the water.
	var sp := pos + Vector2(16, 26)
	SafeDraw.poly(self, PackedVector2Array([sp + dir * 9.0, sp + n * 15.0, sp - dir * 6.0, sp - n * 15.0]), Color(0, 0.08, 0.14, 0.14))
	var body := PackedVector2Array([pos + dir * 8.0, pos + n * 3.0, pos - dir * 8.0, pos - n * 3.0])
	for s in [-1.0, 1.0]:
		var tip: Vector2 = pos + n * float(s) * (17.0 - absf(wing) * 5.0) - dir * (6.0 + wing * 5.0)
		SafeDraw.poly(self, PackedVector2Array([pos + dir * 3.0, tip + dir * 2.0, tip - dir * 4.0, pos - dir * 4.0]), Color(0.97, 0.97, 0.98))
		draw_line(tip + dir * 1.0, tip - dir * 4.0, Color(0.25, 0.27, 0.32), 2.0)
	SafeDraw.poly(self, body, Color(1, 1, 1))
	draw_circle(pos + dir * 8.0, 2.0, Color(0.95, 0.75, 0.2))
