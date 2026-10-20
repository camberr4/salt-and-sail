extends Node
## Top-level flow: boot -> title -> loading -> voyage (pause / chart) -> summary.

enum S { BOOT, TITLE, LOADING, VOYAGE, PAUSED, SUMMARY }

var sea: Sea
var hud_layer: CanvasLayer
var menu_layer: CanvasLayer
var joystick: Joystick
var hud: Hud
var title: TitleScreen
var loading: LoadingOverlay
var pause_menu: PauseMenu
var settings_panel: SettingsPanel
var chart_overlay: ChartOverlay
var summary: SummaryPanel
var state := S.BOOT

var _frames := 0
var _shot_frame := 0
var _opened_dev_ui := false
var _from_pause := false
var _perf_t0 := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().go_back_requested.connect(_on_back)
	if Dev.has("timescale"):
		Engine.time_scale = Dev.get_num("timescale", 1.0)

	sea = Sea.new()
	sea.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(sea)
	sea.fade = 1.0
	sea.weather_changed.connect(_on_weather_changed)
	sea.poi_visited.connect(func(_p, _r): pass)

	hud_layer = CanvasLayer.new()
	hud_layer.layer = 10
	hud_layer.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(hud_layer)
	var ui_root := Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.theme = Game.ui_theme
	hud_layer.add_child(ui_root)

	joystick = Joystick.new()
	ui_root.add_child(joystick)
	hud = Hud.new()
	ui_root.add_child(hud)
	hud.visible = false
	hud._alpha = 0.0
	hud.pause_pressed.connect(pause_game)
	hud.chart_pressed.connect(func(): pause_game(true))
	joystick.blockers = hud.blockers()
	joystick.enabled = false

	title = TitleScreen.new()
	ui_root.add_child(title)
	title.set_sail.connect(start_voyage)
	title.open_settings.connect(open_settings)
	title.quit_game.connect(func(): get_tree().quit())

	menu_layer = CanvasLayer.new()
	menu_layer.layer = 20
	menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(menu_layer)
	var menu_root := Control.new()
	menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_root.theme = Game.ui_theme
	menu_layer.add_child(menu_root)
	menu_layer.set_meta("root", menu_root)

	loading = LoadingOverlay.new()
	loading.process_mode = Node.PROCESS_MODE_ALWAYS
	var load_layer := CanvasLayer.new()
	load_layer.layer = 30
	add_child(load_layer)
	load_layer.add_child(loading)
	loading.show_overlay()

	sea.world_ready.connect(_on_world_ready)
	_boot()


func _boot() -> void:
	state = S.BOOT
	var title_seed := randi()
	if Dev.has("seed"):
		title_seed = int(Dev.get_num("seed"))
	var as_voyage := Dev.get_str("start", "title") == "voyage"
	sea.begin_world(title_seed, not as_voyage)


func _menu_root() -> Control:
	return menu_layer.get_meta("root")


func _on_world_ready() -> void:
	if state == S.BOOT:
		loading.hide_overlay()
		if Dev.get_str("start", "title") == "voyage":
			_begin_voyage_ui()
			create_tween().tween_property(sea, "fade", 0.0, 1.6)
		else:
			state = S.TITLE
			Sfx.music("title", 2.0)
			create_tween().tween_property(sea, "fade", 0.0, 1.8)
			title.intro()
	elif state == S.LOADING:
		_begin_voyage_ui()
		loading.hide_overlay()
		create_tween().tween_property(sea, "fade", 0.0, 2.0).set_delay(0.3)


# ------------------------------------------------------------------ flow

func start_voyage() -> void:
	if state != S.TITLE and state != S.SUMMARY:
		return
	_clear_summary()
	state = S.LOADING
	title.outro()
	Sfx.play("horn", -6.0)
	var tw := create_tween()
	tw.tween_property(sea, "fade", 1.0, 0.9)
	tw.tween_callback(func():
		loading.show_overlay()
		sea.begin_world(randi(), false))
	hud.set_shown(false)


func _begin_voyage_ui() -> void:
	state = S.VOYAGE
	Game.stats["voyages_started"] += 1
	Game.save()
	hud.bind(sea)
	hud.visible = true
	hud.set_shown(true)
	joystick.enabled = true
	joystick.cancel()
	if chart_overlay != null:
		chart_overlay.chart.rebind()
	Sfx.music_for_weather(sea.weather.state)
	Sfx.play("horn", -6.0)


func _on_weather_changed(s: int) -> void:
	if state == S.VOYAGE or state == S.PAUSED:
		Sfx.music_for_weather(s)


func pause_game(open_chart := false) -> void:
	if state != S.VOYAGE:
		return
	state = S.PAUSED
	get_tree().paused = true
	joystick.cancel()
	Sfx.play("click", -4.0)
	if open_chart:
		_from_pause = false
		_show_chart()
	else:
		_show_pause()


func resume_game() -> void:
	if state != S.PAUSED:
		return
	_free_menus()
	get_tree().paused = false
	state = S.VOYAGE


func _show_pause() -> void:
	_free_menus()
	pause_menu = PauseMenu.new()
	_menu_root().add_child(pause_menu)
	pause_menu.resume.connect(resume_game)
	pause_menu.open_chart.connect(func():
		_from_pause = true
		pause_menu.visible = false
		_show_chart())
	pause_menu.open_settings.connect(func():
		pause_menu.visible = false
		open_settings())
	pause_menu.end_voyage.connect(end_voyage)


func _show_chart() -> void:
	chart_overlay = ChartOverlay.new()
	_menu_root().add_child(chart_overlay)
	chart_overlay.open(sea)
	chart_overlay.closed.connect(func():
		chart_overlay.queue_free()
		chart_overlay = null
		if _from_pause and pause_menu != null:
			pause_menu.visible = true
		else:
			resume_game())


func open_settings() -> void:
	if settings_panel != null:
		return
	settings_panel = SettingsPanel.new()
	_menu_root().add_child(settings_panel)
	settings_panel.closed.connect(func():
		settings_panel.queue_free()
		settings_panel = null
		if pause_menu != null:
			pause_menu.visible = true)


func _free_menus() -> void:
	for n in [pause_menu, chart_overlay, settings_panel]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	pause_menu = null
	chart_overlay = null
	settings_panel = null


func end_voyage() -> void:
	_free_menus()
	get_tree().paused = false
	state = S.SUMMARY
	joystick.enabled = false
	joystick.cancel()
	hud.set_shown(false)
	Game.stats["voyages_finished"] += 1
	Game.stats["best_chart_pct"] = maxf(float(Game.stats["best_chart_pct"]), sea.world.fog.percent())
	Game.save()
	summary = SummaryPanel.new()
	summary.setup({
		"time": sea.elapsed,
		"gold": sea.gold,
		"found": sea.stats_pois_found,
		"chart": sea.world.fog.percent(),
	})
	_menu_root().add_child(summary)
	summary.again.connect(start_voyage)
	summary.menu.connect(back_to_title)
	Sfx.music("title", 2.0)


func _clear_summary() -> void:
	if summary != null and is_instance_valid(summary):
		summary.queue_free()
	summary = null


func back_to_title() -> void:
	_clear_summary()
	state = S.BOOT
	var tw := create_tween()
	tw.tween_property(sea, "fade", 1.0, 0.7)
	tw.tween_callback(func():
		loading.show_overlay()
		sea.begin_world(randi(), true))


# ------------------------------------------------------------------ input / lifecycle

func _on_back() -> void:
	match state:
		S.VOYAGE:
			pause_game()
		S.PAUSED:
			if settings_panel != null:
				settings_panel.closed.emit()
			elif chart_overlay != null:
				chart_overlay.closed.emit()
			elif pause_menu != null:
				pause_menu.back()
		S.TITLE:
			if settings_panel != null:
				settings_panel.closed.emit()
			else:
				get_tree().quit()
		S.SUMMARY:
			back_to_title()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_on_back()
		elif event.keycode == KEY_M and state == S.VOYAGE:
			pause_game(true)
		elif OS.is_debug_build() and state == S.VOYAGE:
			var names := {KEY_F1: 0, KEY_F2: 1, KEY_F3: 2, KEY_F4: 3, KEY_F5: 4}
			if names.has(event.keycode):
				sea.weather.set_state(names[event.keycode], 90.0)
			elif event.keycode == KEY_F6:
				sea.world.fog.reveal_all()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if state == S.VOYAGE and not Dev.has("shot"):
			pause_game()


func _process(_dt: float) -> void:
	if state == S.VOYAGE:
		sea.steer = Dev.get_vec("steer") if Dev.has("steer") else joystick.get_vector()
	else:
		sea.steer = Vector2.ZERO
	_dev_hooks()


## Command-line helpers used for automated screenshots.
func _dev_hooks() -> void:
	if sea.loading or sea.gen == null:
		return
	_frames += 1
	if not _opened_dev_ui and _frames > 30:
		_opened_dev_ui = true
		if Dev.has("autopilot"):
			sea.ship.autopilot = true
		match Dev.get_str("open", ""):
			"chart":
				pause_game(true)
			"pause":
				pause_game()
			"settings":
				if state == S.TITLE or state == S.VOYAGE:
					if state == S.VOYAGE:
						pause_game()
					open_settings()
			"summary":
				if state == S.VOYAGE:
					end_voyage()
		if Dev.get_str("do", "") == "sail" and state == S.TITLE:
			start_voyage()
	if Dev.has("dbg") and _frames == int(Dev.get_num("frames", 150)) - 1:
		for p in sea.pois:
			if p.position.distance_to(sea.ship.position) < 1500.0:
				print("poi ", p.kind, " disc=", p.discovered, " act=", p.active, " vis=", p.visible, " app=", p.appear, " pos=", p.position, " anchor=", p.anchor, " ship=", sea.ship.position)
	if Dev.has("simtouch") and state == S.VOYAGE:
		# Inject a touch + drag to verify the joystick end to end.
		if _frames == 45:
			var t := InputEventScreenTouch.new()
			t.index = 0
			t.position = Vector2(540, 1500)
			t.pressed = true
			Input.parse_input_event(t)
		elif _frames > 45 and _frames < 140 and _frames % 5 == 0:
			var d := InputEventScreenDrag.new()
			d.index = 0
			d.position = Vector2(540 + 90, 1500 - 40 - (_frames - 45))
			d.relative = Vector2(0, -5)
			Input.parse_input_event(d)
		if _frames % 20 == 0:
			print("f=", _frames, " joy=", joystick.get_vector(), " heading=", snappedf(sea.ship.heading, 0.01), " speed=", snappedf(sea.ship.speed, 0.1))
	if Dev.get_str("do", "") == "cycle":
		# Exercise the whole flow: voyage -> log -> new voyage -> log -> title.
		match _frames:
			60:
				if state == S.VOYAGE: end_voyage()
			90:
				if state == S.SUMMARY: summary.again.emit()
			400:
				if state == S.VOYAGE: end_voyage()
			430:
				if state == S.SUMMARY: summary.menu.emit()
		if _frames % 30 == 0:
			print("cycle f=", _frames, " state=", state)
	if Dev.has("dolphins") and _frames == 30:
		for i in 3:
			sea.ambient._try_spawn_pod(Vector2.from_angle(sea.ship.heading))
		sea.ambient._try_spawn_gulls()
	if Dev.has("perf"):
		if _frames == 60:
			_perf_t0 = Time.get_ticks_usec()
		elif _frames == 260:
			print("avg frame ms: ", snappedf((Time.get_ticks_usec() - _perf_t0) / 200000.0, 0.1), " quality=", Game.settings["quality"])
	if Dev.has("watch") and _frames % 15 == 0 and state == S.VOYAGE:
		var wp: Vector2 = Dev.get_vec("watch")
		print("f=", _frames, " dist=", snappedf(sea.ship.position.distance_to(wp), 1.0), " speed=", snappedf(sea.ship.speed, 1.0), " ext=", snappedf(sea.ship.external.length(), 1.0), " shake=", snappedf(sea.shake, 0.01))
	if Dev.has("dbg") and _frames == 40:
		print("vp ", get_viewport().get_visible_rect().size, " ui_root ", hud.get_parent().size, " hud ", hud.size, " title ", title.size, " joystick ", joystick.size)
	if Dev.has("shot"):
		var target := int(Dev.get_num("frames", 150))
		if _frames == target and (state == S.VOYAGE or state == S.TITLE or state == S.PAUSED or state == S.SUMMARY):
			get_viewport().get_texture().get_image().save_png(Dev.get_str("shot"))
			print("shot saved, state=", state, " found=", sea.stats_pois_found, " pos=", sea.ship.position, " weather=", sea.weather.state)
			get_tree().quit()
