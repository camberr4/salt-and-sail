class_name UiKit
extends RefCounted
## Builders for the parchment-and-brass menu widgets.


static func parchment_box() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("f1e2bd")
	s.border_color = Color("5a3a1e")
	s.set_border_width_all(6)
	s.set_corner_radius_all(30)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 22
	s.shadow_offset = Vector2(0, 10)
	s.content_margin_left = 48
	s.content_margin_right = 48
	s.content_margin_top = 34
	s.content_margin_bottom = 40
	s.anti_aliasing = true
	return s


static func panel(min_width: float = 640.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", parchment_box())
	p.custom_minimum_size.x = min_width
	return p


static func title(text: String, size: int = 72) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", Game.title_font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("2b1d12"))
	l.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.35))
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


static func body(text: String, size: int = 34, color: Color = Color("3a2515")) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	return l


class BtnIcon extends Control:
	var kind := ""
	var ink := Color.WHITE

	func _draw() -> void:
		UiIcons.draw(self, kind, size * 0.5, minf(size.x, size.y) * 0.5, ink)


static func button(text: String, primary: bool = false, min_w: float = 420.0, icon: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 104 if primary else 88)
	b.focus_mode = Control.FOCUS_NONE
	if primary:
		b.add_theme_stylebox_override("normal", _btn(Color("e8b64a"), Color("8a5a1c")))
		b.add_theme_stylebox_override("hover", _btn(Color("f4c85f"), Color("8a5a1c")))
		b.add_theme_stylebox_override("pressed", _btn(Color("c99a35"), Color("6b4414"), true))
		b.add_theme_color_override("font_color", Color("2b1d12"))
		b.add_theme_color_override("font_hover_color", Color("2b1d12"))
		b.add_theme_color_override("font_pressed_color", Color("2b1d12"))
		b.add_theme_font_size_override("font_size", 52)
	else:
		b.add_theme_stylebox_override("normal", _btn(Color("6d4624"), Color("3a2310")))
		b.add_theme_stylebox_override("hover", _btn(Color("825a30"), Color("3a2310")))
		b.add_theme_stylebox_override("pressed", _btn(Color("4a2f17"), Color("2a180a"), true))
		b.add_theme_font_size_override("font_size", 40)
	b.pressed.connect(func(): Sfx.play("click", -3.0); Game.haptic(12, 0.3))
	if icon != "":
		var ic := BtnIcon.new()
		ic.kind = icon
		ic.ink = Color("2b1d12") if primary else Color("f1e2bd")
		ic.anchor_top = 0.5
		ic.anchor_bottom = 0.5
		ic.offset_left = 34
		ic.offset_right = 86
		ic.offset_top = -26
		ic.offset_bottom = 26
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ic)
	return b


static func _btn(fill: Color, border: Color, pressed: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(4)
	s.border_width_bottom = 8 if not pressed else 4
	s.set_corner_radius_all(18)
	s.content_margin_left = 30
	s.content_margin_right = 30
	s.content_margin_top = 10 if not pressed else 14
	s.content_margin_bottom = 12 if not pressed else 10
	s.anti_aliasing = true
	return s


static func dim_rect(alpha: float = 0.55) -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(0.02, 0.06, 0.1, alpha)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	return c


static func centered(child: Control) -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(child)
	return c


static func pop_in(node: Control, delay: float = 0.0) -> void:
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(0.9, 0.9)
	node.modulate.a = 0.0
	var tw := node.create_tween().set_parallel(true)
	tw.tween_property(node, "scale", Vector2.ONE, 0.35).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "modulate:a", 1.0, 0.25).set_delay(delay)
