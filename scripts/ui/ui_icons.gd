class_name UiIcons
extends RefCounted
## Small vector icons drawn in code. Every icon fits in a circle of radius r
## around c, in a parchment-and-brass palette. `ink` is the main line colour.

const INK := Color("2b1d12")
const BRASS := Color("e8b64a")
const BRASS_DARK := Color("8a5a1c")


static func draw(ci: CanvasItem, kind: String, c: Vector2, r: float, ink: Color = INK, t: float = 0.0) -> void:
	match kind:
		"coin":
			ci.draw_circle(c, r, BRASS_DARK)
			ci.draw_circle(c, r * 0.88, BRASS)
			ci.draw_arc(c, r * 0.62, 0.0, TAU, 24, BRASS_DARK, maxf(1.5, r * 0.1), true)
			ci.draw_line(c + Vector2(0, -r * 0.34), c + Vector2(0, r * 0.34), BRASS_DARK, maxf(1.5, r * 0.14))
			ci.draw_circle(c + Vector2(-r * 0.3, -r * 0.35), r * 0.16, Color(1, 1, 1, 0.55))
		"compass":
			ci.draw_arc(c, r * 0.92, 0.0, TAU, 32, ink, maxf(1.5, r * 0.1), true)
			var n := PackedVector2Array([c + Vector2(0, -r * 0.82), c + Vector2(r * 0.2, 0), c + Vector2(-r * 0.2, 0)])
			var s := PackedVector2Array([c + Vector2(0, r * 0.82), c + Vector2(r * 0.2, 0), c + Vector2(-r * 0.2, 0)])
			SafeDraw.poly(ci, n, Color("b23a2b"))
			SafeDraw.poly(ci, s, ink)
			ci.draw_circle(c, r * 0.1, BRASS)
		"compass_diamond":
			SafeDraw.poly(ci, PackedVector2Array([c + Vector2(0, -r * 0.95), c + Vector2(r * 0.42, 0), c + Vector2(0, r * 0.95), c + Vector2(-r * 0.42, 0)]), Color("e0d3b4"))
			SafeDraw.poly(ci, PackedVector2Array([c + Vector2(0, -r * 0.95), c + Vector2(r * 0.42, 0), c + Vector2(0, 0), c + Vector2(-r * 0.42, 0)]), Color("c4472f"))
			ci.draw_polyline(PackedVector2Array([c + Vector2(0, -r * 0.95), c + Vector2(r * 0.42, 0), c + Vector2(0, r * 0.95), c + Vector2(-r * 0.42, 0), c + Vector2(0, -r * 0.95)]), ink, 2.0, true)
		"scroll":
			var body := Rect2(c + Vector2(-r * 0.7, -r * 0.52), Vector2(r * 1.4, r * 1.04))
			ci.draw_rect(body, Color("f1e2bd"))
			ci.draw_rect(body, ink, false, maxf(1.5, r * 0.09))
			ci.draw_circle(c + Vector2(-r * 0.7, 0), r * 0.26, Color("d9c08a"))
			ci.draw_circle(c + Vector2(r * 0.7, 0), r * 0.26, Color("d9c08a"))
			ci.draw_arc(c + Vector2(-r * 0.7, 0), r * 0.26, 0.0, TAU, 12, ink, 1.5, true)
			ci.draw_arc(c + Vector2(r * 0.7, 0), r * 0.26, 0.0, TAU, 12, ink, 1.5, true)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.4, r * 0.25), c + Vector2(-r * 0.1, -r * 0.1), c + Vector2(r * 0.1, r * 0.1), c + Vector2(r * 0.4, -r * 0.25)]), Color("b23a2b"), maxf(1.5, r * 0.09), true)
		"pause":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.42, -r * 0.5), Vector2(r * 0.28, r)), ink)
			ci.draw_rect(Rect2(c + Vector2(r * 0.14, -r * 0.5), Vector2(r * 0.28, r)), ink)
		"binoculars":
			for s in [-1.0, 1.0]:
				ci.draw_circle(c + Vector2(s * r * 0.42, r * 0.12), r * 0.4, ink)
				ci.draw_circle(c + Vector2(s * r * 0.42, r * 0.12), r * 0.24, Color(ink, 0.35))
				ci.draw_rect(Rect2(c + Vector2(s * r * 0.42 - r * 0.2, -r * 0.62), Vector2(r * 0.4, r * 0.4)), ink)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.14, -r * 0.05), Vector2(r * 0.28, r * 0.2)), ink)
		"menu":
			for i in 3:
				ci.draw_line(c + Vector2(-r * 0.5, (i - 1) * r * 0.36), c + Vector2(r * 0.5, (i - 1) * r * 0.36), ink, maxf(2.0, r * 0.18))
		"wheel":
			ci.draw_arc(c, r * 0.62, 0.0, TAU, 32, ink, maxf(2.0, r * 0.16), true)
			for i in 8:
				var a := TAU * i / 8.0
				ci.draw_line(c + Vector2.from_angle(a) * r * 0.2, c + Vector2.from_angle(a) * r * 0.98, ink, maxf(2.0, r * 0.15))
				ci.draw_circle(c + Vector2.from_angle(a) * r * 0.98, r * 0.1, ink)
			ci.draw_circle(c, r * 0.2, ink)
		"x":
			ci.draw_line(c + Vector2(-r * 0.6, -r * 0.6), c + Vector2(r * 0.6, r * 0.6), ink, maxf(3.0, r * 0.22))
			ci.draw_line(c + Vector2(-r * 0.6, r * 0.6), c + Vector2(r * 0.6, -r * 0.6), ink, maxf(3.0, r * 0.22))
		"quit":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.6, -r * 0.7), Vector2(r * 0.7, r * 1.4)), ink, false, maxf(2.0, r * 0.16))
			ci.draw_line(c + Vector2(-r * 0.1, 0), c + Vector2(r * 0.8, 0), ink, maxf(2.0, r * 0.16))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.95, 0), c + Vector2(r * 0.5, -r * 0.35), c + Vector2(r * 0.5, r * 0.35)]), ink)
		"gear":
			for i in 8:
				var a := TAU * i / 8.0
				ci.draw_line(c + Vector2.from_angle(a) * r * 0.6, c + Vector2.from_angle(a) * r * 0.95, ink, maxf(2.0, r * 0.28))
			ci.draw_circle(c, r * 0.68, ink)
			ci.draw_circle(c, r * 0.3, Color("f1e2bd"))
		"sun":
			var sun_col := Color("f7c948")
			for i in 10:
				var a := TAU * i / 10.0 + t * 0.4
				ci.draw_line(c + Vector2.from_angle(a) * r * 0.62, c + Vector2.from_angle(a) * r * 0.95, sun_col, maxf(2.0, r * 0.12))
			ci.draw_circle(c, r * 0.48, sun_col)
			ci.draw_circle(c + Vector2(-r * 0.1, -r * 0.12), r * 0.2, Color(1, 1, 0.8, 0.7))
		"fog":
			for i in 4:
				var y := -r * 0.55 + i * r * 0.37
				var off := sin(t * 0.8 + i) * r * 0.12
				ci.draw_line(c + Vector2(-r * 0.75 + off, y), c + Vector2(r * 0.75 + off, y), Color(0.85, 0.9, 0.95, 0.95 - i * 0.12), maxf(2.0, r * 0.15))
		"rain":
			_cloud(ci, c + Vector2(0, -r * 0.2), r * 0.8, Color(0.75, 0.82, 0.9))
			for i in 3:
				var x := -r * 0.4 + i * r * 0.4
				var ph := fmod(t * 1.4 + i * 0.33, 1.0)
				ci.draw_line(c + Vector2(x - ph * r * 0.1, r * 0.25 + ph * r * 0.25), c + Vector2(x - ph * r * 0.1 - r * 0.08, r * 0.45 + ph * r * 0.25), Color(0.5, 0.72, 1.0), maxf(2.0, r * 0.11))
		"storm":
			_cloud(ci, c + Vector2(0, -r * 0.25), r * 0.85, Color(0.5, 0.55, 0.65))
			var bolt := PackedVector2Array([c + Vector2(r * 0.12, -r * 0.05), c + Vector2(-r * 0.26, r * 0.35), c + Vector2(0, r * 0.3), c + Vector2(-r * 0.12, r * 0.8), c + Vector2(r * 0.3, r * 0.2), c + Vector2(r * 0.04, r * 0.22)])
			SafeDraw.poly(ci, bolt, Color("ffd23f") if fmod(t, 1.6) < 1.2 else Color("fff6c8"))
		"moon":
			ci.draw_circle(c, r * 0.62, Color("f3e9c6"))
			ci.draw_circle(c + Vector2(r * 0.3, -r * 0.12), r * 0.56, Color(0.08, 0.14, 0.26))
			for p in [Vector2(0.55, 0.5), Vector2(0.75, -0.55)]:
				ci.draw_circle(c + p * r, r * 0.08, Color("f3e9c6"))
		"village":
			SafeDraw.poly(ci, PackedVector2Array([c + Vector2(-r * 0.85, -r * 0.05), c + Vector2(0, -r * 0.8), c + Vector2(r * 0.85, -r * 0.05)]), Color("b23a2b"))
			ci.draw_rect(Rect2(c + Vector2(-r * 0.62, -r * 0.05), Vector2(r * 1.24, r * 0.78)), Color("efe3c4"))
			ci.draw_rect(Rect2(c + Vector2(-r * 0.62, -r * 0.05), Vector2(r * 1.24, r * 0.78)), ink, false, maxf(1.5, r * 0.09))
			ci.draw_rect(Rect2(c + Vector2(-r * 0.15, r * 0.25), Vector2(r * 0.3, r * 0.48)), ink)
		"lighthouse":
			SafeDraw.poly(ci, PackedVector2Array([c + Vector2(-r * 0.4, r * 0.85), c + Vector2(-r * 0.24, -r * 0.4), c + Vector2(r * 0.24, -r * 0.4), c + Vector2(r * 0.4, r * 0.85)]), Color("f4efe4"))
			SafeDraw.poly(ci, PackedVector2Array([c + Vector2(-r * 0.34, r * 0.3), c + Vector2(-r * 0.3, 0.0), c + Vector2(r * 0.3, 0.0), c + Vector2(r * 0.34, r * 0.3)]), Color("b23a2b"))
			ci.draw_rect(Rect2(c + Vector2(-r * 0.3, -r * 0.72), Vector2(r * 0.6, r * 0.34)), Color("ffe18a"))
			SafeDraw.poly(ci, PackedVector2Array([c + Vector2(-r * 0.38, -r * 0.72), c + Vector2(0, -r * 1.0), c + Vector2(r * 0.38, -r * 0.72)]), Color("b23a2b"))
			for s in [-1.0, 1.0]:
				ci.draw_line(c + Vector2(s * r * 0.4, -r * 0.55), c + Vector2(s * r * 0.9, -r * 0.7), Color("ffe18a"), 2.0)
		"treasure":
			ci.draw_line(c + Vector2(-r * 0.7, -r * 0.7), c + Vector2(r * 0.7, r * 0.7), Color("b23a2b"), maxf(3.0, r * 0.28))
			ci.draw_line(c + Vector2(-r * 0.7, r * 0.7), c + Vector2(r * 0.7, -r * 0.7), Color("b23a2b"), maxf(3.0, r * 0.28))
		"skull":
			ci.draw_circle(c + Vector2(0, -r * 0.1), r * 0.62, Color("efe9da"))
			ci.draw_rect(Rect2(c + Vector2(-r * 0.32, r * 0.3), Vector2(r * 0.64, r * 0.4)), Color("efe9da"))
			ci.draw_circle(c + Vector2(-r * 0.26, -r * 0.1), r * 0.17, ink)
			ci.draw_circle(c + Vector2(r * 0.26, -r * 0.1), r * 0.17, ink)
			ci.draw_arc(c + Vector2(0, -r * 0.1), r * 0.62, 0.0, TAU, 24, ink, 1.5, true)
		"wreck":
			var hull := PackedVector2Array([c + Vector2(-r * 0.9, -r * 0.05), c + Vector2(-r * 0.5, r * 0.5), c + Vector2(r * 0.4, r * 0.5), c + Vector2(r * 0.7, r * 0.05)])
			SafeDraw.poly(ci, hull, Color("6b4724"))
			ci.draw_line(c + Vector2(-r * 0.1, 0), c + Vector2(r * 0.35, -r * 0.85), ink, maxf(2.0, r * 0.14))
			SafeDraw.poly(ci, PackedVector2Array([c + Vector2(0.0, -r * 0.5), c + Vector2(r * 0.55, -r * 0.7), c + Vector2(r * 0.35, -r * 0.2)]), Color("efe3c4"))
		"bottle":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.3, -r * 0.1), Vector2(r * 0.6, r * 0.85)), Color("4fa36f"))
			ci.draw_rect(Rect2(c + Vector2(-r * 0.15, -r * 0.65), Vector2(r * 0.3, r * 0.6)), Color("5fb87f"))
			ci.draw_rect(Rect2(c + Vector2(-r * 0.2, -r * 0.88), Vector2(r * 0.4, r * 0.26)), Color("a87636"))
			ci.draw_rect(Rect2(c + Vector2(-r * 0.15, r * 0.05), Vector2(r * 0.3, r * 0.45)), Color("f1e2bd"))
		"whirlpool":
			var pts := PackedVector2Array()
			for i in 30:
				var f := i / 29.0
				pts.append(c + Vector2.from_angle(f * 9.0 + t) * r * (0.12 + 0.8 * f))
			ci.draw_polyline(pts, Color("2a6f97"), maxf(2.0, r * 0.14), true)
		"wisps":
			var fl := PackedVector2Array([c + Vector2(0, -r * 0.9), c + Vector2(r * 0.5, r * 0.1), c + Vector2(0, r * 0.8), c + Vector2(-r * 0.5, r * 0.1)])
			SafeDraw.poly(ci, fl, Color("5fd0e8"))
			ci.draw_circle(c + Vector2(0, r * 0.15), r * 0.22, Color("e8fbff"))
		"ship":
			var hull2 := PackedVector2Array([c + Vector2(r, 0), c + Vector2(r * 0.2, r * 0.55), c + Vector2(-r * 0.85, r * 0.45), c + Vector2(-r * 0.85, -r * 0.45), c + Vector2(r * 0.2, -r * 0.55)])
			SafeDraw.poly(ci, hull2, Color("b23a2b"))
			ci.draw_polyline(PackedVector2Array(Array(hull2) + [hull2[0]]), Color("2b1d12"), 2.0, true)
		"unknown":
			ci.draw_arc(c + Vector2(0, -r * 0.2), r * 0.4, PI, TAU + PI * 0.5, 14, ink, maxf(2.0, r * 0.2), true)
			ci.draw_circle(c + Vector2(0, r * 0.7), r * 0.14, ink)
		"anchor":
			ci.draw_line(c + Vector2(0, -r * 0.7), c + Vector2(0, r * 0.7), ink, maxf(2.0, r * 0.14))
			ci.draw_arc(c + Vector2(0, r * 0.1), r * 0.62, 0.1, PI - 0.1, 16, ink, maxf(2.0, r * 0.14), true)
			ci.draw_arc(c + Vector2(0, -r * 0.8), r * 0.16, 0.0, TAU, 10, ink, 2.0, true)
			ci.draw_line(c + Vector2(-r * 0.3, -r * 0.35), c + Vector2(r * 0.3, -r * 0.35), ink, maxf(2.0, r * 0.12))


static func _cloud(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(c + Vector2(-r * 0.4, r * 0.1), r * 0.36, col)
	ci.draw_circle(c + Vector2(0.0, -r * 0.1), r * 0.46, col)
	ci.draw_circle(c + Vector2(r * 0.42, r * 0.12), r * 0.34, col)
	ci.draw_rect(Rect2(c + Vector2(-r * 0.4, r * 0.1), Vector2(r * 0.82, r * 0.36)), col)
