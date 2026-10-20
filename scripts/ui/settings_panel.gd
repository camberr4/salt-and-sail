class_name SettingsPanel
extends Control

signal closed


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.dim_rect(0.6))
	var panel := UiKit.panel(960.0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	box.add_child(UiKit.title("Settings", 78))

	box.add_child(_slider("Master volume", "master"))
	box.add_child(_slider("Music", "music"))
	box.add_child(_slider("Sound effects", "sfx"))
	box.add_child(_slider("Joystick size", "joystick_size", 0.7, 1.5))
	box.add_child(_toggle("Vibration", "haptics"))
	box.add_child(_quality())
	box.add_child(_toggle("Battery saver (30 fps)", "fps30"))
	box.add_child(_toggle("Show FPS", "show_fps"))

	var done := UiKit.button("Done", true, 360.0)
	done.pressed.connect(func(): closed.emit())
	var row := CenterContainer.new()
	row.add_child(done)
	box.add_child(row)
	var c := UiKit.centered(panel)
	add_child(c)
	await get_tree().process_frame
	UiKit.pop_in(panel)


func _row(text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	var l := UiKit.body(text, 34)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.custom_minimum_size.x = 330
	h.add_child(l)
	return h


func _slider(text: String, key: String, lo: float = 0.0, hi: float = 1.0) -> HBoxContainer:
	var h := _row(text)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = float(Game.settings[key])
	s.custom_minimum_size = Vector2(300, 60)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(func(v: float):
		Game.set_setting(key, v)
		Sfx.play("click", -8.0))
	h.add_child(s)
	return h


func _toggle(text: String, key: String) -> HBoxContainer:
	var h := _row(text)
	var b := UiKit.button("", false, 180.0)
	b.custom_minimum_size.y = 72
	b.add_theme_font_size_override("font_size", 32)
	var upd := func(): b.text = "On" if Game.settings[key] else "Off"
	upd.call()
	b.pressed.connect(func():
		Game.set_setting(key, not Game.settings[key])
		upd.call())
	h.add_child(b)
	return h


func _quality() -> HBoxContainer:
	var h := _row("Graphics")
	var group := ButtonGroup.new()
	var names := ["Low", "Medium", "High"]
	for i in 3:
		var b := UiKit.button(names[i], false, 140.0)
		b.custom_minimum_size.y = 72
		b.add_theme_font_size_override("font_size", 30)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = int(Game.settings["quality"]) == i
		b.toggled.connect(func(on: bool):
			if on:
				Game.set_setting("quality", i))
		h.add_child(b)
	return h
