class_name SummaryPanel
extends Control
## Short "voyage log" shown when a voyage ends.

signal again
signal menu

var data := {}
var _rows: Array[Control] = []


func setup(d: Dictionary) -> void:
	data = d


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.dim_rect(0.62))
	var panel := UiKit.panel(900.0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(UiKit.title("Voyage Log", 84))
	var mins := int(data["time"]) / 60
	var secs := int(data["time"]) % 60
	var rows := [
		["Time at sea", "%d:%02d" % [mins, secs]],
		["Treasure", str(data["gold"])],
		["Places found", str(data["found"])],
		["Sea charted", "%d%%" % int(round(data["chart"]))],
	]
	for r in rows:
		var h := HBoxContainer.new()
		var a := UiKit.body(r[0], 34)
		a.autowrap_mode = TextServer.AUTOWRAP_OFF
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b := UiKit.body(r[1], 40, Color("7a2418"))
		b.autowrap_mode = TextServer.AUTOWRAP_OFF
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(a)
		h.add_child(b)
		box.add_child(h)
		_rows.append(h)
		var sep := HSeparator.new()
		box.add_child(sep)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 10
	box.add_child(spacer)
	var b1 := UiKit.button("Set Sail Again", true)
	b1.pressed.connect(func(): again.emit())
	box.add_child(b1)
	var b2 := UiKit.button("Main Menu")
	b2.pressed.connect(func(): menu.emit())
	box.add_child(b2)
	add_child(UiKit.centered(panel))
	await get_tree().process_frame
	UiKit.pop_in(panel)
	for i in _rows.size():
		var row := _rows[i]
		row.modulate.a = 0.0
		create_tween().tween_property(row, "modulate:a", 1.0, 0.35).set_delay(0.35 + i * 0.22)
