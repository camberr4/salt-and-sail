class_name Hud
extends Control
## Heads-up display: gold, chart progress, minimap, weather/wind badge, buttons
## and the discovery banners / arrival cards.

signal pause_pressed
signal chart_pressed

var sea: Sea
var minimap: ChartView
var minimap_hit: Button
var pause_btn: IconButton
var chart_btn: IconButton
var fps_label: Label

var _gold_shown := 0.0
var _gold_pop := 0.0
var _chart_shown := 0.0
var _banners: Array[Dictionary] = []
var _card := {}
var _t := 0.0
var _alpha := 1.0
var _weather_state := 0
var _weather_pop := 0.0
var _margin := Vector4(30, 24, 30, 24)
var _sb_chip: StyleBoxFlat
var _sb_dark: StyleBoxFlat
var _sb_card: StyleBoxFlat
var _hint_timer := 0.0
var _card_bottom := 0.0
var _hints_done := {}

const MM_SIZE := 270.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sb_chip = _make_box(18, 0.93)
	_sb_card = _make_box(26, 0.97)
	_sb_dark = StyleBoxFlat.new()
	_sb_dark.bg_color = Color(0.03, 0.07, 0.13, 0.84)
	_sb_dark.border_color = Color(0.7, 0.72, 0.75, 0.45)
	_sb_dark.set_border_width_all(2)
	_sb_dark.set_corner_radius_all(22)
	_sb_dark.shadow_color = Color(0, 0, 0, 0.35)
	_sb_dark.shadow_size = 6
	_sb_dark.shadow_offset = Vector2(0, 3)

	pause_btn = IconButton.new("pause", 54.0)
	add_child(pause_btn)
	pause_btn.pressed.connect(func(): pause_pressed.emit())
	chart_btn = IconButton.new("binoculars", 54.0)
	add_child(chart_btn)
	chart_btn.pressed.connect(func(): chart_pressed.emit())

	minimap_hit = Button.new()
	minimap_hit.flat = true
	minimap_hit.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "focus"]:
		minimap_hit.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	add_child(minimap_hit)
	minimap_hit.pressed.connect(func(): chart_pressed.emit())

	minimap = ChartView.new()
	minimap.minimap = true
	minimap.custom_minimum_size = Vector2.ONE * MM_SIZE
	minimap.size = Vector2.ONE * MM_SIZE
	add_child(minimap)

	fps_label = Label.new()
	fps_label.add_theme_font_size_override("font_size", 22)
	add_child(fps_label)
	resized.connect(_layout)
	Game.settings_changed.connect(func(): fps_label.visible = Game.settings["show_fps"])
	fps_label.visible = Game.settings["show_fps"]
	_layout()


func _make_box(radius: int, alpha: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.95, 0.88, 0.7, alpha)
	s.border_color = Color("5a3a1e")
	s.set_border_width_all(3)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 4)
	return s


func safe_margins() -> Vector4:
	var m := Vector4(30, 24, 30, 24)
	if OS.has_feature("mobile"):
		var win := Vector2(DisplayServer.window_get_size())
		var safe := DisplayServer.get_display_safe_area()
		if win.x > 0.0 and safe.size.x > 0:
			var sc := size / win
			m.x = maxf(m.x, safe.position.x * sc.x + 14.0)
			m.y = maxf(m.y, safe.position.y * sc.y + 10.0)
			m.z = maxf(m.z, (win.x - safe.end.x) * sc.x + 14.0)
			m.w = maxf(m.w, (win.y - safe.end.y) * sc.y + 10.0)
	return m


func _layout() -> void:
	_margin = safe_margins()
	var right := size.x - _margin.z
	pause_btn.position = Vector2(right - pause_btn.size.x, _margin.y)
	chart_btn.position = Vector2(pause_btn.position.x - chart_btn.size.x - 14.0, _margin.y)
	minimap.position = Vector2(right - MM_SIZE - 6.0, _margin.y + pause_btn.size.y + 26.0)
	minimap_hit.position = minimap.position
	minimap_hit.size = minimap.size
	fps_label.position = Vector2(_margin.x, size.y - _margin.w - 34.0)


func bind(p_sea: Sea) -> void:
	sea = p_sea
	_gold_shown = float(sea.gold)
	_chart_shown = 0.0
	_banners.clear()
	_card = {}
	_hint_timer = 0.0
	_hints_done.clear()
	minimap.bind(sea)
	_weather_state = sea.weather.state
	if not sea.poi_discovered.is_connected(_on_discovered):
		sea.poi_discovered.connect(_on_discovered)
		sea.poi_visited.connect(_on_visited)
		sea.gold_changed.connect(func(_g): _gold_pop = 1.0)
		sea.weather_changed.connect(_on_weather)
		sea.weather_warning.connect(_on_warning)
		sea.rumor_added.connect(func(_p): pass)
		sea.edge_reached.connect(func(): banner("The edge of the chart", "compass", "Nothing but mist beyond. Turn back, captain.", 4.5))


func blockers() -> Array[Control]:
	return [pause_btn, chart_btn, minimap_hit]


func set_shown(on: bool) -> void:
	var tw := create_tween()
	if on:
		visible = true
	tw.tween_property(self, "_alpha", 1.0 if on else 0.0, 0.5)
	if not on:
		tw.tween_callback(func(): visible = false)


# ------------------------------------------------------------------ toasts

func banner(text: String, icon: String, sub: String = "", dur: float = 3.2) -> void:
	_banners.append({"text": text, "icon": icon, "sub": sub, "t": 0.0, "dur": dur})
	while _banners.size() > 3:
		_banners.remove_at(0)


func card(title: String, text: String, gold: int, rumor: String, icon: String) -> void:
	_card = {"title": title, "text": text, "gold": gold, "rumor": rumor, "icon": icon, "t": 0.0, "dur": 7.5}


func _on_discovered(p: Poi) -> void:
	var verb := "Spotted" if p.kind in ["wreck", "bottle", "whirlpool"] else "Discovered"
	banner("%s: %s" % [verb, p.poi_name], p.kind, "", 3.0)
	if not _hints_done.has("chart") and not Game.has_seen_hint("chart"):
		_hints_done["chart"] = true
		get_tree().create_timer(3.5).timeout.connect(func(): banner("Tap the scroll to open your chart", "scroll", "", 4.0))
		Game.mark_hint("chart")


func _on_visited(p: Poi, res: Dictionary) -> void:
	var icon: String = res["kind"]
	if res["kind"] == "whirlpool":
		banner("You survived " + p.poi_name + "!", "whirlpool", "", 4.0)
		return
	card(res["title"], res["text"], res["gold"], res["rumor"], icon)


func _on_weather(state: int) -> void:
	_weather_state = state
	_weather_pop = 1.0
	if sea != null and not sea.title_mode:
		var icons := ["sun", "fog", "rain", "storm", "moon"]
		banner(Weather.NAMES[state], icons[state], Weather.BLURBS[state], 3.6)


func _on_warning(next_state: int) -> void:
	var msgs := [
		"The skies are clearing ahead.",
		"A bank of fog lies on the horizon.",
		"Dark clouds are gathering.",
		"The barometer is dropping fast. Storm ahead!",
		"The sun sinks towards the sea.",
	]
	var icons := ["sun", "fog", "rain", "storm", "moon"]
	banner("Weather change", icons[next_state], msgs[next_state], 4.0)


# ------------------------------------------------------------------ frame

func _process(dt: float) -> void:
	_t += dt
	modulate.a = _alpha
	if sea == null or sea.world == null:
		return
	_gold_shown = lerpf(_gold_shown, float(sea.gold), 1.0 - exp(-8.0 * dt))
	_gold_pop = maxf(0.0, _gold_pop - dt * 2.5)
	_weather_pop = maxf(0.0, _weather_pop - dt * 2.0)
	_chart_shown = lerpf(_chart_shown, sea.world.fog.percent(), 1.0 - exp(-4.0 * dt))
	for b in _banners:
		b["t"] += dt
	_banners = _banners.filter(func(b): return b["t"] < b["dur"])
	if not _card.is_empty():
		_card["t"] += dt
		if _card["t"] > _card["dur"]:
			_card = {}
	if Game.settings["show_fps"]:
		fps_label.text = "%d fps" % Engine.get_frames_per_second()
	_hint_timer += dt
	if _hint_timer > 7.0 and not _hints_done.has("explore") and not Game.has_seen_hint("explore") and not sea.title_mode:
		_hints_done["explore"] = true
		Game.mark_hint("explore")
		banner("Sail on to explore", "compass", "The fog lifts as you go. Look for islands and glints.", 5.0)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not _card.is_empty() and event is InputEventScreenTouch and event.pressed and _card["t"] > 0.8:
		_card["dur"] = _card["t"] + 0.3


func _draw() -> void:
	if sea == null or sea.world == null or sea.title_mode:
		return
	var font := Game.body_font_bold
	var title_font := Game.title_font
	var m := _margin
	# Gold chip: dark glass with a big coin.
	var gp := 1.0 + 0.12 * sin(minf(_gold_pop, 1.0) * PI)
	var gr := Rect2(m.x, m.y, 300.0, 84.0)
	draw_style_box(_sb_dark, gr)
	UiIcons.draw(self, "coin", gr.position + Vector2(46, 42), 31.0 * gp)
	draw_string(font, gr.position + Vector2(100, 58), str(int(round(_gold_shown))), HORIZONTAL_ALIGNMENT_LEFT, -1, int(48 * gp), Color("f4ecd8"))
	# Chart progress chip: parchment.
	var cr := Rect2(m.x, m.y + 98.0, 300.0, 92.0)
	draw_style_box(_sb_chip, cr)
	UiIcons.draw(self, "compass_diamond", cr.position + Vector2(46, 46), 28.0)
	draw_string(font, cr.position + Vector2(92, 42), "Charted", HORIZONTAL_ALIGNMENT_LEFT, -1, 31, UiIcons.INK)
	draw_string(font, cr.position + Vector2(212, 42), "%d%%" % int(round(_chart_shown)), HORIZONTAL_ALIGNMENT_LEFT, -1, 31, UiIcons.INK)
	var bar := Rect2(cr.position + Vector2(92, 60), Vector2(190, 9))
	draw_rect(bar, Color(0.35, 0.22, 0.12, 0.3))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(_chart_shown / 100.0, 0.0, 1.0), bar.size.y)), Color("c0892f"))
	# Places found.
	var ft := "Found %d" % sea.stats_pois_found
	draw_string(font, Vector2(m.x + 8.0 + 2, m.y + 240.0 + 2), ft, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(0, 0, 0, 0.5))
	draw_string(font, Vector2(m.x + 8.0, m.y + 240.0), ft, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(1, 1, 1, 0.95))

	# Minimap: thin brass ring, compass letters, menu knob.
	var mc := minimap.position + minimap.size * 0.5
	var mr := MM_SIZE * 0.5
	draw_circle(mc + Vector2(0, 4), mr + 8.0, Color(0, 0, 0, 0.3))
	draw_arc(mc, mr + 3.0, 0.0, TAU, 72, Color("2a2018"), 9.0, true)
	draw_arc(mc, mr + 3.0, 0.0, TAU, 72, Color("d9b45a"), 4.0, true)
	var wa: float = sea.weather.wind.angle()
	for ld in [["N", Vector2(0, -1)], ["E", Vector2(1, 0)], ["S", Vector2(0, 1)], ["W", Vector2(-1, 0)]]:
		var lp: Vector2 = mc + (ld[1] as Vector2) * (mr + 26.0)
		draw_string(font, lp + Vector2(-10, 10) + Vector2(2, 2), ld[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0, 0, 0, 0.6))
		draw_string(font, lp + Vector2(-10, 10), ld[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("f4ecd8"))
	var kb := mc + Vector2.from_angle(PI * 0.25) * (mr + 4.0)
	draw_circle(kb, 24.0, Color(0.03, 0.07, 0.13, 0.92))
	draw_arc(kb, 23.0, 0.0, TAU, 24, Color("d9b45a"), 3.0, true)
	UiIcons.draw(self, "menu", kb, 14.0, Color("f4ecd8"))

	# Wind and weather, stacked bottom right with labels underneath.
	var icons := ["sun", "fog", "rain", "storm", "moon"]
	var wname: String = Weather.NAMES[_weather_state]
	var bcx := size.x - m.z - 66.0
	var br := Vector2(bcx, size.y - m.w - 96.0)
	var pop := 1.0 + 0.2 * sin(minf(_weather_pop, 1.0) * PI)
	draw_circle(br + Vector2(0, 4), 64.0, Color(0, 0, 0, 0.3))
	var bgc := [Color("2b7fc0"), Color("52606c"), Color("34506a"), Color("27324a"), Color("141d44")]
	draw_circle(br, 60.0, Color(0.03, 0.07, 0.13, 0.92))
	draw_circle(br, 54.0, bgc[_weather_state])
	draw_arc(br, 58.0, 0.0, TAU, 40, Color(0.85, 0.87, 0.9, 0.6), 3.0, true)
	UiIcons.draw(self, icons[_weather_state], br, 38.0 * pop, UiIcons.INK, _t)
	var ww := font.get_string_size(wname, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	draw_string(font, Vector2(bcx - ww * 0.5 + 2, br.y + 100 + 2), wname, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(0, 0, 0, 0.6))
	draw_string(font, Vector2(bcx - ww * 0.5, br.y + 100), wname, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color.WHITE)
	var wc := br + Vector2(0, -150.0)
	draw_circle(wc + Vector2(0, 4), 52.0, Color(0, 0, 0, 0.3))
	draw_circle(wc, 52.0, Color(0.03, 0.07, 0.13, 0.9))
	draw_arc(wc, 50.0, 0.0, TAU, 40, Color(0.85, 0.87, 0.9, 0.6), 3.0, true)
	var ws := clampf(sea.weather.wind.length(), 0.0, 1.2)
	var wdir := Vector2.from_angle(wa)
	var tip := wc + wdir * (16.0 + 16.0 * ws)
	draw_line(wc - wdir * 22.0, tip, Color("f4ecd8"), 5.0, true)
	draw_colored_polygon(PackedVector2Array([tip + wdir * 14.0, tip + wdir.rotated(2.3) * 15.0, tip + wdir.rotated(-2.3) * 15.0]), Color("f4ecd8"))
	draw_string(font, Vector2(bcx - 34 + 2, wc.y + 80 + 2), "Wind", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0, 0, 0, 0.6))
	draw_string(font, Vector2(bcx - 34, wc.y + 80), "Wind", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)

	_draw_banners(font, title_font)
	_draw_card(font, title_font)


func _draw_banners(font: Font, title_font: Font) -> void:
	var y := maxf(_margin.y + 440.0, _card_bottom + 16.0)
	var cx := size.x * 0.5
	for b in _banners:
		var t: float = b["t"]
		var dur: float = b["dur"]
		var k := clampf(minf(t / 0.35, (dur - t) / 0.4), 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 3.0)
		var text: String = b["text"]
		var sub: String = b["sub"]
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x
		var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x if sub != "" else 0.0
		var w := minf(maxf(tw, sw) + 140.0, size.x - 50.0)
		var h := 84.0 if sub == "" else 120.0
		var r := Rect2(cx - w * 0.5, y - (1.0 - e) * (h + 40.0), w, h)
		draw_style_box(_sb_chip, r)
		UiIcons.draw(self, b["icon"], r.position + Vector2(52, h * 0.5), 28.0, UiIcons.INK, _t)
		draw_string(font, r.position + Vector2(100, 54 if sub == "" else 50), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, UiIcons.INK)
		if sub != "":
			draw_string(font, r.position + Vector2(100, 92), sub, HORIZONTAL_ALIGNMENT_LEFT, w - 120.0, 28, Color(0.35, 0.22, 0.12))
		y += (h + 12.0) * e


func _draw_card(font: Font, title_font: Font) -> void:
	if _card.is_empty():
		_card_bottom = 0.0
		return
	var t: float = _card["t"]
	var dur: float = _card["dur"]
	var k := clampf(minf(t / 0.5, (dur - t) / 0.45), 0.0, 1.0)
	var e := 1.0 - pow(1.0 - k, 3.0)
	var width := minf(size.x - 70.0, 940.0)
	var text: String = _card["text"]
	var text_size := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width - 80.0, 34)
	var rumor: String = _card["rumor"]
	var rumor_size := font.get_multiline_string_size(rumor, HORIZONTAL_ALIGNMENT_LEFT, width - 80.0, 32) if rumor != "" else Vector2.ZERO
	var h := 150.0 + text_size.y + 24.0 + (rumor_size.y + 34.0 if rumor != "" else 0.0) + (92.0 if int(_card["gold"]) > 0 else 16.0)
	var base_y := size.y * 0.345 - h * 0.5
	var r := Rect2(size.x * 0.5 - width * 0.5, base_y + (1.0 - e) * 60.0, width, h)
	_card_bottom = r.end.y
	draw_style_box(_sb_card, r)
	draw_arc(r.position + Vector2(72, 70), 44.0, 0.0, TAU, 32, Color("e8b64a"), 4.0, true)
	draw_circle(r.position + Vector2(72, 70), 42.0, Color("d9c08a"))
	UiIcons.draw(self, _card["icon"], r.position + Vector2(72, 70), 28.0, UiIcons.INK, _t)
	draw_string(title_font, r.position + Vector2(136, 88), _card["title"], HORIZONTAL_ALIGNMENT_LEFT, width - 170.0, 62, UiIcons.INK)
	draw_multiline_string(font, r.position + Vector2(40, 152), text, HORIZONTAL_ALIGNMENT_LEFT, width - 80.0, 34, -1, Color(0.2, 0.12, 0.07))
	var y := 150.0 + text_size.y + 16.0
	if rumor != "":
		draw_multiline_string(font, r.position + Vector2(40, y + 26.0), rumor, HORIZONTAL_ALIGNMENT_LEFT, width - 80.0, 32, -1, Color(0.5, 0.18, 0.12))
		y += rumor_size.y + 34.0
	if int(_card["gold"]) > 0:
		var cw := 230.0
		var cr := Rect2(r.position.x + width * 0.5 - cw * 0.5, r.position.y + y + 6.0, cw, 64.0)
		draw_style_box(_sb_chip, cr)
		UiIcons.draw(self, "coin", cr.position + Vector2(38, 32), 22.0)
		draw_string(font, cr.position + Vector2(76, 46), "+%d" % int(_card["gold"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 42, UiIcons.INK)
