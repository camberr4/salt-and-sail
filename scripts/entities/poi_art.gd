class_name PoiArt
extends RefCounted
## Everything a point of interest looks like, drawn in code. `build` makes a
## one-off layout from the POI's seed; `draw` renders a frame of it.

const ROOFS := [Color("b8472f"), Color("a85a32"), Color("c9a24a"), Color("5d7a8c"), Color("8a3b2b")]
const WALLS := [Color("efe3c4"), Color("e4d3ac"), Color("f3ead2")]


static func build(p: Poi, rng: RandomNumberGenerator) -> Dictionary:
	var l := {}
	match p.kind:
		"village":
			var home: bool = p.data.get("home", false)
			var houses := []
			var cols := [-66.0, -30.0, 2.0] if not home else [-86.0, -48.0, -10.0, 26.0]
			var rows := [-54.0, -18.0, 18.0, 54.0] if not home else [-72.0, -36.0, 0.0, 36.0, 72.0]
			for cx in cols:
				for ry in rows:
					if rng.randf() < (0.62 if not home else 0.7):
						houses.append({
							"pos": Vector2(cx + rng.randf_range(-5, 5), ry + rng.randf_range(-4, 4)),
							"size": Vector2(rng.randf_range(24, 34), rng.randf_range(20, 28)),
							"roof": ROOFS[rng.randi() % ROOFS.size()],
							"wall": WALLS[rng.randi() % WALLS.size()],
							"smoke": rng.randf() < 0.45,
							"phase": rng.randf(),
						})
			l["houses"] = houses
			var trees := []
			for i in 7:
				trees.append(Vector2(rng.randf_range(-118, -74), rng.randf_range(-76, 76)))
			l["trees"] = trees
			l["roof_flag"] = ROOFS[rng.randi() % ROOFS.size()]
		"lighthouse":
			var rocks := []
			for i in 9:
				var a := rng.randf() * TAU
				rocks.append({"pos": Vector2.from_angle(a) * rng.randf_range(28, 48), "r": rng.randf_range(6, 13)})
			l["rocks"] = rocks
		"treasure":
			var palms := []
			for i in 4:
				palms.append({
					"pos": Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(10, 36),
					"rot": rng.randf() * TAU,
					"phase": rng.randf() * 6.0,
					"size": rng.randf_range(0.85, 1.15),
				})
			l["palms"] = palms
			l["x"] = Vector2(rng.randf_range(-10, 10), rng.randf_range(-6, 14))
		"skull":
			var bumps := []
			for i in 28:
				bumps.append(rng.randf_range(0.9, 1.1))
			l["bumps"] = bumps
			l["rot"] = rng.randf_range(-0.4, 0.4)
		"wreck":
			l["ang"] = rng.randf() * TAU
			var debris := []
			for i in 6:
				debris.append({
					"pos": Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(60, 110),
					"rot": rng.randf() * TAU,
					"len": rng.randf_range(10, 22),
					"phase": rng.randf() * 6.0,
				})
			l["debris"] = debris
		"wisps":
			var orbs := []
			for i in 5:
				orbs.append({"r": rng.randf_range(35, 100), "sp": rng.randf_range(0.4, 0.9) * (1 if rng.randf() < 0.5 else -1), "ph": rng.randf() * TAU, "ry": rng.randf_range(0.5, 1.0)})
			l["orbs"] = orbs
	return l


const SPRITE_FILE := {"village": "village", "lighthouse": "lighthouse", "treasure": "treasure", "skull": "skull_rock", "wreck": "wreck", "whirlpool": "whirlpool", "bottle": "bottle", "wisps": "wisps"}
const SPRITE_SIZE := {"village": 560.0, "lighthouse": 420.0, "treasure": 460.0, "skull": 360.0, "wreck": 400.0, "whirlpool": 700.0, "bottle": 110.0, "wisps": 320.0}


## Painted sprite from assets/art/poi, if supplied. Returns true when drawn.
static func _draw_sprite(p: Poi, sc: float) -> bool:
	var tex := Art.tex("poi/" + SPRITE_FILE.get(p.kind, p.kind))
	if tex == null:
		return false
	var s: float = SPRITE_SIZE.get(p.kind, 400.0)
	var rot := 0.0
	var a := 1.0
	match p.kind:
		"village":
			rot = p.normal_angle - PI * 0.5  # the pier points down in the painting
		"whirlpool":
			rot = p.t * 0.7
		"wisps":
			a = clampf(p.night * 1.4 - 0.2, 0.0, 1.0)
		"bottle":
			rot = 0.5 + sin(p.t * 1.1) * 0.2
			p.draw_set_transform(Vector2(0, sin(p.t * 1.7) * 3.0), rot, Vector2(sc, sc))
			p.draw_texture_rect(tex, Rect2(-s * 0.5, -s * 0.5, s, s), false)
			p.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return true
	if a <= 0.01:
		return true
	p.draw_set_transform(Vector2.ZERO, rot, Vector2(sc, sc))
	var home: bool = p.data.get("home", false)
	var k := 1.2 if home else 1.0
	p.draw_texture_rect(tex, Rect2(-s * 0.5 * k, -s * 0.5 * k, s * k, s * k), false, Color(1, 1, 1, a))
	p.draw_set_transform(Vector2.ZERO, 0.0, Vector2(sc, sc))
	if p.kind == "lighthouse":
		_glow(p, Vector2.ZERO, 70.0, Color(1.0, 0.9, 0.55, 0.9), 0.15 + 0.45 * p.night)
	elif p.kind == "village" and p.night > 0.05:
		_glow(p, Vector2.ZERO, 120.0, Color(1.0, 0.75, 0.4, 0.8), p.night * 0.6)
	p.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true


static func draw(p: Poi, sc: float) -> void:
	if _draw_sprite(p, sc):
		_discovery_ring(p)
		return
	p.draw_set_transform(Vector2.ZERO, 0.0, Vector2(sc, sc))
	match p.kind:
		"village":
			_village(p, sc)
		"lighthouse":
			_lighthouse(p)
		"treasure":
			_treasure(p)
		"skull":
			_skull(p)
		"wreck":
			_wreck(p)
		"whirlpool":
			_whirlpool(p)
		"bottle":
			_bottle(p)
		"wisps":
			_wisps(p)
	p.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_discovery_ring(p)


static func _discovery_ring(p: Poi) -> void:
	if p.appear < 1.0:
		var k := p.appear
		p.draw_arc(Vector2.ZERO, 30.0 + k * 170.0, 0.0, TAU, 48, Color(1, 0.95, 0.7, (1.0 - k) * 0.7), 3.0 * (1.0 - k) + 1.0, true)


static func _glow(p: Poi, pos: Vector2, r: float, col: Color, strength: float) -> void:
	if strength <= 0.01:
		return
	for i in 3:
		var k := 1.0 - i / 3.0
		p.draw_circle(pos, r * (0.45 + 0.55 * k), Color(col, col.a * strength * (0.12 + 0.2 * (1.0 - k))))


static func _blob(p: Poi, c: Vector2, r: float, col: Color, seed_off: float = 0.0, n: int = 14) -> void:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2.from_angle(a) * r * (0.82 + 0.28 * sin(a * 3.0 + seed_off) * cos(a * 2.0 + seed_off * 1.7)))
	SafeDraw.poly(p, pts, col)


# ------------------------------------------------------------------ village

static func _village(p: Poi, sc: float) -> void:
	var home: bool = p.data.get("home", false)
	var k := 1.2 if home else 1.0
	p.draw_set_transform(Vector2.ZERO, p.normal_angle, Vector2(sc * k, sc * k))
	var t := p.t
	var night := p.night
	# Cleared ground.
	p.draw_circle(Vector2(-34, 0), 84.0, Color(0.55, 0.42, 0.26, 0.5))
	p.draw_circle(Vector2(-34, 0), 70.0, Color(0.68, 0.55, 0.36, 0.55))
	p.draw_rect(Rect2(-20, -6, 70, 12), Color(0.76, 0.64, 0.45, 0.9))
	# Trees behind the houses.
	for tp in p.layout["trees"]:
		p.draw_circle(tp + Vector2(4, 5), 12.0, Color(0, 0.08, 0.04, 0.3))
		_blob(p, tp, 12.0, Color(0.1, 0.36, 0.18), tp.x)
		_blob(p, tp + Vector2(-2, -3), 8.0, Color(0.2, 0.5, 0.25), tp.y)
	# Houses.
	for h in p.layout["houses"]:
		var pos: Vector2 = h["pos"]
		var sz: Vector2 = h["size"]
		p.draw_rect(Rect2(pos - sz * 0.5 + Vector2(5, 6), sz), Color(0, 0.05, 0.08, 0.3))
		p.draw_rect(Rect2(pos - sz * 0.5 - Vector2(1.5, 1.5), sz + Vector2(3, 3)), Color(0.22, 0.14, 0.08))
		p.draw_rect(Rect2(pos - sz * 0.5, sz), h["wall"])
		var roof: Color = h["roof"]
		var half := Rect2(pos - sz * 0.5, Vector2(sz.x, sz.y * 0.5))
		p.draw_rect(half, roof.lightened(0.14))
		p.draw_rect(Rect2(pos - Vector2(sz.x * 0.5, 0), Vector2(sz.x, sz.y * 0.5)), roof.darkened(0.16))
		p.draw_line(pos - Vector2(sz.x * 0.5, 0), pos + Vector2(sz.x * 0.5, 0), roof.darkened(0.4), 1.5)
		for s in range(1, 4):
			var x := pos.x - sz.x * 0.5 + s * sz.x / 4.0
			p.draw_line(Vector2(x, pos.y - sz.y * 0.5), Vector2(x, pos.y + sz.y * 0.5), Color(0, 0, 0, 0.12), 1.0)
		# Lit window at night.
		if night > 0.05:
			_glow(p, pos + Vector2(sz.x * 0.35, 0), 22.0, Color(1.0, 0.75, 0.35, 0.8), night)
		if h["smoke"]:
			for i in 4:
				var ph := fmod(t * 0.35 + h["phase"] + i * 0.25, 1.0)
				var sp := pos + Vector2(sz.x * 0.25, -sz.y * 0.2) + Vector2(-ph * 22.0, -ph * 26.0) + Vector2(p.wind.x, p.wind.y) * ph * 24.0
				p.draw_circle(sp, 3.0 + ph * 9.0, Color(0.92, 0.92, 0.95, 0.34 * (1.0 - ph)))
	# Dock.
	var dock_col := Color(0.24, 0.14, 0.08)
	p.draw_rect(Rect2(32, -10, 82, 20).grow(2.0), Color(0, 0.08, 0.14, 0.3))
	p.draw_rect(Rect2(32, -10, 82, 20), dock_col)
	for i in range(0, 14):
		var x := 34.0 + i * 5.7
		p.draw_line(Vector2(x, -10), Vector2(x, 10), Color(0.62, 0.43, 0.24).darkened(0.1 * (i % 3)), 4.2)
	p.draw_rect(Rect2(102, -17, 20, 34), dock_col)
	for i in range(0, 5):
		p.draw_line(Vector2(103 + i * 4.2, -17), Vector2(103 + i * 4.2, 17), Color(0.66, 0.46, 0.26), 3.4)
	for i in range(0, 5):
		var x := 38.0 + i * 18.0
		p.draw_circle(Vector2(x, -11), 2.4, Color(0.15, 0.08, 0.04))
		p.draw_circle(Vector2(x, 11), 2.4, Color(0.15, 0.08, 0.04))
	# Moored rowboat, bobbing gently.
	var bob := sin(t * 1.6) * 1.8
	var bp := Vector2(82, 25 + bob)
	p.draw_set_transform(Vector2.ZERO, p.normal_angle, Vector2(sc * k, sc * k))
	var boat := PackedVector2Array()
	for i in 13:
		var a := TAU * i / 13.0
		boat.append(bp + Vector2(cos(a) * 16.0, sin(a) * 6.5) * (1.0 + 0.0 * a))
	SafeDraw.poly(p, boat, Color(0.2, 0.1, 0.05))
	var boat_in := PackedVector2Array()
	for i in 13:
		var a2 := TAU * i / 13.0
		boat_in.append(bp + Vector2(cos(a2) * 13.5, sin(a2) * 4.4))
	SafeDraw.poly(p, boat_in, Color(0.58, 0.38, 0.2))
	p.draw_line(bp + Vector2(-8, 0), bp + Vector2(8, 0), Color(0.35, 0.2, 0.1), 1.6)
	p.draw_line(Vector2(84, 14), bp + Vector2(4, -5), Color(0.8, 0.7, 0.5, 0.8), 1.0)
	# Crates and barrels.
	p.draw_rect(Rect2(104, -14, 9, 9), Color(0.45, 0.3, 0.16))
	p.draw_rect(Rect2(104, -14, 9, 9), Color(0.2, 0.12, 0.06), false, 1.2)
	p.draw_circle(Vector2(109, 8), 5.0, Color(0.2, 0.1, 0.05))
	p.draw_circle(Vector2(109, 8), 3.8, Color(0.5, 0.31, 0.15))
	# Flag at the end of the pier.
	var pole := Vector2(116, 0)
	p.draw_line(pole, pole + Vector2(0, -22), Color(0.2, 0.12, 0.06), 2.2)
	var fl := PackedVector2Array()
	for i in range(0, 8):
		var s := i / 7.0
		fl.append(pole + Vector2(0, -22) + Vector2(s * 20.0, sin(s * 6.0 - t * 7.0) * 3.0 * s))
	for i in range(7, -1, -1):
		var s2 := i / 7.0
		fl.append(pole + Vector2(0, -22) + Vector2(s2 * 20.0, 8.0 * (1.0 - s2 * 0.3) + sin(s2 * 6.0 - t * 7.0) * 3.0 * s2))
	SafeDraw.poly(p, fl, p.layout["roof_flag"])
	# Lanterns.
	for lp in [Vector2(38, -11), Vector2(110, 15), Vector2(-4, 22)]:
		p.draw_circle(lp, 2.6, Color(1.0, 0.8, 0.4))
		_glow(p, lp, 34.0, Color(1.0, 0.78, 0.4, 0.9), 0.25 + 0.75 * night)
	if home:
		# A bigger harbour hall with a banner.
		p.draw_rect(Rect2(-18, 38, 46, 30), Color(0.22, 0.14, 0.08))
		p.draw_rect(Rect2(-16, 40, 42, 26), Color("c9a24a"))
		p.draw_rect(Rect2(-16, 40, 42, 13), Color("dbb85e"))
		p.draw_line(Vector2(-16, 53), Vector2(26, 53), Color(0.3, 0.2, 0.1), 1.5)


# --------------------------------------------------------------- lighthouse

static func _lighthouse(p: Poi) -> void:
	var t := p.t
	var night := p.night
	for rk in p.layout["rocks"]:
		var rp: Vector2 = rk["pos"]
		_blob(p, rp + Vector2(3, 4), rk["r"], Color(0, 0.05, 0.1, 0.3))
		_blob(p, rp, rk["r"], Color(0.42, 0.41, 0.42))
		_blob(p, rp + Vector2(-1.5, -2), rk["r"] * 0.7, Color(0.58, 0.57, 0.56))
	# Long shadow of the tower.
	var sa := 0.75
	var sd := Vector2.from_angle(sa)
	var sn := sd.rotated(PI * 0.5)
	SafeDraw.poly(p, PackedVector2Array([sn * 11.0, sd * 118.0 + sn * 5.0, sd * 118.0 - sn * 5.0, -sn * 11.0]), Color(0, 0.04, 0.08, 0.28))
	# Beams, rotating slowly.
	var ang := t * 0.85
	for s in [0.0, PI]:
		var a: float = ang + float(s)
		var pts := PackedVector2Array([Vector2.ZERO, Vector2.from_angle(a - 0.07) * 360.0, Vector2.from_angle(a + 0.07) * 360.0])
		var cols := PackedColorArray([Color(1, 0.95, 0.7, 0.3 + 0.35 * night), Color(1, 0.95, 0.7, 0.0), Color(1, 0.95, 0.7, 0.0)])
		p.draw_primitive(pts, cols, PackedVector2Array())
	# Tower seen from above: base, gallery, lantern room and roof.
	p.draw_circle(Vector2.ZERO, 25.0, Color(0.3, 0.28, 0.28))
	p.draw_circle(Vector2.ZERO, 23.0, Color(0.88, 0.86, 0.82))
	for i in 12:
		var a2 := TAU * i / 12.0
		p.draw_circle(Vector2.from_angle(a2) * 21.0, 1.7, Color(0.25, 0.22, 0.22))
	p.draw_arc(Vector2.ZERO, 21.0, 0.0, TAU, 40, Color(0.3, 0.27, 0.27), 1.6, true)
	p.draw_circle(Vector2.ZERO, 15.5, Color(0.72, 0.18, 0.14))
	p.draw_circle(Vector2.ZERO, 13.5, Color(0.96, 0.93, 0.86))
	p.draw_circle(Vector2.ZERO, 9.5, Color(0.72, 0.18, 0.14))
	_glow(p, Vector2.ZERO, 70.0, Color(1.0, 0.9, 0.55, 0.9), 0.15 + 0.3 * night)
	for i in 6:
		var a3 := TAU * i / 6.0
		p.draw_line(Vector2.ZERO, Vector2.from_angle(a3) * 9.5, Color(0.5, 0.1, 0.08), 1.2)
	p.draw_circle(Vector2.ZERO, 3.8, Color(1.0, 0.93, 0.6))
	var hl := Vector2.from_angle(ang) * 6.0
	p.draw_circle(hl, 2.2, Color(1, 1, 1, 0.95))


# ----------------------------------------------------------------- treasure

static func _palm(p: Poi, pos: Vector2, rot: float, phase: float, size: float) -> void:
	var t := p.t
	p.draw_circle(pos + Vector2(6, 8), 15.0 * size, Color(0, 0.06, 0.04, 0.25))
	for i in 8:
		var a := rot + TAU * i / 8.0 + sin(t * 1.3 + phase + i) * 0.05 + p.wind.x * 0.05
		var d := Vector2.from_angle(a)
		var n := d.rotated(PI * 0.5)
		var len := 24.0 * size * (0.9 + 0.1 * sin(t * 1.7 + phase + i * 1.3))
		var pts := PackedVector2Array([pos, pos + d * len * 0.5 + n * 5.0 * size, pos + d * len, pos + d * len * 0.5 - n * 4.0 * size])
		var shade := 0.9 + 0.2 * float(i % 2)
		SafeDraw.poly(p, pts, Color(0.16 * shade, 0.5 * shade, 0.22 * shade))
		p.draw_line(pos, pos + d * len, Color(0.1, 0.34, 0.14, 0.8), 1.0)
	p.draw_circle(pos, 3.6 * size, Color(0.36, 0.22, 0.1))
	p.draw_circle(pos + Vector2(2, 1), 1.6, Color(0.25, 0.15, 0.06))


static func _treasure(p: Poi) -> void:
	var t := p.t
	var xp: Vector2 = p.layout["x"]
	if not p.visited:
		# Red X on the sand, pulsing softly.
		var pulse := 0.85 + 0.15 * sin(t * 3.0)
		var s := 11.0 * pulse
		for off in [Vector2(1.5, 2.0), Vector2.ZERO]:
			var col := Color(0.2, 0.05, 0.03, 0.4) if off != Vector2.ZERO else Color(0.82, 0.1, 0.08)
			p.draw_line(xp + off + Vector2(-s, -s), xp + off + Vector2(s, s), col, 5.0)
			p.draw_line(xp + off + Vector2(-s, s), xp + off + Vector2(s, -s), col, 5.0)
		for i in 3:
			var ph := fmod(t * 0.7 + i * 0.33, 1.0)
			var sp := xp + Vector2.from_angle(i * 2.1 + t * 0.3) * 18.0
			var r := 6.0 * sin(ph * PI)
			p.draw_line(sp + Vector2(-r, 0), sp + Vector2(r, 0), Color(1, 0.92, 0.55, 0.9), 2.0)
			p.draw_line(sp + Vector2(0, -r), sp + Vector2(0, r), Color(1, 0.92, 0.55, 0.9), 2.0)
	else:
		# Dug hole and open chest.
		p.draw_circle(xp, 13.0, Color(0.35, 0.24, 0.14))
		p.draw_circle(xp, 10.0, Color(0.2, 0.12, 0.07))
		p.draw_rect(Rect2(xp - Vector2(8, 5), Vector2(16, 10)), Color(0.5, 0.3, 0.12))
		p.draw_rect(Rect2(xp - Vector2(8, 5), Vector2(16, 4)), Color(0.95, 0.75, 0.2))
	for pl in p.layout["palms"]:
		_palm(p, pl["pos"], pl["rot"], pl["phase"], pl["size"])


# -------------------------------------------------------------------- skull

static func _skull(p: Poi) -> void:
	var t := p.t
	var night := p.night
	p.draw_set_transform(Vector2.ZERO, p.layout["rot"], Vector2.ONE * clampf(p.appear * 3.0, 0.0, 1.0))
	var rock := Color(0.5, 0.5, 0.54)
	var dark := Color(0.2, 0.2, 0.24)
	# Surf ring.
	for i in 2:
		var ph := fmod(t * 0.4 + i * 0.5, 1.0)
		p.draw_arc(Vector2(0, 6), 72.0 + ph * 26.0, 0.0, TAU, 48, Color(1, 1, 1, 0.35 * (1.0 - ph)), 3.0, true)
	# Cranium.
	var pts := PackedVector2Array()
	var bumps: Array = p.layout["bumps"]
	for i in bumps.size():
		var a := TAU * i / bumps.size()
		pts.append(Vector2(cos(a) * 54.0, sin(a) * 46.0 - 10.0) * float(bumps[i]))
	SafeDraw.poly(p, PackedVector2Array(Array(pts).map(func(v): return v + Vector2(6, 8))), Color(0, 0.04, 0.08, 0.3))
	SafeDraw.poly(p, pts, dark)
	var inner := PackedVector2Array()
	for v in pts:
		inner.append(v * 0.92 + Vector2(-1.5, -2))
	SafeDraw.poly(p, inner, rock)
	var hi := PackedVector2Array()
	for v in pts:
		hi.append(v * 0.62 + Vector2(-8, -12))
	SafeDraw.poly(p, hi, rock.lightened(0.12))
	# Jaw and teeth.
	p.draw_rect(Rect2(-32, 28, 64, 22), dark)
	p.draw_rect(Rect2(-30, 28, 60, 19), rock.darkened(0.08))
	for i in 7:
		var x := -27.0 + i * 9.0
		p.draw_rect(Rect2(x, 35, 6, 14), Color(0.9, 0.88, 0.8))
		p.draw_rect(Rect2(x, 35, 6, 14), dark, false, 1.0)
	# Eyes and nose.
	for s in [-1.0, 1.0]:
		var ec := Vector2(s * 20.0, -8.0)
		p.draw_circle(ec, 13.5, dark)
		p.draw_circle(ec, 11.5, Color(0.04, 0.05, 0.08))
		if night > 0.05:
			var gl := 0.6 + 0.4 * sin(t * 2.2 + s)
			_glow(p, ec, 46.0, Color(0.4, 1.0, 0.6, 0.9), night * gl)
			p.draw_circle(ec, 5.0, Color(0.55, 1.0, 0.7, 0.8 * night * gl))
	SafeDraw.poly(p, PackedVector2Array([Vector2(0, 8), Vector2(-6, 22), Vector2(6, 22)]), Color(0.05, 0.06, 0.09))
	# Cracks.
	p.draw_polyline(PackedVector2Array([Vector2(-10, -50), Vector2(-4, -38), Vector2(-12, -30), Vector2(-6, -20)]), dark, 1.6, true)


# -------------------------------------------------------------------- wreck

static func _wreck(p: Poi) -> void:
	var t := p.t
	var ang: float = p.layout["ang"]
	# Shimmering shallows around the hull.
	for i in 3:
		var ph := fmod(t * 0.3 + i / 3.0, 1.0)
		p.draw_arc(Vector2.ZERO, 62.0 + ph * 40.0, 0.0, TAU, 40, Color(0.7, 1.0, 0.95, 0.25 * (1.0 - ph)), 2.5, true)
	p.draw_set_transform(Vector2.ZERO, ang + sin(t * 0.6) * 0.015, Vector2.ONE * clampf(p.appear * 3.0, 0.0, 1.0))
	var hl := 70.0
	var hb := 24.0
	var hull := PackedVector2Array()
	# Stern intact, bow shattered into jagged planks.
	for i in range(0, 13):
		var u := lerpf(-1.0, 0.45, i / 12.0)
		hull.append(Vector2(u * hl, -hb * (0.5 + 0.5 * sqrt(maxf(1.0 - u * u, 0.0)))))
	hull.append(Vector2(0.55 * hl, -hb * 0.3))
	hull.append(Vector2(0.4 * hl, -hb * 0.05))
	hull.append(Vector2(0.62 * hl, hb * 0.2))
	hull.append(Vector2(0.45 * hl, hb * 0.55))
	for i in range(12, -1, -1):
		var u2 := lerpf(-1.0, 0.45, i / 12.0)
		hull.append(Vector2(u2 * hl, hb * (0.5 + 0.5 * sqrt(maxf(1.0 - u2 * u2, 0.0)))))
	SafeDraw.poly(p, PackedVector2Array(Array(hull).map(func(v): return v * 1.08 + Vector2(6, 8))), Color(0, 0.08, 0.14, 0.3))
	SafeDraw.poly(p, hull, Color(0.16, 0.1, 0.07))
	var inner := PackedVector2Array(Array(hull).map(func(v): return v * 0.88))
	SafeDraw.poly(p, inner, Color(0.32, 0.22, 0.14))
	# Ribs.
	for i in range(0, 9):
		var x := lerpf(-hl * 0.85, hl * 0.35, i / 8.0)
		var w := hb * (0.5 + 0.5 * sqrt(maxf(1.0 - (x / hl) * (x / hl), 0.0))) * 0.86
		p.draw_line(Vector2(x, -w), Vector2(x, w), Color(0.1, 0.06, 0.04), 2.4)
	# Seaweed and algae tint, then the waterline wash.
	SafeDraw.poly(p, inner, Color(0.2, 0.5, 0.45, 0.28))
	# Snapped mast and torn sail.
	p.draw_line(Vector2(-6, 0), Vector2(60, -34), Color(0.2, 0.12, 0.06), 5.0)
	p.draw_line(Vector2(-6, 0), Vector2(60, -34), Color(0.5, 0.34, 0.18), 2.0)
	var rag := PackedVector2Array([Vector2(20, -14), Vector2(48, -30), Vector2(40, -8), Vector2(26, 0)])
	SafeDraw.poly(p, rag, Color(0.85, 0.8, 0.68, 0.85))
	p.draw_circle(Vector2(-6, 0), 4.5, Color(0.17, 0.09, 0.04))
	# Foam where water laps the timbers.
	p.draw_polyline(PackedVector2Array(Array(hull).map(func(v): return v * 1.04)), Color(1, 1, 1, 0.4 + 0.2 * sin(t * 1.8)), 2.0, true)
	p.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * clampf(p.appear * 3.0, 0.0, 1.0))
	for d in p.layout["debris"]:
		var dp: Vector2 = d["pos"] + Vector2(sin(t * 0.9 + d["phase"]) * 3.0, cos(t * 0.7 + d["phase"]) * 3.0)
		var dr: float = d["rot"] + sin(t * 0.8 + d["phase"]) * 0.2
		var dd: Vector2 = Vector2.from_angle(dr) * float(d["len"]) * 0.5
		p.draw_line(dp - dd + Vector2(2, 3), dp + dd + Vector2(2, 3), Color(0, 0.07, 0.12, 0.3), 5.0)
		p.draw_line(dp - dd, dp + dd, Color(0.4, 0.27, 0.15), 4.0)
		p.draw_line(dp - dd, dp + dd, Color(0.55, 0.38, 0.2), 1.6)
	# A glint of something valuable.
	var gp := fmod(t * 0.45, 1.0)
	var gs := 8.0 * sin(gp * PI)
	var gc := Vector2(-30, 6)
	p.draw_line(gc + Vector2(-gs, 0), gc + Vector2(gs, 0), Color(1, 0.9, 0.5, 0.9), 2.0)
	p.draw_line(gc + Vector2(0, -gs), gc + Vector2(0, gs), Color(1, 0.9, 0.5, 0.9), 2.0)


# ---------------------------------------------------------------- whirlpool

static func _whirlpool(p: Poi) -> void:
	var t := p.t
	var arms := 5
	# Outer pull zone, barely visible.
	p.draw_arc(Vector2.ZERO, 300.0, 0.0, TAU, 72, Color(1, 1, 1, 0.06), 2.0, true)
	p.draw_circle(Vector2.ZERO, 210.0, Color(0.01, 0.06, 0.18, 0.22))
	p.draw_circle(Vector2.ZERO, 140.0, Color(0.01, 0.05, 0.16, 0.28))
	for arm in arms:
		var base := TAU * arm / arms - t * 0.85
		var pts := PackedVector2Array()
		var dark_cols := PackedColorArray()
		var foam_cols := PackedColorArray()
		for i in range(0, 26):
			var r := lerpf(210.0, 22.0, i / 25.0)
			var a := base + (210.0 - r) * 0.0125 * 1.0 + pow((210.0 - r) / 190.0, 1.3) * 2.6
			pts.append(Vector2.from_angle(a) * r)
			var f := i / 25.0
			dark_cols.append(Color(0.0, 0.03, 0.12, 0.55 * smoothstep(0.0, 0.3, f)))
			foam_cols.append(Color(1, 1, 1, 0.5 * sin(f * PI) * (0.6 + 0.4 * sin(t * 2.0 + arm))))
		p.draw_polyline_colors(pts, dark_cols, 17.0, true)
		p.draw_polyline_colors(pts, foam_cols, 3.0, true)
	p.draw_circle(Vector2.ZERO, 40.0, Color(0.0, 0.02, 0.08, 0.85))
	p.draw_circle(Vector2.ZERO, 26.0, Color(0.0, 0.0, 0.03, 0.95))
	p.draw_arc(Vector2.ZERO, 42.0, t, t + TAU * 0.7, 20, Color(1, 1, 1, 0.5), 2.0, true)


# ------------------------------------------------------------------- bottle

static func _bottle(p: Poi) -> void:
	var t := p.t
	var bob := sin(t * 1.7) * 3.0
	var rot := 0.7 + sin(t * 1.1) * 0.2
	# Ripples and a hopeful glow.
	for i in 2:
		var ph := fmod(t * 0.5 + i * 0.5, 1.0)
		p.draw_arc(Vector2.ZERO, 14.0 + ph * 40.0, 0.0, TAU, 32, Color(1, 1, 1, 0.5 * (1.0 - ph)), 2.0, true)
	_glow(p, Vector2.ZERO, 70.0, Color(1.0, 0.9, 0.5, 0.9), 0.35 + 0.15 * sin(t * 2.4))
	p.draw_set_transform(Vector2(0, bob), rot, Vector2.ONE * clampf(p.appear * 3.0, 0.0, 1.0))
	p.draw_rect(Rect2(-12, -5.5, 26, 11).grow(1.0), Color(0, 0.1, 0.12, 0.3))
	p.draw_rect(Rect2(-14, -6, 22, 12), Color(0.22, 0.62, 0.42, 0.95))
	p.draw_circle(Vector2(-14, 0), 6.0, Color(0.22, 0.62, 0.42, 0.95))
	p.draw_rect(Rect2(8, -3, 9, 6), Color(0.28, 0.7, 0.48, 0.95))
	p.draw_rect(Rect2(17, -3.4, 4, 6.8), Color(0.65, 0.45, 0.25))
	p.draw_rect(Rect2(-10, -3, 16, 6), Color(0.95, 0.9, 0.72, 0.9))
	p.draw_line(Vector2(-12, -4.5), Vector2(6, -4.5), Color(1, 1, 1, 0.55), 1.4)
	p.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in 2:
		var ph2 := fmod(t * 0.8 + i * 0.5, 1.0)
		var a := t * 1.2 + i * PI
		var sp := Vector2.from_angle(a) * 26.0
		var r := 5.0 * sin(ph2 * PI)
		p.draw_line(sp + Vector2(-r, 0), sp + Vector2(r, 0), Color(1, 0.95, 0.6, 0.9), 1.8)
		p.draw_line(sp + Vector2(0, -r), sp + Vector2(0, r), Color(1, 0.95, 0.6, 0.9), 1.8)


# -------------------------------------------------------------------- wisps

static func _wisps(p: Poi) -> void:
	var t := p.t
	var vis := clampf(p.night * 1.4 - 0.2, 0.0, 1.0)
	if vis <= 0.01:
		return
	p.draw_circle(Vector2.ZERO, 120.0, Color(0.4, 0.9, 1.0, 0.05 * vis))
	for o in p.layout["orbs"]:
		for k in range(9, -1, -1):
			var tt: float = t - k * 0.06
			var a: float = float(o["ph"]) + tt * float(o["sp"])
			var pos := Vector2(cos(a) * float(o["r"]), sin(a * 1.3) * float(o["r"]) * float(o["ry"]))
			var f := 1.0 - k / 10.0
			var col := Color(0.55, 0.95, 1.0, 0.0)
			if k == 0:
				p.draw_circle(pos, 20.0, Color(0.4, 0.8, 1.0, 0.1 * vis))
				p.draw_circle(pos, 10.0, Color(0.55, 0.95, 1.0, 0.3 * vis))
				p.draw_circle(pos, 4.5, Color(0.9, 1.0, 1.0, 0.95 * vis))
			else:
				col.a = 0.22 * f * vis
				p.draw_circle(pos, 3.5 * f + 1.0, col)
