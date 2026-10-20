extends Node
## Global state: settings, save data, shared shader parameters, haptics.

signal settings_changed

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

const UI_GOLD := Color("e8b64a")
const UI_INK := Color("2b1d12")
const UI_PARCHMENT := Color("f1e2bd")
const UI_PARCHMENT_DARK := Color("d9c08a")
const UI_SEA := Color("0b2a3f")
const UI_RED := Color("b23a2b")

var settings := {
	"master": 0.9,
	"music": 0.7,
	"sfx": 0.9,
	"haptics": true,
	"joystick_size": 1.0,
	"quality": 1,  # 0 low, 1 medium, 2 high
	"fps30": false,
	"show_fps": false,
}

var stats := {
	"voyages_started": 0,
	"voyages_finished": 0,
	"total_gold": 0,
	"best_chart_pct": 0.0,
	"pois_found": 0,
	"seen_hints": [],
}

var title_font: Font
var logo_font: Font
var body_font: Font
var body_font_bold: Font
var ui_theme: Theme

# Shared shader globals. Written by the weather system / camera each frame.
const GLOBALS := {
	"g_wind": [RenderingServer.GLOBAL_VAR_TYPE_VEC2, Vector2(0.3, 0.1)],
	"g_rain": [RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0],
	"g_storm": [RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0],
	"g_fog": [RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0],
	"g_night": [RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0],
	"g_waves": [RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.3],
	"g_sat": [RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 1.0],
	"g_warm": [RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0],
	"g_clouds": [RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.7],
	"g_cam": [RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0, 0, 1, 1)],
	"g_ship": [RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0, 0, 700, 0)],
	"g_quality": [RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 1.0],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key in GLOBALS:
		RenderingServer.global_shader_parameter_add(key, GLOBALS[key][0], GLOBALS[key][1])
	_setup_input()
	_setup_fonts()
	_load()
	if not FileAccess.file_exists(SAVE_PATH):
		# First launch: pick a sensible quality tier.
		settings["quality"] = 1 if OS.has_feature("mobile") else 2
	if Dev.has("quality"):
		settings["quality"] = int(Dev.get_num("quality"))
	apply_settings()
	get_tree().set_auto_accept_quit(false)
	DisplayServer.screen_set_keep_on(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		save()
		AudioServer.set_bus_mute(0, true)
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		AudioServer.set_bus_mute(0, false)


func gset(name: StringName, value: Variant) -> void:
	RenderingServer.global_shader_parameter_set(name, value)


# ---------------------------------------------------------------- settings

func apply_settings() -> void:
	gset("g_quality", float(settings["quality"]))
	Engine.max_fps = 30 if settings["fps30"] else 60
	Sfx.apply_volumes()
	settings_changed.emit()


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	apply_settings()
	save()


func haptic(ms: int, amplitude: float = 0.5) -> void:
	if settings["haptics"] and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms, amplitude)


# ---------------------------------------------------------------- save / load

func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"version": SAVE_VERSION, "settings": settings, "stats": stats}))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	var s: Variant = data.get("settings", {})
	if typeof(s) == TYPE_DICTIONARY:
		for k in s:
			if settings.has(k):
				settings[k] = s[k]
	var st: Variant = data.get("stats", {})
	if typeof(st) == TYPE_DICTIONARY:
		for k in st:
			if stats.has(k):
				stats[k] = st[k]


func has_seen_hint(id: String) -> bool:
	return id in stats["seen_hints"]


func mark_hint(id: String) -> void:
	if not has_seen_hint(id):
		stats["seen_hints"].append(id)
		save()


# ---------------------------------------------------------------- input

func _setup_input() -> void:
	var map := {
		"steer_left": [KEY_A, KEY_LEFT],
		"steer_right": [KEY_D, KEY_RIGHT],
		"steer_up": [KEY_W, KEY_UP],
		"steer_down": [KEY_S, KEY_DOWN],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	# Gamepad left stick as a bonus.
	var axes := {
		"steer_left": [JOY_AXIS_LEFT_X, -1.0],
		"steer_right": [JOY_AXIS_LEFT_X, 1.0],
		"steer_up": [JOY_AXIS_LEFT_Y, -1.0],
		"steer_down": [JOY_AXIS_LEFT_Y, 1.0],
	}
	for action in axes:
		var ev := InputEventJoypadMotion.new()
		ev.axis = axes[action][0]
		ev.axis_value = axes[action][1]
		InputMap.action_add_event(action, ev)


# ---------------------------------------------------------------- fonts / theme

func _setup_fonts() -> void:
	title_font = load("res://assets/fonts/PirataOne-Regular.ttf")
	logo_font = load("res://assets/fonts/PlayfairDisplaySC-Bold.ttf")
	body_font = load("res://assets/fonts/Almendra-Regular.ttf")
	body_font_bold = load("res://assets/fonts/Almendra-Bold.ttf")
	ui_theme = _build_theme()


func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = body_font_bold
	t.default_font_size = 30
	t.set_color("font_color", "Label", UI_PARCHMENT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.55))
	t.set_constant("shadow_offset_x", "Label", 0)
	t.set_constant("shadow_offset_y", "Label", 2)

	var normal := _button_box(Color("5a3a1e"), Color("8c5d2e"), Color("20130a"))
	var hover := _button_box(Color("6d4624"), Color("a87636"), Color("20130a"))
	var pressed := _button_box(Color("3f2813"), Color("6b4724"), Color("20130a"))
	pressed.content_margin_top += 3
	pressed.content_margin_bottom -= 3
	var focus := StyleBoxEmpty.new()
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", UI_PARCHMENT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", UI_GOLD)
	t.set_font_size("font_size", "Button", 34)

	var sl := StyleBoxFlat.new()
	sl.bg_color = Color(0, 0, 0, 0.4)
	sl.set_corner_radius_all(8)
	sl.content_margin_top = 6
	sl.content_margin_bottom = 6
	t.set_stylebox("slider", "HSlider", sl)
	var grab := StyleBoxFlat.new()
	grab.bg_color = UI_GOLD
	grab.set_corner_radius_all(8)
	t.set_stylebox("grabber_area", "HSlider", grab)
	t.set_stylebox("grabber_area_highlight", "HSlider", grab)
	var knob := _knob_texture()
	t.set_icon("grabber", "HSlider", knob)
	t.set_icon("grabber_highlight", "HSlider", knob)
	t.set_icon("grabber_disabled", "HSlider", knob)
	t.set_constant("grabber_offset", "HSlider", 0)
	return t


func _button_box(fill: Color, border: Color, shadow: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(3)
	s.set_corner_radius_all(14)
	s.shadow_color = Color(shadow, 0.55)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 4)
	s.content_margin_left = 34
	s.content_margin_right = 34
	s.content_margin_top = 14
	s.content_margin_bottom = 18
	return s


func _knob_texture() -> Texture2D:
	var img := Image.create(56, 56, false, Image.FORMAT_RGBA8)
	for y in 56:
		for x in 56:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(28, 28))
			var a := clampf(27.0 - d, 0.0, 1.0)
			var ring := clampf(d - 18.0, 0.0, 1.0)
			var c := UI_GOLD.lerp(Color("7a4f1d"), ring)
			c.a = a
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
