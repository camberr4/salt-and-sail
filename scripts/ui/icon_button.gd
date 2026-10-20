class_name IconButton
extends Control
## Round brass button with a code-drawn icon. Press animation included.

signal pressed

var kind := "pause"
var label := ""
var _down := false
var _hover := 0.0
var _press := 0.0
var _t := 0.0
var _radius := 36.0


func _init(p_kind: String = "pause", p_radius: float = 36.0, p_label: String = "") -> void:
	kind = p_kind
	_radius = p_radius
	label = p_label
	custom_minimum_size = Vector2.ONE * (p_radius * 2.0 + 16.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
		else:
			if _down and get_rect().has_point(event.position + position):
				pressed.emit()
				Sfx.play("click", -4.0)
				Game.haptic(15, 0.3)
			_down = false
	elif event is InputEventMouseMotion and _down:
		pass


func _process(dt: float) -> void:
	_t += dt
	_press = move_toward(_press, 1.0 if _down else 0.0, dt * 10.0)
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := _radius * (1.0 - 0.06 * _press)
	draw_circle(c + Vector2(0, 4), r + 2.0, Color(0, 0, 0, 0.3))
	draw_circle(c, r, Color("5a3a1e"))
	draw_circle(c, r - 3.0, Color("e8b64a"))
	draw_circle(c, r - 7.0, Color("f1e2bd").lerp(Color("d9c08a"), _press))
	draw_arc(c, r - 7.0, PI * 1.1, PI * 1.9, 16, Color(1, 1, 1, 0.5), 2.0, true)
	UiIcons.draw(self, kind, c + Vector2(0, 1.0 * _press), r * 0.52, UiIcons.INK, _t)
