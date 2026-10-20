class_name ChartView
extends Control
## Sea chart. In `minimap` mode it is a small round view that follows the ship;
## otherwise it is the whole world with drag-to-pan and zoom buttons.

var sea: Sea
var minimap := false
var view_center := Vector2(WorldGen.WORLD_W, WorldGen.WORLD_H) * 0.5
var view_width := WorldGen.WORLD_W
var min_width := 2400.0

var _rect: ColorRect
var _marks: Control
var _mat: ShaderMaterial
var _drag := -1
var _t := 0.0
var _pinch := {}
var _pinch_start := 0.0
var _pinch_width := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE if minimap else Control.MOUSE_FILTER_STOP
	clip_contents = true
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/chart.gdshader")
	_mat.set_shader_parameter("noise_tex", load("res://assets/textures/noise_atlas.png"))
	_mat.set_shader_parameter("circle_mask", 1.0 if minimap else 0.0)
	_rect.material = _mat
	add_child(_rect)
	_marks = Marks.new()
	_marks.chart = self
	_marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marks)


func bind(p_sea: Sea) -> void:
	sea = p_sea
	_mat.set_shader_parameter("height_tex", sea.world.height_tex)
	_mat.set_shader_parameter("explored_tex", sea.world.fog.texture)


func rebind() -> void:
	if sea != null and sea.world != null:
		bind(sea)


func show_whole_world() -> void:
	var aspect := size.x / maxf(size.y, 1.0)
	view_width = maxf(WorldGen.WORLD_W * 1.04, WorldGen.WORLD_H * 1.12 * aspect)
	view_center = Vector2(WorldGen.WORLD_W, WorldGen.WORLD_H) * 0.5


func center_on_ship() -> void:
	if sea != null:
		view_center = sea.ship.position


func _process(dt: float) -> void:
	_t += dt
	if sea == null or sea.world == null:
		return
	if minimap:
		view_center = view_center.lerp(sea.ship.position, 1.0 - exp(-8.0 * dt))
		view_width = 2700.0
	var view_size := Vector2(view_width, view_width * size.y / maxf(size.x, 1.0))
	_mat.set_shader_parameter("view_center", view_center)
	_mat.set_shader_parameter("view_size", view_size)
	_mat.set_shader_parameter("grid_step", Vector2(1080.0, 1920.0))
	_marks.queue_redraw()


func world_to_local(w: Vector2) -> Vector2:
	var s := size.x / view_width
	return (w - view_center) * s + size * 0.5


func draw_marks(ci: CanvasItem) -> void:
	if sea == null or sea.world == null:
		return
	var s := size.x / view_width
	if not minimap:
		_draw_grid_labels(ci, s)
	for p in sea.pois:
		if not p.discovered and not p.rumored:
			continue
		var lp := world_to_local(p.position)
		if p.kind == "whirlpool" or not p.discovered:
			pass
		if not Rect2(Vector2.ZERO, size).grow(30.0).has_point(lp):
			continue
		if minimap and lp.distance_to(size * 0.5) > size.x * 0.5 - 10.0:
			continue
		var r := 13.0 if not minimap else 8.0
		if p.discovered:
			var shade := 0.0 if not p.visited else 0.35
			ci.draw_circle(lp, r + 3.0, Color(0.95, 0.88, 0.7, 0.85))
			ci.draw_arc(lp, r + 3.0, 0.0, TAU, 20, Color(0.2, 0.12, 0.07, 0.85), 1.6, true)
			UiIcons.draw(ci, p.kind, lp, r * (1.0 - shade * 0.2), UiIcons.INK, _t)
		else:
			# Rumoured: a question mark within a dashed circle, roughly placed.
			var jitter := Vector2(sin(p.data["seed"] * 0.001), cos(p.data["seed"] * 0.002)) * 120.0 * s
			var rp := lp + jitter
			ci.draw_arc(rp, r + 8.0, 0.0, TAU, 20, Color(0.45, 0.28, 0.14, 0.7), 2.0, true)
			UiIcons.draw(ci, "unknown", rp, r, Color(0.45, 0.28, 0.14), _t)
	# The ship.
	var sp := world_to_local(sea.ship.position)
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	ci.draw_circle(sp, (10.0 if minimap else 17.0) + pulse * 5.0, Color(1, 1, 1, 0.22))
	ci.draw_set_transform(sp, sea.ship.heading, Vector2.ONE)
	var rr := 9.0 if minimap else 15.0
	ci.draw_colored_polygon(PackedVector2Array([Vector2(rr * 1.15, 0), Vector2(-rr * 0.8, rr * 0.7), Vector2(-rr * 0.35, 0), Vector2(-rr * 0.8, -rr * 0.7)]), Color("b23a2b"))
	ci.draw_polyline(PackedVector2Array([Vector2(rr * 1.15, 0), Vector2(-rr * 0.8, rr * 0.7), Vector2(-rr * 0.35, 0), Vector2(-rr * 0.8, -rr * 0.7), Vector2(rr * 1.15, 0)]), Color("2b1d12"), 2.0, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_grid_labels(ci: CanvasItem, s: float) -> void:
	var font := Game.body_font_bold
	for i in 10:
		var x := world_to_local(Vector2((i + 0.5) * 1080.0, 0)).x
		if x > 10.0 and x < size.x - 10.0:
			ci.draw_string(font, Vector2(x - 8.0, 26.0), char(65 + i), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.3, 0.18, 0.1, 0.75))
	for j in 10:
		var y := world_to_local(Vector2(0, (j + 0.5) * 1920.0)).y
		if y > 10.0 and y < size.y - 10.0:
			ci.draw_string(font, Vector2(8.0, y + 8.0), str(j + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.3, 0.18, 0.1, 0.75))


class Marks extends Control:
	var chart: ChartView

	func _draw() -> void:
		chart.draw_marks(self)


func zoom_by(factor: float) -> void:
	var full := maxf(WorldGen.WORLD_W * 1.04, WorldGen.WORLD_H * 1.12 * size.x / maxf(size.y, 1.0))
	view_width = clampf(view_width * factor, min_width, full)
	_clamp_center()


func _clamp_center() -> void:
	var half := Vector2(view_width, view_width * size.y / maxf(size.x, 1.0)) * 0.5
	var lo := half.min(Vector2(WorldGen.WORLD_W, WorldGen.WORLD_H) - half)
	var hi := half.max(Vector2(WorldGen.WORLD_W, WorldGen.WORLD_H) - half)
	view_center = Vector2(clampf(view_center.x, minf(lo.x, hi.x), maxf(lo.x, hi.x)), clampf(view_center.y, minf(lo.y, hi.y), maxf(lo.y, hi.y)))


func _gui_input(event: InputEvent) -> void:
	if minimap:
		return
	# Touch pointers are tracked for pinch zoom only; single-finger panning
	# arrives as (emulated) mouse motion so it works the same everywhere.
	if event is InputEventScreenTouch:
		if event.pressed:
			_pinch[event.index] = event.position
			if _pinch.size() == 2:
				var pts := _pinch.values()
				_pinch_start = (pts[0] as Vector2).distance_to(pts[1])
				_pinch_width = view_width
		else:
			_pinch.erase(event.index)
	elif event is InputEventScreenDrag:
		_pinch[event.index] = event.position
		if _pinch.size() >= 2 and _pinch_start > 10.0:
			var pts2 := _pinch.values()
			var d: float = (pts2[0] as Vector2).distance_to(pts2[1])
			view_width = _pinch_width * _pinch_start / maxf(d, 1.0)
			zoom_by(1.0)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and _pinch.size() < 2:
		view_center -= event.relative * view_width / size.x
		_clamp_center()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_by(0.85)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(1.18)
