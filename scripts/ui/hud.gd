class_name Hud
extends Control
## Heads-up display: gold, chart progress, minimap, weather/wind badge, buttons
## and the discovery banners / arrival cards.

signal pause_pressed
signal chart_pressed

var sea: Sea
var minimap: ChartView
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
var _sb_card: StyleBoxFlat
var _hint_timer := 0.0
var _hints_done := {}

const MM_SIZE := 240.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sb_chip = _make_box(18, 0.93)
	_sb_card = _make_box(26, 0.97)

	pause_btn = IconButton.new("pause", 38.0)
	add_child(pause_btn)
	pause_btn.pressed.connect(func(): pause_pressed.emit())
	chart_btn = IconButton.new("scroll", 38.0)
	add_child(chart_btn)
	chart_btn.pressed.connect(func(): chart_pressed.emit())

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
	chart_btn.position = Vector2(pause_btn.position.x - chart_btn.size.x - 16.0, _margin.y)
	minimap.position = Vector2(right - MM_SIZE, _margin.y + pause_btn.size.y + 18.0)
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


func blockers() -> Array[Control]:
	return [pause_btn, chart_btn]


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
	# Gold chip.
	var gp := 1.0 + 0.12 * sin(minf(_gold_pop, 1.0) * PI)
	var gr := Rect2(m.x, m.y, 250.0, 64.0)
	draw_style_box(_sb_chip, gr)
	UiIcons.draw(self, "coin", gr.position + Vector2(38, 32), 22.0 * gp)
	draw_string(font, gr.position + Vector2(76, 43), str(int(round(_gold_shown))), HORIZONTAL_ALIGNMENT_LEFT, -1, int(38 * gp), UiIcons.INK)
	# Chart progress chip.
	var cr := Rect2(m.x, m.y + 78.0, 250.0, 64.0)
	draw_style_box(_sb_chip, cr)
	UiIcons.draw(self, "compass", cr.position + Vector2(38, 32), 22.0)
	draw_string(font, cr.position + Vector2(74, 30), "Charted", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.35, 0.22, 0.12))
	draw_string(font, cr.position + Vector2(168, 30), "%d%%" % int(round(_chart_shown)), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UiIcons.INK)
	var bar := Rect2(cr.position + Vector2(74, 40), Vector2(160, 10))
	draw_rect(bar, Color(0.35, 0.22, 0.12, 0.35))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(_chart_shown / 100.0, 0.0, 1.0), bar.size.y)), Color("2a7f62"))
	draw_rect(bar, Color("5a3a1e"), false, 2.0)
	# Places found.
	draw_string(font, Vector2(m.x + 6.0, m.y + 176.0), "Found %d" % sea.stats_pois_found, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, 0.9))

	# Minimap bezel.
	var mc := minimap.position + minimap.size * 0.5
	draw_circle(mc + Vector2(0, 4), MM_SIZE * 0.5 + 8.0, Color(0, 0, 0, 0.3))
	draw_arc(mc, MM_SIZE * 0.5 + 2.0, 0.0, TAU, 64, Color("5a3a1e"), 10.0, true)
	draw_arc(mc, MM_SIZE * 0.5 + 2.0, 0.0, TAU, 64, Color("e8b64a"), 4.0, true)
	var wa: float = sea.weather.wind.angle()
	# North marker on the bezel.
	draw_colored_polygon(PackedVector2Array([mc + Vector2(0, -MM_SIZE * 0.5 - 16.0), mc + Vector2(-8, -MM_SIZE * 0.5 - 2.0), mc + Vector2(8, -MM_SIZE * 0.5 - 2.0)]), Color("b23a2b"))

	# Weather badge, bottom right.
	var br := Vector2(size.x - m.z - 52.0, size.y - m.w - 52.0)
	var pop := 1.0 + 0.2 * sin(minf(_weather_pop, 1.0) * PI)
	draw_circle(br + Vector2(0, 4), 50.0, Color(0, 0, 0, 0.3))
	draw_circle(br, 48.0, Color("5a3a1e"))
	var bg := [Color("5db4e8"), Color("8e9ca6"), Color("5b7185"), Color("3a4658"), Color("16254a")]
	draw_circle(br, 44.0, bg[_weather_state])
	draw_arc(br, 44.0, 0.0, TAU, 32, Color("e8b64a"), 3.0, true)
	var icons := ["sun", "fog", "rain", "storm", "moon"]
	UiIcons.draw(self, icons[_weather_state], br, 30.0 * pop, UiIcons.INK, _t)
	var wname: String = Weather.NAMES[_weather_state]
	var ww := font.get_string_size(wname, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	draw_string(font, br + Vector2(-62.0 - ww + 2, 10 + 2), wname, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0, 0, 0, 0.55))
	draw_string(font, br + Vector2(-62.0 - ww, 10), wname, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
	# Wind dial.
	var wc := br + Vector2(0, -104.0)
	draw_circle(wc, 30.0, Color(0, 0.05, 0.1, 0.5))
	draw_arc(wc, 30.0, 0.0, TAU, 28, Color("e8b64a"), 2.5, true)
	var ws := clampf(sea.weather.wind.length(), 0.0, 1.2)
	var wdir := Vector2.from_angle(wa)
	var tip := wc + wdir * (10.0 + 14.0 * ws)
	draw_line(wc - wdir * 12.0, tip, Color(0.9, 0.97, 1.0), 3.0, true)
	draw_colored_polygon(PackedVector2Array([tip + wdir * 7.0, tip + wdir.rotated(2.4) * 8.0, tip + wdir.rotated(-2.4) * 8.0]), Color(0.9, 0.97, 1.0))
	draw_string(font, wc + Vector2(-17, 54), "Wind", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.85))

	_draw_banners(font, title_font)
	_draw_card(font, title_font)


func _draw_banners(font: Font, title_font: Font) -> void:
	var y := _margin.y + 395.0
	var cx := size.x * 0.5
	for b in _banners:
		var t: float = b["t"]
		var dur: float = b["dur"]
		var k := clampf(minf(t / 0.35, (dur - t) / 0.4), 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 3.0)
		var text: String = b["text"]
		var sub: String = b["sub"]
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
		var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x if sub != "" else 0.0
		var w := minf(maxf(tw, sw) + 120.0, size.x - 50.0)
		var h := 66.0 if sub == "" else 94.0
		var r := Rect2(cx - w * 0.5, y - (1.0 - e) * (h + 40.0), w, h)
		draw_style_box(_sb_chip, r)
		UiIcons.draw(self, b["icon"], r.position + Vector2(48, h * 0.5), 24.0, UiIcons.INK, _t)
		draw_string(font, r.position + Vector2(90, 42 if sub == "" else 38), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, UiIcons.INK)
		if sub != "":
			draw_string(font, r.position + Vector2(90, 72), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.35, 0.22, 0.12))
		y += (h + 12.0) * e


func _draw_card(font: Font, title_font: Font) -> void:
	if _card.is_empty():
		return
	var t: float = _card["t"]
	var dur: float = _card["dur"]
	var k := clampf(minf(t / 0.5, (dur - t) / 0.45), 0.0, 1.0)
	var e := 1.0 - pow(1.0 - k, 3.0)
	var width := minf(size.x - 70.0, 940.0)
	var text: String = _card["text"]
	var text_size := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width - 80.0, 28)
	var rumor: String = _card["rumor"]
	var rumor_size := font.get_multiline_string_size(rumor, HORIZONTAL_ALIGNMENT_LEFT, width - 80.0, 26) if rumor != "" else Vector2.ZERO
	var h := 130.0 + text_size.y + 24.0 + (rumor_size.y + 34.0 if rumor != "" else 0.0) + (76.0 if int(_card["gold"]) > 0 else 12.0)
	var base_y := size.y * 0.31 - h * 0.5
	var r := Rect2(size.x * 0.5 - width * 0.5, base_y + (1.0 - e) * 60.0, width, h)
	draw_style_box(_sb_card, r)
	draw_arc(r.position + Vector2(64, 62), 38.0, 0.0, TAU, 32, Color("e8b64a"), 4.0, true)
	draw_circle(r.position + Vector2(64, 62), 36.0, Color("d9c08a"))
	UiIcons.draw(self, _card["icon"], r.position + Vector2(64, 62), 24.0, UiIcons.INK, _t)
	draw_string(title_font, r.position + Vector2(120, 78), _card["title"], HORIZONTAL_ALIGNMENT_LEFT, width - 150.0, 50, UiIcons.INK)
	draw_multiline_string(font, r.position + Vector2(40, 130), text, HORIZONTAL_ALIGNMENT_LEFT, width - 80.0, 28, -1, Color(0.2, 0.12, 0.07))
	var y := 130.0 + text_size.y + 16.0
	if rumor != "":
		draw_multiline_string(font, r.position + Vector2(40, y + 22.0), rumor, HORIZONTAL_ALIGNMENT_LEFT, width - 80.0, 26, -1, Color(0.5, 0.18, 0.12))
		y += rumor_size.y + 26.0
	if int(_card["gold"]) > 0:
		var cw := 190.0
		var cr := Rect2(r.position.x + width * 0.5 - cw * 0.5, r.position.y + y + 4.0, cw, 50.0)
		draw_style_box(_sb_chip, cr)
		UiIcons.draw(self, "coin", cr.position + Vector2(32, 25), 18.0)
		draw_string(font, cr.position + Vector2(62, 35), "+%d" % int(_card["gold"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 32, UiIcons.INK)
