class_name Joystick
extends Control
## Floating virtual joystick: appears wherever the thumb lands and steers the
## ship. Also reads keyboard / gamepad so the game is testable on a desktop.

signal first_used

var value := Vector2.ZERO
var active := false
var enabled := true
var blockers: Array[Control] = []

var _index := -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO
var _alpha := 0.0
var _hint_alpha := 1.0
var _used := false
var _t := 0.0
var _radius := 120.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_used = Game.has_seen_hint("joystick")
	_hint_alpha = 0.0 if _used else 1.0


func _update_radius() -> void:
	_radius = 120.0 * float(Game.settings["joystick_size"])


func _input(event: InputEvent) -> void:
	if not enabled or not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var pos: Vector2 = make_input_local(event).position
		if event.pressed and _index == -1 and not _blocked(pos):
			_index = event.index
			_origin = pos
			_knob = Vector2.ZERO
			active = true
			_update_radius()
			if not _used:
				_used = true
				Game.mark_hint("joystick")
				first_used.emit()
		elif not event.pressed and event.index == _index:
			_release()
	elif event is InputEventScreenDrag and event.index == _index:
		var pos2: Vector2 = make_input_local(event).position
		var d := pos2 - _origin
		if d.length() > _radius:
			# Let the base follow the thumb so you never "run out" of stick.
			_origin += d.normalized() * (d.length() - _radius)
			d = d.limit_length(_radius)
		_knob = d


func _blocked(pos: Vector2) -> bool:
	for c in blockers:
		if is_instance_valid(c) and c.is_visible_in_tree() and c.get_global_rect().grow(10.0).has_point(pos):
			return true
	return false


func _release() -> void:
	_index = -1
	active = false
	_knob = Vector2.ZERO


func cancel() -> void:
	_release()


func get_vector() -> Vector2:
	if active:
		var v := _knob / _radius
		if v.length() < 0.1:
			return Vector2.ZERO
		return v
	if not enabled:
		return Vector2.ZERO
	return Input.get_vector("steer_left", "steer_right", "steer_up", "steer_down")


func _process(dt: float) -> void:
	_t += dt
	value = get_vector()
	_alpha = move_toward(_alpha, 1.0 if active else 0.0, dt * (8.0 if active else 3.0))
	_hint_alpha = move_toward(_hint_alpha, 0.0 if (_used or not enabled) else 1.0, dt * 2.0)
	queue_redraw()


func _draw() -> void:
	if _alpha > 0.01:
		_draw_stick(_origin, _knob, _alpha, _radius)
	if _hint_alpha > 0.01:
		var r := 120.0 * float(Game.settings["joystick_size"])
		var base := Vector2(size.x * 0.5, size.y * 0.76)
		var k := Vector2.from_angle(_t * 1.2) * r * 0.45 * (0.5 + 0.5 * sin(_t * 0.8))
		_draw_stick(base, k, _hint_alpha * 0.55, r)
		var font := Game.body_font_bold
		var text := "Touch and drag to steer"
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 32).x
		draw_string(font, base + Vector2(-w * 0.5 + 2, r + 56 + 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(0, 0, 0, 0.5 * _hint_alpha))
		draw_string(font, base + Vector2(-w * 0.5, r + 56), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(Game.UI_PARCHMENT, _hint_alpha))


func _draw_stick(origin: Vector2, knob: Vector2, a: float, r: float) -> void:
	# Base: dark glass disc, brass rim and compass ticks.
	draw_circle(origin, r + 6.0, Color(0, 0, 0, 0.18 * a))
	draw_circle(origin, r, Color(0.04, 0.1, 0.16, 0.38 * a))
	draw_arc(origin, r, 0.0, TAU, 56, Color(Game.UI_GOLD, 0.8 * a), 4.0, true)
	draw_arc(origin, r * 0.62, 0.0, TAU, 40, Color(Game.UI_GOLD, 0.25 * a), 2.0, true)
	for i in 16:
		var ang := TAU * i / 16.0
		var len := 14.0 if i % 4 == 0 else 7.0
		draw_line(origin + Vector2.from_angle(ang) * (r - 3.0), origin + Vector2.from_angle(ang) * (r - 3.0 - len), Color(Game.UI_GOLD, 0.7 * a), 2.0)
	# Power ring brightens as you push harder.
	var power := clampf(knob.length() / r, 0.0, 1.0)
	if power > 0.05:
		draw_arc(origin, r * 0.62 + power * 6.0, knob.angle() - 0.5, knob.angle() + 0.5, 12, Color(1, 0.9, 0.5, 0.6 * a * power), 6.0, true)
	# Knob.
	var kp := origin + knob
	draw_circle(kp + Vector2(0, 5), 38.0, Color(0, 0, 0, 0.3 * a))
	draw_circle(kp, 38.0, Color(0.55, 0.36, 0.14, a))
	draw_circle(kp, 33.0, Color(0.95, 0.74, 0.3, a))
	draw_circle(kp + Vector2(-6, -7), 20.0, Color(1.0, 0.88, 0.55, 0.9 * a))
	draw_arc(kp, 33.0, 0.0, TAU, 32, Color(0.4, 0.25, 0.08, 0.8 * a), 2.0, true)
	if power > 0.08:
		var d := knob.normalized()
		draw_colored_polygon(PackedVector2Array([kp + d * 24.0, kp + d.rotated(2.5) * 12.0, kp + d.rotated(-2.5) * 12.0]), Color(0.4, 0.22, 0.06, 0.85 * a))
