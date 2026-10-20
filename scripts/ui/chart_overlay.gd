class_name ChartOverlay
extends Control
## Full-screen sea chart in a parchment frame.

signal closed

var chart: ChartView
var _sea: Sea
var close_btn: IconButton
var legend: Control


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
	var pct := UiKit.body("Charted 0%", 36, Color("3a2515"))
	pct.autowrap_mode = TextServer.AUTOWRAP_OFF
	pct.custom_minimum_size.x = 250
	pct.name = "Pct"
	row.add_child(pct)
	var close := IconButton.new("quit", 44.0)
	close.glass = false
	close.kind = "x"
	close.pressed.connect(func(): closed.emit())
	close_btn = close
	chart.resized.connect(func(): chart.show_whole_world())
	# Round close button pinned to the frame's top-right corner.
	add_child(close_btn)
	close_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close_btn.offset_left = -128.0
	close_btn.offset_right = -36.0
	close_btn.offset_top = 78.0
	close_btn.offset_bottom = 170.0
	legend = Legend.new()
	chart.add_child(legend)
	legend.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	legend.offset_left = -330.0
	legend.offset_top = -330.0
	legend.offset_right = -14.0
	legend.offset_bottom = -14.0


class Legend extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var sb := UiKit.parchment_box()
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(14)
		sb.shadow_size = 6
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var rows := [["ship", "Your Ship"], ["village", "Settlement"], ["unknown", "Rumour"], ["lighthouse", "Lighthouse"], ["treasure", "Treasure"]]
		for i in rows.size():
			var y := 32.0 + i * 54.0
			UiIcons.draw(self, rows[i][0], Vector2(40, y), 18.0)
			draw_string(Game.body_font_bold, Vector2(78, y + 10), rows[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("3a2515"))


func open(sea: Sea) -> void:
	_sea = sea
	chart.bind(sea)
	set_process(true)
	await get_tree().process_frame
	chart.show_whole_world()
	chart.center_on_ship()
	chart.zoom_by(0.5)
	UiKit.pop_in(self)


func _process(_dt: float) -> void:
	if _sea != null and _sea.world != null:
		(find_child("Pct", true, false) as Label).text = "Charted %d%%" % int(round(_sea.world.fog.percent()))
