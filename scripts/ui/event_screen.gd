class_name EventScreen
extends Control
## Encounter screen: painted illustration on top (assets/art/events/<art>.png,
## or a code-painted placeholder), story text, choices, then the outcome.

signal finished(outcome: Dictionary)

var ev: Dictionary
var gold := 0
var _rng := RandomNumberGenerator.new()
var _box: VBoxContainer
var _art: ArtPane
var _outcome := {}
var _t := 0.0


class ArtPane extends Control:
	var tex: Texture2D
	var tone := "sea"
	var title := ""
	var t := 0.0

	func _process(dt: float) -> void:
		t += dt
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if tex != null:
			var ts := tex.get_size()
			var k := maxf(size.x / ts.x, size.y / ts.y)
			var drawn := ts * k
			draw_texture_rect(tex, Rect2((size - drawn) * 0.5, drawn), false)
		else:
			_placeholder(r)
		# soft bottom fade so the title sits well
		for i in 6:
			var h := 40.0 + i * 16.0
			draw_rect(Rect2(0, size.y - h, size.x, h), Color(0.02, 0.04, 0.08, 0.1))

	func _placeholder(r: Rect2) -> void:
		var tops := {"sea": Color("2a79c4"), "fog": Color("8e9ca6"), "night": Color("0d1738"), "storm": Color("2b3548"), "tavern": Color("6b3b1c"), "gold": Color("c28b2c")}
		var bots := {"sea": Color("0b2a5a"), "fog": Color("4d5b66"), "night": Color("04081c"), "storm": Color("0e1420"), "tavern": Color("2a140a"), "gold": Color("5a3a10")}
		var top: Color = tops.get(tone, tops["sea"])
		var bot: Color = bots.get(tone, bots["sea"])
		var steps := 48
		for i in steps:
			var f := float(i) / steps
			draw_rect(Rect2(0, r.size.y * f, r.size.x, r.size.y / steps + 1.0), top.lerp(bot, f))
		# slow rays and drifting motes for life
		for i in 7:
			var a := -0.9 + i * 0.3 + sin(t * 0.3 + i) * 0.05
			var p0 := Vector2(size.x * 0.5, -40.0)
			var p1 := p0 + Vector2(sin(a), cos(a)) * size.y * 1.3
			draw_line(p0, p1, Color(1, 1, 1, 0.05), 90.0)
		for i in 22:
			var x := fmod(i * 97.3 + t * (6.0 + i % 5), size.x)
			var y := size.y * (0.25 + 0.6 * fmod(i * 0.37, 1.0)) + sin(t + i) * 8.0
			draw_circle(Vector2(x, y), 2.0 + i % 3, Color(1, 1, 1, 0.18))
		# a horizon and a ship silhouette
		var hy := size.y * 0.62
		draw_rect(Rect2(0, hy, size.x, size.y - hy), Color(0, 0.04, 0.12, 0.45))
		var sx := size.x * 0.5 + sin(t * 0.4) * 20.0
		var bob := sin(t * 1.3) * 4.0
		draw_colored_polygon(PackedVector2Array([Vector2(sx - 110, hy - 6 + bob), Vector2(sx + 110, hy - 6 + bob), Vector2(sx + 70, hy + 28 + bob), Vector2(sx - 80, hy + 28 + bob)]), Color(0.05, 0.03, 0.02, 0.9))
		draw_line(Vector2(sx, hy - 6 + bob), Vector2(sx, hy - 150 + bob), Color(0.05, 0.03, 0.02, 0.9), 5.0)
		draw_colored_polygon(PackedVector2Array([Vector2(sx + 4, hy - 140 + bob), Vector2(sx + 80, hy - 30 + bob), Vector2(sx + 4, hy - 20 + bob)]), Color(0.9, 0.88, 0.8, 0.85))
		draw_colored_polygon(PackedVector2Array([Vector2(sx - 4, hy - 120 + bob), Vector2(sx - 60, hy - 30 + bob), Vector2(sx - 4, hy - 20 + bob)]), Color(0.9, 0.88, 0.8, 0.8))


func setup(p_ev: Dictionary, p_gold: int) -> void:
	ev = p_ev
	gold = p_gold
	_rng.randomize()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.dim_rect(0.78))
	var panel := PanelContainer.new()
	var sb := UiKit.parchment_box()
	if sb is StyleBoxFlat:
		sb.content_margin_left = 0
		sb.content_margin_right = 0
		sb.content_margin_top = 0
		sb.content_margin_bottom = 28
		sb.set_corner_radius_all(30)
	else:
		sb.content_margin_left = 50
		sb.content_margin_right = 50
		sb.content_margin_top = 50
		sb.content_margin_bottom = 50
	panel.add_theme_stylebox_override("panel", sb)
	panel.clip_contents = true
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 36
	panel.offset_right = -36
	panel.offset_top = 90
	panel.offset_bottom = -90
	add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	panel.add_child(_box)
	_build_story()
	await get_tree().process_frame
	UiKit.pop_in(panel)


func _clear() -> void:
	for c in _box.get_children():
		c.queue_free()


func _make_art(title: String) -> ArtPane:
	var a := ArtPane.new()
	a.tex = Art.tex("events/" + str(ev.get("art", "")))
	a.tone = ev.get("tone", "sea")
	a.custom_minimum_size = Vector2(0, 520)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.size_flags_vertical = Control.SIZE_EXPAND_FILL
	a.clip_contents = true
	return a


func _pad(c: Control) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 44)
	m.add_theme_constant_override("margin_right", 44)
	m.add_child(c)
	return m


func _build_story() -> void:
	_clear()
	_art = _make_art(ev["title"])
	_box.add_child(_art)
	var title := UiKit.title(ev["title"], 72)
	_box.add_child(_pad(title))
	var text := UiKit.body(ev["text"], 34)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_box.add_child(_pad(text))
	for c in ev["choices"]:
		var cost: int = c.get("cost", 0)
		var b := UiKit.button(c["label"], false, 760.0)
		b.disabled = cost > gold
		if cost > gold:
			b.text = "%s  (need %d)" % [c["label"].split(" (")[0], cost]
		if c.has("hint"):
			b.text = "%s\n%s" % [c["label"], c["hint"]]
			b.add_theme_font_size_override("font_size", 34)
		b.pressed.connect(func(): _choose(c))
		_box.add_child(_pad(b))


func _choose(choice: Dictionary) -> void:
	_outcome = EventDb.roll(choice, _rng)
	_clear()
	_art = _make_art(ev["title"])
	_art.custom_minimum_size.y = 420
	_box.add_child(_art)
	_box.add_child(_pad(UiKit.title("What Happened", 64)))
	var text := UiKit.body(_outcome["text"], 36)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_box.add_child(_pad(text))
	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 20)
	var g: int = _outcome.get("gold", 0)
	if g != 0:
		chips.add_child(_chip(("+%d gold" if g > 0 else "%d gold") % g, Color("2a7f62") if g > 0 else Color("a02a20")))
	if _outcome.get("rumor", false):
		chips.add_child(_chip("A rumour", Color("5a3a8a")))
	if _outcome.get("reveal", 0) > 0:
		chips.add_child(_chip("Chart revealed", Color("2a5f9f")))
	if _outcome.has("weather"):
		chips.add_child(_chip("Weather turns", Color("5a6a7a")))
	if chips.get_child_count() > 0:
		_box.add_child(chips)
	var done := UiKit.button("Continue", true, 560.0)
	done.pressed.connect(func(): finished.emit(_outcome))
	var row := CenterContainer.new()
	row.add_child(done)
	_box.add_child(row)
	if g > 0:
		Sfx.play("coin", -3.0)
	elif g < 0:
		Sfx.play("splash", -6.0, 0.8)
	else:
		Sfx.play("arrive", -8.0)


func _chip(text: String, col: Color) -> Control:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	var sbc := StyleBoxFlat.new()
	sbc.bg_color = col
	sbc.set_corner_radius_all(18)
	sbc.content_margin_left = 24
	sbc.content_margin_right = 24
	sbc.content_margin_top = 8
	sbc.content_margin_bottom = 12
	l.add_theme_stylebox_override("normal", sbc)
	return l
