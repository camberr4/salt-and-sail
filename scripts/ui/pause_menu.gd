class_name PauseMenu
extends Control

signal resume
signal open_chart
signal open_settings
signal end_voyage

var _box: VBoxContainer
var _panel: PanelContainer
var _confirm := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.dim_rect(0.58))
	_panel = UiKit.panel(800.0)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 16)
	_panel.add_child(_box)
	add_child(UiKit.centered(_panel))
	_build_main()
	await get_tree().process_frame
	UiKit.pop_in(_panel)


func _clear() -> void:
	for c in _box.get_children():
		c.queue_free()


func _build_main() -> void:
	_clear()
	_confirm = false
	_box.add_child(UiKit.title("Paused", 84))
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 6
	_box.add_child(spacer)
	var b1 := UiKit.button("Keep Sailing", true)
	b1.pressed.connect(func(): resume.emit())
	_box.add_child(b1)
	var b2 := UiKit.button("Sea Chart")
	b2.pressed.connect(func(): open_chart.emit())
	_box.add_child(b2)
	var b3 := UiKit.button("Settings")
	b3.pressed.connect(func(): open_settings.emit())
	_box.add_child(b3)
	var b4 := UiKit.button("Return to Port")
	b4.pressed.connect(_build_confirm)
	_box.add_child(b4)


func _build_confirm() -> void:
	_clear()
	_confirm = true
	_box.add_child(UiKit.title("Return to port?", 70))
	_box.add_child(UiKit.body("This ends your voyage. Everything you found will be remembered.", 30))
	var b1 := UiKit.button("Keep Sailing", true)
	b1.pressed.connect(func(): resume.emit())
	_box.add_child(b1)
	var b2 := UiKit.button("Return to Port")
	b2.pressed.connect(func(): end_voyage.emit())
	_box.add_child(b2)


func back() -> void:
	if _confirm:
		_build_main()
	else:
		resume.emit()
