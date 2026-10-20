class_name LoadingOverlay
extends Control
## "Charting the seas..." screen with a spinning compass, shown while the
## archipelago is generated.

const TIPS := [
	"Fog lifts as you sail. Unexplored water stays hidden.",
	"Lighthouses clear the mist for miles around.",
	"Storms shorten your spyglass. Hug the coast when the sky turns dark.",
	"Some lights only appear at night.",
	"Villages trade rumours. Listen closely.",
	"Whirlpools can be escaped by sailing straight out.",
]

var _t := 0.0
var _tip := ""
var _alpha := 0.0
var _shown := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func show_overlay() -> void:
	_tip = TIPS[randi() % TIPS.size()]
	visible = true
	_shown = true


func hide_overlay() -> void:
	_shown = false


func _process(dt: float) -> void:
	_t += dt
	_alpha = move_toward(_alpha, 1.0 if _shown else 0.0, dt * (4.0 if _shown else 3.0))
	if _alpha <= 0.0 and not _shown:
		visible = false
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.08, 0.13, _alpha))
	var c := size * 0.5 + Vector2(0, -30)
	var a := _alpha
	draw_arc(c, 70.0, 0.0, TAU, 48, Color(Game.UI_GOLD, 0.8 * a), 5.0, true)
	for i in 12:
		var ang := TAU * i / 12.0
		draw_line(c + Vector2.from_angle(ang) * 62.0, c + Vector2.from_angle(ang) * (52.0 if i % 3 else 44.0), Color(Game.UI_GOLD, 0.7 * a), 3.0)
	var needle := sin(_t * 1.6) * 0.9 + _t * 1.3
	var d := Vector2.from_angle(needle)
	draw_colored_polygon(PackedVector2Array([c + d * 54.0, c + d.rotated(PI * 0.5) * 9.0, c - d * 54.0, c + d.rotated(-PI * 0.5) * 9.0]), Color(0.8, 0.22, 0.17, a))
	draw_colored_polygon(PackedVector2Array([c - d * 54.0, c + d.rotated(PI * 0.5) * 9.0, c, c + d.rotated(-PI * 0.5) * 9.0]), Color(0.92, 0.9, 0.84, a))
	draw_circle(c, 7.0, Color(Game.UI_GOLD, a))
	var font := Game.title_font
	var text := "Charting the seas" + ".".repeat(int(_t * 2.0) % 4)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x
	draw_string(font, c + Vector2(-w * 0.5, 170), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color(Game.UI_PARCHMENT, a))
	var f2 := Game.body_font
	var w2 := f2.get_string_size(_tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	draw_string(f2, c + Vector2(-w2 * 0.5, 236), _tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(Game.UI_PARCHMENT, 0.7 * a))
