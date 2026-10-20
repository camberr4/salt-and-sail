class_name ShipVisual
extends Node2D
## The player's ship, drawn entirely in code in layers: shadow, hull, deck,
## fittings, masts, sails, rigging, crow's nest and flag. Looks are driven by a
## small dictionary so upgrades and livery (milestone 2) only change data.

const HL := 82.0  # half length
const HB := 33.0  # half beam

var look := {
	"hull": Color("7a4a24"),
	"hull_dark": Color("3a2112"),
	"deck": Color("c08f55"),
	"trim": Color("b23a2b"),
	"sail": Color("f4ead0"),
	"sail_shade": Color("c9b894"),
	"flag": Color("1d1b22"),
	"cannons": 3,
	"masts": 3,
}

# Animation inputs, written by Ship each frame.
var speed01 := 0.0
var heel := 0.0
var wind_local := Vector2(0.4, 0.2)
var night := 0.0
var time := 0.0
var damage_flash := 0.0

var _theta := 0.0
var _hull_outer: PackedVector2Array
var _hull_rim: PackedVector2Array
var _hull_deck: PackedVector2Array
var _phase := randf() * 10.0


func _ready() -> void:
	_hull_outer = _hull(1.0, 1.0)
	_hull_rim = _hull(0.965, 0.9)
	_hull_deck = _hull(0.9, 0.74)
	z_index = 0


func _half_w(u: float) -> float:
	if u >= 0.0:
		return HB * pow(maxf(1.0 - pow(u, 2.1), 0.0), 0.78)
	return HB * (0.46 + 0.54 * pow(maxf(1.0 - pow(-u, 2.6), 0.0), 0.62))


func _hull(ls: float, ws: float, n: int = 26) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n + 1):
		var u := lerpf(-1.0, 1.0, float(i) / n)
		pts.append(Vector2(u * HL * ls, -_half_w(u) * ws))
	for i in range(n, -1, -1):
		var u := lerpf(-1.0, 1.0, float(i) / n)
		pts.append(Vector2(u * HL * ls, _half_w(u) * ws))
	return pts


func _process(delta: float) -> void:
	time += delta
	queue_redraw()


func _parallax() -> Vector2:
	return Vector2(0.0, -1.0).rotated(-global_rotation)


func _draw() -> void:
	var t := time + _phase
	var par := _parallax()
	var bob := sin(t * 1.9) * 0.012
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 1.0 + bob + heel * 0.05))

	_draw_shadow(par)
	_draw_hull()
	_draw_deck(t)
	_draw_rig(t, par)
	if damage_flash > 0.0:
		draw_colored_polygon(_hull_outer, Color(1, 0.2, 0.1, damage_flash * 0.45))


func _draw_shadow(par: Vector2) -> void:
	var off := -par * 16.0 + Vector2(0, 0)
	var sh := PackedVector2Array()
	for p in _hull_outer:
		sh.append(p * 1.04 + off.rotated(0.0))
	draw_colored_polygon(sh, Color(0.0, 0.09, 0.17, 0.30))
	var sh2 := PackedVector2Array()
	for p in _hull_outer:
		sh2.append(p * 1.12 + off * 1.15)
	draw_colored_polygon(sh2, Color(0.0, 0.09, 0.17, 0.12))


func _draw_hull() -> void:
	var dark: Color = look["hull_dark"]
	var hull: Color = look["hull"]
	draw_colored_polygon(_hull_outer, dark)
	draw_polyline(_close(_hull_outer), dark.darkened(0.3), 3.0, true)
	draw_colored_polygon(_hull_rim, hull)
	# Gunwale highlight on the upper-left edge.
	var hl := hull.lightened(0.32)
	draw_polyline(_close(_hull_rim), Color(hl, 0.9), 1.6, true)
	# Livery stripe running along the rail.
	var stripe := _hull(0.93, 0.84)
	draw_polyline(_close(stripe), look["trim"], 2.2, true)
	# Rail posts around the gunwale.
	for i in range(0, 24):
		var u := lerpf(-0.9, 0.9, i / 23.0)
		var w := _half_w(u) * 0.9
		for s in [-1.0, 1.0]:
			var post := Vector2(u * HL * 0.965, w * float(s))
			draw_circle(post, 2.1, dark)
			draw_circle(post + Vector2(-0.4, -0.4), 1.2, hull.lightened(0.45))
	# Planking on the hull sides.
	for k in [-0.95, -0.78, 0.78, 0.95]:
		var line := PackedVector2Array()
		for i in range(0, 21):
			var u := lerpf(-0.93, 0.95, i / 20.0)
			line.append(Vector2(u * HL, _half_w(u) * 0.93 * k))
		draw_polyline(line, Color(dark, 0.35), 1.0, true)


func _draw_deck(t: float) -> void:
	var deck: Color = look["deck"]
	draw_colored_polygon(_hull_deck, deck)
	# Plank lines running fore-aft.
	for k in range(-5, 6):
		var f := k / 6.0
		var line := PackedVector2Array()
		for i in range(0, 17):
			var u := lerpf(-0.88, 0.9, i / 16.0)
			line.append(Vector2(u * HL * 0.9, _half_w(u) * 0.74 * f))
		draw_polyline(line, Color(0.35, 0.2, 0.08, 0.28), 1.0, true)
	# Butt joints.
	for i in range(0, 9):
		var x := lerpf(-HL * 0.72, HL * 0.72, i / 8.0)
		var w := _half_w(x / HL) * 0.74
		draw_line(Vector2(x, -w * (0.4 + 0.3 * float(i % 3))), Vector2(x, -w * 0.1 * float(i % 3)), Color(0.35, 0.2, 0.08, 0.18), 1.0)
	draw_polyline(_close(_hull_deck), Color(0.3, 0.17, 0.07, 0.8), 2.0, true)

	# Raised forecastle with its own rail.
	var fore := PackedVector2Array()
	for i in range(0, 9):
		var u := lerpf(0.56, 0.9, i / 8.0)
		fore.append(Vector2(u * HL * 0.9, -_half_w(u) * 0.74))
	for i in range(8, -1, -1):
		var u := lerpf(0.56, 0.9, i / 8.0)
		fore.append(Vector2(u * HL * 0.9, _half_w(u) * 0.74))
	draw_colored_polygon(fore, deck.darkened(0.12))
	draw_polyline(_close(fore), Color(0.3, 0.17, 0.07, 0.85), 1.6, true)
	for k in range(-2, 3):
		var line := PackedVector2Array()
		for i in range(0, 6):
			var u := lerpf(0.58, 0.88, i / 5.0)
			line.append(Vector2(u * HL * 0.9, _half_w(u) * 0.74 * k / 2.6))
		draw_polyline(line, Color(0.35, 0.2, 0.08, 0.3), 1.0, true)
	# Stern cabin.
	var cab := Rect2(-HL * 0.9, -HB * 0.52, HL * 0.34, HB * 1.04)
	draw_rect(cab.grow(2.0), Color(0.18, 0.09, 0.05))
	draw_rect(cab, Color("8a2f25"))
	draw_rect(Rect2(cab.position + Vector2(2, 2), cab.size - Vector2(4, 4)), Color("a8402f"))
	draw_line(cab.position + Vector2(cab.size.x * 0.5, 2), cab.position + Vector2(cab.size.x * 0.5, cab.size.y - 2), Color(0.3, 0.1, 0.07, 0.8), 2.0)
	for k in range(4):
		var yy := cab.position.y + 6.0 + k * (cab.size.y - 12.0) / 3.0
		draw_line(Vector2(cab.position.x + 2, yy), Vector2(cab.end.x - 2, yy), Color(0.3, 0.1, 0.07, 0.45), 1.0)
	# Stern windows glow warmly at night.
	var glow := 0.25 + 0.75 * night
	for s in [-1.0, 1.0]:
		var wp := Vector2(-HL * 0.9 - 1.0, s * HB * 0.28)
		draw_rect(Rect2(wp - Vector2(2, 4.5), Vector2(4, 9)), Color(1.0, 0.82, 0.4, glow))

	# Wheel.
	var wheel := Vector2(-HL * 0.48, 0)
	draw_circle(wheel, 7.0, Color(0.22, 0.12, 0.06))
	draw_circle(wheel, 5.0, Color(0.55, 0.36, 0.18))
	for k in range(6):
		var a := k * TAU / 6.0 + heel * 2.0
		draw_line(wheel, wheel + Vector2.from_angle(a) * 8.5, Color(0.22, 0.12, 0.06), 1.6)
	draw_circle(wheel, 2.0, Color(0.85, 0.65, 0.25))

	# Hatch and barrels.
	var hatch := Rect2(HL * 0.12, -HB * 0.2, HL * 0.16, HB * 0.4)
	draw_rect(hatch, Color(0.28, 0.16, 0.08))
	for k in range(1, 4):
		var hx := hatch.position.x + k * hatch.size.x / 4.0
		draw_line(Vector2(hx, hatch.position.y), Vector2(hx, hatch.end.y), Color(0.55, 0.38, 0.2), 1.3)
	for b in [Vector2(-HL * 0.28, HB * 0.46), Vector2(-HL * 0.28, -HB * 0.46), Vector2(-HL * 0.18, HB * 0.5)]:
		draw_circle(b, 6.0, Color(0.2, 0.1, 0.05))
		draw_circle(b, 4.6, Color(0.5, 0.31, 0.15))
		draw_arc(b, 3.0, 0.0, TAU, 12, Color(0.3, 0.17, 0.08), 1.0)

	# Cannon barrels poking over the rails.
	var n: int = look["cannons"]
	for i in range(n):
		var x := lerpf(-HL * 0.18, HL * 0.34, (i + 0.5) / maxf(n, 1.0))
		var w := _half_w(x / HL)
		for s in [-1.0, 1.0]:
			draw_rect(Rect2(Vector2(x - 3.5, s * (w - 2.0) - (4.0 if s < 0 else -1.0)), Vector2(7, 5)), Color(0.1, 0.09, 0.1))
			draw_circle(Vector2(x, s * (w + 1.0)), 2.2, Color(0.05, 0.05, 0.06))

	# Bowsprit.
	draw_line(Vector2(HL * 0.8, 0), Vector2(HL + 30.0, 0), Color(0.25, 0.14, 0.07), 4.0)
	draw_line(Vector2(HL * 0.8, -0.8), Vector2(HL + 30.0, -0.8), Color(0.55, 0.37, 0.19), 1.5)
	# Capstan.
	draw_circle(Vector2(HL * 0.58, 0), 4.5, Color(0.22, 0.12, 0.06))
	draw_circle(Vector2(HL * 0.58, 0), 3.0, Color(0.6, 0.42, 0.22))
	# Bow lantern.
	if night > 0.05:
		draw_circle(Vector2(HL * 0.84, 0), 3.0, Color(1.0, 0.8, 0.45, 0.4 + 0.6 * night))
	draw_circle(Vector2(-HL * 0.98, 0), 3.2, Color(1.0, 0.78, 0.4, 0.35 + 0.65 * night))


func _draw_sail(mast: Vector2, width: float, theta: float, belly: float, side: float, shake: float, sail_col: Color, shade_col: Color, lift: Vector2) -> void:
	var ydir := Vector2(0, 1).rotated(theta)
	var nrm := ydir.rotated(-PI * 0.5) * side
	var segs := 12
	var yard := PackedVector2Array()
	var curve := PackedVector2Array()
	for i in range(segs + 1):
		var s := float(i) / segs
		var wob := 1.0 + shake * sin(s * 9.0 + time * 14.0)
		var base := mast + ydir * (s - 0.5) * width + lift
		yard.append(base)
		curve.append(base + nrm * sin(PI * s) * belly * wob * (0.85 + 0.15 * sin(s * PI)))
	# Soft shadow cast on the deck, offset away from the light.
	var shadow := Color(0.08, 0.04, 0.02, 0.2)
	for i in range(segs):
		var o := Vector2(5, 7) - lift * 0.6
		draw_primitive(PackedVector2Array([yard[i] + o, yard[i + 1] + o, curve[i + 1] + o, curve[i] + o]), PackedColorArray([shadow, shadow, shadow, shadow]), PackedVector2Array())
	# Sail cloth: bright at the yard, shaded along the belly.
	for i in range(segs):
		var k0 := sin(PI * float(i) / segs)
		var k1 := sin(PI * float(i + 1) / segs)
		var c0 := sail_col.lerp(shade_col, 0.15 + 0.5 * k0)
		var c1 := sail_col.lerp(shade_col, 0.15 + 0.5 * k1)
		var m0 := sail_col.lerp(shade_col, 0.9 * k0)
		var m1 := sail_col.lerp(shade_col, 0.9 * k1)
		draw_primitive(PackedVector2Array([yard[i], yard[i + 1], curve[i + 1], curve[i]]), PackedColorArray([c0, c1, m1, m0]), PackedVector2Array())
	# Cloth seams following the belly.
	for k in range(1, 4):
		var f := k / 4.0
		var seam := PackedVector2Array()
		for i in range(segs + 1):
			seam.append(yard[i].lerp(curve[i], f))
		draw_polyline(seam, Color(0.45, 0.36, 0.22, 0.3), 1.0, true)
	var edge := PackedVector2Array()
	edge.append_array(yard)
	for i in range(segs, -1, -1):
		edge.append(curve[i])
	draw_polyline(_close(edge), Color(0.33, 0.25, 0.15, 0.85), 1.5, true)
	# Yard.
	draw_line(yard[0] - ydir * 3.0, yard[segs] + ydir * 3.0, Color(0.2, 0.11, 0.05), 3.4)
	draw_line(yard[0] - ydir * 3.0, yard[segs] + ydir * 3.0, Color(0.58, 0.4, 0.2), 1.4)


func _draw_rig(t: float, par: Vector2) -> void:
	var sail_col: Color = look["sail"]
	var shade: Color = look["sail_shade"]
	var wl := wind_local
	var strength := clampf(wl.length(), 0.0, 1.3)
	var target := 0.0
	var luff := 0.0
	if wl.x > -0.25:
		target = clampf(wl.angle() * 0.4, -0.5, 0.5)
	else:
		target = signf(wl.y + 0.0001) * 0.45
		luff = clampf(-wl.x, 0.0, 1.0)
	_theta = lerp_angle(_theta, target, 0.05)
	var nrm_dir := Vector2(0, 1).rotated(_theta).rotated(-PI * 0.5)
	var side := 1.0 if nrm_dir.dot(wl) >= 0.0 else -1.0
	var drive := clampf(strength * (1.0 - luff), 0.0, 1.0)
	var belly := 18.0 + 24.0 * drive + 5.0 * speed01
	var shake := 0.05 + luff * 0.25
	var heel_off := Vector2(0, heel * 9.0)

	# (mast x, yard width, belly factor, height of the yard)
	var masts := [
		[Vector2(HL * 0.44, 0), 66.0, 0.8, 26.0],
		[Vector2(HL * 0.04, 0), 86.0, 1.0, 34.0],
		[Vector2(-HL * 0.38, 0), 60.0, 0.78, 24.0],
	]
	if int(look["masts"]) < 3:
		masts.remove_at(2)

	# Jib on the bowsprit.
	var jib := PackedVector2Array()
	for i in range(9):
		var s := i / 8.0
		jib.append(Vector2(lerpf(HL * 0.5, HL + 26.0, s), 0))
	for i in range(8, -1, -1):
		var s := i / 8.0
		jib.append(Vector2(lerpf(HL * 0.5, HL + 26.0, s), side * sin(PI * s) * (6.0 + 8.0 * drive) * (1.0 - s * 0.35)))
	SafeDraw.poly(self, jib, Color(sail_col, 0.96))
	draw_polyline(_close(jib), Color(0.35, 0.27, 0.16, 0.85), 1.2, true)

	# Draw from stern to bow so forward sails overlap the ones behind.
	for mi in range(masts.size() - 1, -1, -1):
		var m: Array = masts[mi]
		var mast: Vector2 = m[0]
		var hy: float = m[3]
		draw_circle(mast + par * 2.0, 4.6, Color(0.17, 0.09, 0.04))
		draw_circle(mast + par * 2.0, 3.2, Color(0.5, 0.33, 0.16))
		var lift: Vector2 = par * hy * 0.22 + heel_off * (hy / 34.0)
		_draw_sail(mast, m[1], _theta, belly * m[2], side, shake, sail_col, shade, lift)
		# Topsail, higher and smaller, for depth.
		var lift2: Vector2 = par * (hy * 0.22 + 7.0) + heel_off * ((hy + 18.0) / 34.0)
		_draw_sail(mast + Vector2(-2.0, 0), m[1] * 0.6, _theta, belly * m[2] * 0.55, side, shake, sail_col.lightened(0.05), shade, lift2)

	# Emblem on the mainsail.
	var m1: Vector2 = masts[1][0]
	var nrm := Vector2(0, 1).rotated(_theta).rotated(-PI * 0.5) * side
	var emb_c := m1 + par * 7.5 + heel_off * 0.8 + nrm * belly * 0.6
	_draw_skull(emb_c, 7.0, Color(0.12, 0.1, 0.12, 0.78))

	# Crow's nest and flag.
	var top := m1 + par * 22.0 + heel_off * 1.6
	draw_line(m1 + par * 3.0, top, Color(0.2, 0.11, 0.05, 0.9), 2.2)
	draw_circle(top, 8.5, Color(0.17, 0.09, 0.04))
	draw_circle(top, 6.8, Color(0.4, 0.25, 0.12))
	draw_circle(top, 3.3, Color(0.16, 0.08, 0.04))
	_draw_flag(top + par * 5.0, t)


func _draw_skull(c: Vector2, r: float, col: Color) -> void:
	draw_circle(c, r, col)
	draw_rect(Rect2(c + Vector2(-r * 0.5, r * 0.6), Vector2(r, r * 0.55)), col)
	var hole := Color(0.96, 0.92, 0.82, 0.95)
	draw_circle(c + Vector2(-r * 0.35, -r * 0.1), r * 0.24, hole)
	draw_circle(c + Vector2(r * 0.35, -r * 0.1), r * 0.24, hole)
	draw_line(c + Vector2(-r * 1.1, -r * 1.1), c + Vector2(r * 1.1, r * 1.5), Color(col, col.a * 0.8), 1.2)
	draw_line(c + Vector2(r * 1.1, -r * 1.1), c + Vector2(-r * 1.1, r * 1.5), Color(col, col.a * 0.8), 1.2)


func _draw_flag(base: Vector2, t: float) -> void:
	var dir := (wind_local - Vector2(speed01 * 0.7, 0.0))
	if dir.length() < 0.15:
		dir = Vector2(-1, 0)
	dir = dir.normalized()
	var perp := dir.rotated(PI * 0.5)
	var length := 38.0
	var width := 15.0
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in range(11):
		var s := i / 10.0
		var wave := sin(s * 6.5 - t * 9.0) * 3.2 * s
		var taper := lerpf(width, 3.0, s * s)
		var p := base + dir * (s * length) + perp * wave
		top.append(p + perp * taper * 0.5)
		bot.append(p - perp * taper * 0.5)
	bot.reverse()
	var poly := PackedVector2Array()
	poly.append_array(top)
	poly.append_array(bot)
	SafeDraw.poly(self, poly, look["flag"])
	draw_polyline(_close(poly), Color(0, 0, 0, 0.6), 1.0, true)
	var mid := base + dir * (length * 0.34) + perp * sin(0.34 * 6.5 - t * 9.0) * 3.2 * 0.34
	draw_circle(mid, 3.6, Color(0.95, 0.92, 0.85))
	draw_line(mid + Vector2(-3.4, 3.4), mid + Vector2(3.4, -3.4), Color(0.95, 0.92, 0.85), 1.0)
	draw_line(mid + Vector2(-3.4, -3.4), mid + Vector2(3.4, 3.4), Color(0.95, 0.92, 0.85), 1.0)
	draw_circle(base, 1.8, Color(0.85, 0.65, 0.25))


func _close(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	if pts.size() > 0:
		out.append(pts[0])
	return out
