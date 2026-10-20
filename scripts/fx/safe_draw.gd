class_name SafeDraw
extends RefCounted
## draw_colored_polygon() logs an error and draws nothing when a shape is
## degenerate (self-touching tips, zero area). Animated shapes can briefly be,
## so they go through this: triangulate first, skip silently on failure.


static func poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	if pts.size() < 3:
		return
	var idx := Geometry2D.triangulate_polygon(pts)
	if idx.is_empty():
		return
	var colors := PackedColorArray([col, col, col])
	var none := PackedVector2Array()
	for i in range(0, idx.size(), 3):
		ci.draw_primitive(PackedVector2Array([pts[idx[i]], pts[idx[i + 1]], pts[idx[i + 2]]]), colors, none)
