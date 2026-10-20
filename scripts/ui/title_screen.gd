class_name TitleScreen
extends Control

signal set_sail
signal open_settings
signal quit_game

var _title: Label
var _sub: Label
var _buttons: VBoxContainer
var _t := 0.0
var _intro_done := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Soft darkening at the top and bottom keeps text readable over any sea.
	for flip in [false, true]:
		var g := Gradient.new()
		var dark := Color(0.01, 0.05, 0.09)
		if flip:
			g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
			g.colors = PackedColorArray([Color(dark, 0.0), Color(dark, 0.35), Color(dark, 0.82)])
		else:
			g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
			g.colors = PackedColorArray([Color(dark, 0.8), Color(dark, 0.45), Color(dark, 0.0)])
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill_from = Vector2(0, 0)
		gt.fill_to = Vector2(0, 1)
		var tr := TextureRect.new()
		tr.texture = gt
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if flip:
			tr.anchor_top = 0.55
		else:
			tr.anchor_bottom = 0.5
		tr.offset_top = 0
		tr.offset_bottom = 0
		add_child(tr)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	var top_pad := Control.new()
	top_pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_pad.size_flags_stretch_ratio = 0.5
	box.add_child(top_pad)

	_title = Label.new()
	_title.text = "Salt & Sail"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", Game.title_font)
	_title.add_theme_font_size_override("font_size", 250)
	_title.add_theme_color_override("font_color", Color("f7e9c3"))
	_title.add_theme_color_override("font_outline_color", Color("1a0f08"))
	_title.add_theme_constant_override("outline_size", 22)
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_title.add_theme_constant_override("shadow_offset_y", 10)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_title)

	_sub = Label.new()
	_sub.text = "A pirate's voyage across\nthe unknown sea"
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_font_override("font", Game.body_font)
	_sub.add_theme_font_size_override("font_size", 38)
	_sub.add_theme_color_override("font_color", Color("f1e2bd"))
	_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_sub.add_theme_constant_override("outline_size", 8)
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_sub)

	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.size_flags_stretch_ratio = 1.1
	box.add_child(gap)

	_buttons = VBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 16)
	_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_buttons)
	box.add_child(center)
	var play := UiKit.button("Set Sail", true, 620.0)
	play.pressed.connect(func(): set_sail.emit())
	_buttons.add_child(play)
	var settings := UiKit.button("Settings", false, 620.0)
	settings.pressed.connect(func(): open_settings.emit())
	_buttons.add_child(settings)
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		var quit := UiKit.button("Quit", false, 620.0)
		quit.pressed.connect(func(): quit_game.emit())
		_buttons.add_child(quit)

	var bottom_pad := Control.new()
	bottom_pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_pad.size_flags_stretch_ratio = 0.3
	box.add_child(bottom_pad)

	var ver := Label.new()
	ver.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0.1.0")
	ver.add_theme_font_size_override("font_size", 22)
	ver.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	ver.position = Vector2(30, -50)
	ver.offset_left = 30
	ver.offset_top = -52
	add_child(ver)
	visible = false


func intro() -> void:
	visible = true
	_intro_done = false
	_title.pivot_offset = _title.size * 0.5
	_title.scale = Vector2(0.85, 0.85)
	_title.modulate.a = 0.0
	_sub.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_title, "scale", Vector2.ONE, 1.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_title, "modulate:a", 1.0, 0.7)
	tw.tween_property(_sub, "modulate:a", 1.0, 0.9).set_delay(0.7)
	var i := 0
	for b in _buttons.get_children():
		b.modulate.a = 0.0
		var off := 40.0
		b.position.y += 0.0
		tw.tween_property(b, "modulate:a", 1.0, 0.5).set_delay(1.0 + i * 0.14)
		i += 1
	tw.chain().tween_callback(func(): _intro_done = true)


func outro() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func():
		visible = false
		modulate.a = 1.0)


func _process(dt: float) -> void:
	_t += dt
	if _intro_done and _title != null:
		_title.pivot_offset = _title.size * 0.5
		_title.rotation = sin(_t * 0.7) * 0.012
		_title.scale = Vector2.ONE * (1.0 + sin(_t * 0.9) * 0.008)
