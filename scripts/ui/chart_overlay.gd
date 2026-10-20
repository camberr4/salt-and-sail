class_name ChartOverlay
extends Control
## Full-screen sea chart in a parchment frame.

signal closed

var chart: ChartView
var _sea: Sea


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.dim_rect(0.7))
	var frame := PanelContainer.new()
	var sb := UiKit.parchment_box()
	sb.set_corner_radius_all(24)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 16
	sb.content_margin_bottom = 20
	frame.add_theme_stylebox_override("panel", sb)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 28
	frame.offset_right = -28
	frame.offset_top = 70
	frame.offset_bottom = -70
	add_child(frame)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	frame.add_child(v)
	v.add_child(UiKit.title("Sea Chart", 76))

	chart = ChartView.new()
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(chart)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	for spec in [["+", 0.7], ["-", 1.4]]:
		var z := UiKit.button(spec[0], false, 84.0)
		z.custom_minimum_size.y = 84
		var f: float = spec[1]
		z.pressed.connect(func(): chart.zoom_by(f))
		row.add_child(z)
	var me := UiKit.button("Find ship", false, 250.0)
	me.custom_minimum_size.y = 84
	me.add_theme_font_size_override("font_size", 32)
	me.pressed.connect(func(): chart.center_on_ship())
	row.add_child(me)
	var close := UiKit.button("Close", true, 240.0)
	close.custom_minimum_size.y = 90
	close.add_theme_font_size_override("font_size", 40)
	close.pressed.connect(func(): closed.emit())
	row.add_child(close)
	chart.resized.connect(func(): chart.show_whole_world())


func open(sea: Sea) -> void:
	_sea = sea
	chart.bind(sea)
	await get_tree().process_frame
	chart.show_whole_world()
	chart.center_on_ship()
	chart.zoom_by(0.5)
	UiKit.pop_in(self)
