class_name Sea
extends Node2D
## The living sea: world, ship, points of interest, weather, camera and fx.
## Used by the title screen (autopilot, everything revealed) and by voyages.

signal world_ready
signal poi_discovered(poi: Poi)
signal poi_visited(poi: Poi, result: Dictionary)
signal gold_changed(total: int)
signal rumor_added(poi: Poi)
signal weather_changed(state: int)
signal weather_warning(next_state: int)
signal edge_reached

const VISION := 900.0

var gen: WorldGen
var world: SeaWorld
var wake: Wake
var poi_root: Node2D
var ship: Ship
var fx: Fx
var fx_add: Fx
var ambient: Ambient
var cam: Camera2D
var weather: Weather
var atmosphere: Atmosphere
var pois: Array[Poi] = []

var steer := Vector2.ZERO
var loading := false
var title_mode := false
var gold := 0
var elapsed := 0.0
var vision := 700.0
var fade := 0.0
var shake := 0.0
var stats_pois_found := 0
var stats_pois_visited := 0

var trail := PackedVector2Array()
var _task := -1
var _pending: WorldGen
var _seed := 0
var _spray_t := 0.0
var _bolt_flash := 0.0
var _flare := 0.0
var _flare_pos := Vector2.ZERO
var _flare_tick := 0.0
var _creak_t := 6.0
var _whirl_cd := 0.0
var _edge_cd := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	weather = Weather.new()
	add_child(weather)
	weather.state_changed.connect(func(s, _p): weather_changed.emit(s))
	weather.warning.connect(func(s): weather_warning.emit(s))
	weather.thunder.connect(func(st): Sfx.play("thunder", -4.0 + st * 2.0, randf_range(0.85, 1.05)))
	weather.lightning.connect(func(_s): shake = maxf(shake, 0.12))

	wake = Wake.new()
	add_child(wake)
	poi_root = Node2D.new()
	poi_root.z_index = 1
	add_child(poi_root)
	ship = Ship.new()
	ship.z_index = 3
	add_child(ship)
	ship.scraped.connect(_on_scraped)
	fx = Fx.new()
	fx.z_index = 4
	add_child(fx)
	fx_add = Fx.new()
	fx_add.additive = true
	fx_add.z_index = 5
	add_child(fx_add)
	ambient = Ambient.new()
	add_child(ambient)
	cam = Camera2D.new()
	cam.position_smoothing_enabled = false
	add_child(cam)
	cam.make_current()
	atmosphere = Atmosphere.new()
	add_child(atmosphere)
	ship.visible = false


# ------------------------------------------------------------------ world loading

## Generates a new archipelago on a worker thread, then calls world_ready.
func begin_world(p_seed: int, p_title: bool) -> void:
	loading = true
	title_mode = p_title
	_seed = p_seed
	var g := WorldGen.new()
	_pending = g
	_task = WorkerThreadPool.add_task(func(): g.generate(p_seed), false, "worldgen")


func _finish_world() -> void:
	gen = _pending
	if world != null:
		world.queue_free()
	for p in pois:
		p.queue_free()
	pois.clear()
	world = SeaWorld.new()
	add_child(world)
	move_child(world, 0)
	world.setup(gen)

	for d in gen.pois:
		var p := Poi.new()
		p.setup(d)
		poi_root.add_child(p)
		pois.append(p)
		p.discovered_signal.connect(_on_poi_discovered)

	ship.world = gen
	ship.visible = true
	ship.autopilot = title_mode
	var start := gen.start_pos
	var heading := gen.start_heading
	if Dev.has("at"):
		start = Dev.get_vec("at", start)
		heading = Dev.get_num("heading", heading)
	ship.place(start, heading)
	wake.clear()
	ambient.clear()
	ambient.gen = gen
	ambient.fx = fx
	gold = 0
	trail.clear()
	elapsed = 0.0
	stats_pois_found = 0
	stats_pois_visited = 0
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(WorldGen.WORLD_W)
	cam.limit_bottom = int(WorldGen.WORLD_H)
	cam.position = ship.position
	# Voyages open with a slow zoom in from a wide view of the harbour.
	cam.zoom = Vector2.ONE * (0.85 if title_mode else 0.52)

	if title_mode:
		world.set_reveal_all(true)
		vision = 7000.0
		weather.locked = true
		weather.start(Weather.State.CLEAR, 999.0, _seed)
		weather.set_warm(0.65)
	else:
		weather.locked = false
		weather.set_warm(-1.0)
		weather.start(Weather.State.CLEAR, _rng.randf_range(70.0, 90.0), _seed)
		vision = VISION
		world.fog.reveal(ship.position, vision, 120.0, 0.0)
	if Dev.has("weather"):
		var names := {"clear": 0, "fog": 1, "rain": 2, "storm": 3, "night": 4}
		weather.set_state(names.get(Dev.get_str("weather"), 0), 9999.0, true)
		weather.locked = true
	if Dev.has("reveal"):
		world.set_reveal_all(true)
	if Dev.has("discoverall"):
		for p in pois:
			p.discover()
			p.appear = 1.0
	loading = false
	world_ready.emit()


# ------------------------------------------------------------------ frame loop

func _process(delta: float) -> void:
	if loading:
		if _task != -1 and WorkerThreadPool.is_task_completed(_task):
			WorkerThreadPool.wait_for_task_completion(_task)
			_task = -1
			_finish_world()
		return
	if gen == null:
		return
	var dt := minf(delta, 0.05)
	elapsed += dt

	ship.wind = weather.wind
	ship.night = weather.cur["night"]
	ship.steer = steer
	ship.tick(dt)
	if trail.is_empty() or trail[trail.size() - 1].distance_to(ship.position) > 110.0:
		trail.append(ship.position)
		if trail.size() > 600:
			trail.remove_at(0)
	_update_whirlpools(dt)
	_update_edge(dt)
	_update_vision(dt)
	_update_pois(dt)
	_update_camera(dt)
	wake.update_wake(ship.position, ship.heading, ship.speed / Ship.MAX_SPEED, weather.cur["waves"], dt)
	_update_fx(dt)
	ambient.calm = clampf(1.0 - weather.cur["storm"] - weather.cur["rain"] * 0.4, 0.0, 1.0)
	ambient.night = weather.cur["night"]
	ambient.update(dt, ship.position, Vector2.from_angle(ship.heading))
	_update_atmosphere()
	Sfx.update_mix(weather.cur, ship.speed / Ship.MAX_SPEED, shake)


func _update_edge(dt: float) -> void:
	_edge_cd = maxf(0.0, _edge_cd - dt)
	if title_mode or _edge_cd > 0.0:
		return
	var p := ship.position
	var d := minf(minf(p.x, p.y), minf(WorldGen.WORLD_W - p.x, WorldGen.WORLD_H - p.y))
	if d < 420.0:
		_edge_cd = 25.0
		edge_reached.emit()


func _update_vision(dt: float) -> void:
	if title_mode:
		Game.gset("g_ship", Vector4(ship.position.x, ship.position.y, vision, 0))
		return
	var target := VISION * weather.vision
	vision = lerpf(vision, target, 1.0 - exp(-1.2 * dt))
	world.fog.reveal(ship.position, vision * 0.97, 110.0)
	if _flare > 0.0:
		_flare_tick -= dt
		if _flare_tick <= 0.0:
			_flare_tick = 0.1
			world.fog.reveal(_flare_pos, _flare, 200.0, 0.0)
	world.fog.flush()
	Game.gset("g_ship", Vector4(ship.position.x, ship.position.y, vision, 0))


func _update_pois(dt: float) -> void:
	var view := get_viewport().get_visible_rect().size / cam.zoom.x
	var c := cam.get_screen_center_position()
	var screen := Rect2(c - view * 0.5, view).grow(420.0)
	var night: float = weather.cur["night"]
	var sp := ship.position
	for p in pois:
		p.night = night
		p.wind = weather.wind
		var on := screen.has_point(p.position)
		if on != p.active:
			p.set_active(on)
		if title_mode:
			if not p.discovered and sp.distance_to(p.position) < 4000.0 and not p.is_night_only():
				p.discover()
			continue
		var d := minf(sp.distance_to(p.position), sp.distance_to(p.anchor))
		if not p.discovered:
			if p.is_night_only() and night < 0.65:
				continue
			if d < vision * 0.92:
				p.discover()
		elif not p.visited and p.kind != "whirlpool":
			if p.is_night_only() and night < 0.5:
				continue
			if sp.distance_to(p.anchor) < p.interact_radius:
				_visit(p)


func _update_camera(dt: float) -> void:
	var spd := ship.speed / Ship.MAX_SPEED
	var storm: float = weather.cur["storm"]
	var zoom_target := 0.9 - 0.05 * spd - 0.03 * storm
	if title_mode:
		zoom_target = 0.85
	cam.zoom = cam.zoom.lerp(Vector2.ONE * zoom_target, 1.0 - exp(-1.6 * dt))
	var target := ship.position + ship.velocity * 0.5
	cam.position = cam.position.lerp(target, 1.0 - exp(-3.0 * dt))
	var rough := shake + storm * 0.12
	# The ship sits below the middle of the screen so there is room to see
	# where it is heading (and for banners above it).
	var framing := Vector2.ZERO if title_mode else Vector2(0.0, -230.0)
	cam.offset = cam.offset.lerp(framing, 1.0 - exp(-4.0 * dt)) if rough < 0.01 else framing + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * rough * 14.0
	shake = move_toward(shake, 0.0, dt * 2.4)
	var c := cam.get_screen_center_position()
	Game.gset("g_cam", Vector4(c.x, c.y, cam.zoom.x, 0.0))
	world.sync_camera(c, cam.zoom.x)


func _update_fx(dt: float) -> void:
	var spd := ship.speed / Ship.MAX_SPEED
	var fwd := Vector2.from_angle(ship.heading)
	_spray_t -= dt
	if spd > 0.35 and _spray_t <= 0.0:
		_spray_t = lerpf(0.09, 0.03, spd)
		var bow := ship.position + fwd * (ShipVisual.HL - 6.0)
		fx.spray(bow + fwd.rotated(PI * 0.5) * randf_range(-6, 6), fwd.rotated(randf_range(-1.2, 1.2)), 1)
	# Foam bubbles drifting in the wake.
	if spd > 0.2 and randf() < 0.6 + spd:
		var stern := ship.position - fwd * 76.0 + fwd.rotated(PI * 0.5) * randf_range(-14.0, 14.0)
		fx.emit(Fx.Kind.DOT, stern, -fwd * randf_range(5.0, 25.0), randf_range(1.2, 2.6), randf_range(2.0, 4.0), randf_range(5.0, 9.0), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.0), 0.8)
	# Occasional creak of timber.
	_creak_t -= dt
	if _creak_t <= 0.0:
		_creak_t = randf_range(5.0, 11.0)
		if spd > 0.1:
			Sfx.play("creak", -9.0, randf_range(0.85, 1.15))


func _update_atmosphere() -> void:
	var c := cam.get_screen_center_position()
	var z := cam.zoom.x
	var view := get_viewport().get_visible_rect().size
	atmosphere.begin_frame()
	var fwd := Vector2.from_angle(ship.heading)
	var lantern: float = 1.0
	atmosphere.add_light(_to_screen(ship.position - fwd * 60.0, c, z, view), 320.0 * z, lantern, Color(1.0, 0.7, 0.38))
	atmosphere.add_light(_to_screen(ship.position + fwd * 70.0, c, z, view), 200.0 * z, 0.8, Color(1.0, 0.75, 0.42))
	var best_beam: Poi = null
	var best_d := 1e9
	for p in pois:
		if not p.active or not p.discovered:
			continue
		var sc := _to_screen(p.position, c, z, view)
		match p.kind:
			"village":
				atmosphere.add_light(sc, 340.0 * z, 0.9, Color(1.0, 0.75, 0.4))
			"lighthouse":
				atmosphere.add_light(sc, 190.0 * z, 0.6, Color(1.0, 0.92, 0.6))
				var d := p.position.distance_to(c)
				if d < best_d:
					best_d = d
					best_beam = p
			"skull":
				atmosphere.add_light(sc, 200.0 * z, 0.8, Color(0.45, 1.0, 0.65))
			"wisps":
				atmosphere.add_light(sc, 260.0 * z, clampf(p.night, 0.0, 1.0), Color(0.5, 0.9, 1.0))
			"bottle":
				atmosphere.add_light(sc, 120.0 * z, 0.5, Color(1.0, 0.9, 0.55))
	if best_beam != null:
		var intens := clampf(weather.cur["night"] + weather.cur["fog"] * 0.7 + weather.cur["storm"] * 0.4, 0.0, 1.0)
		atmosphere.set_beam(_to_screen(best_beam.position, c, z, view), best_beam.t * 0.85, intens)
	atmosphere.end_frame(view, weather.flash, fade)


func _to_screen(w: Vector2, c: Vector2, z: float, view: Vector2) -> Vector2:
	return (w - c) * z + view * 0.5


# ------------------------------------------------------------------ gameplay events

func _on_scraped(strength: float, point: Vector2) -> void:
	shake = maxf(shake, 0.25 + 0.5 * strength)
	fx.splinters(point, -Vector2.from_angle(ship.heading), 6 + int(6 * strength))
	fx.splash(point, 0.7)
	Sfx.play("scrape", -2.0 + strength * 3.0, randf_range(0.9, 1.1))
	Game.haptic(int(30 + 60 * strength), 0.3 + 0.5 * strength)


func _on_poi_discovered(p: Poi) -> void:
	if title_mode:
		return
	stats_pois_found += 1
	Game.stats["pois_found"] += 1
	fx_add.sparkles(p.position, 70.0, 14)
	Sfx.play("discover", -3.0)
	Game.haptic(20, 0.25)
	poi_discovered.emit(p)


func add_gold(n: int) -> void:
	gold += n
	Game.stats["total_gold"] += n
	gold_changed.emit(gold)


func _visit(p: Poi) -> void:
	p.visited = true
	stats_pois_visited += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = p.data["seed"]
	var res := {"title": p.poi_name, "text": p.interact_text(rng), "gold": 0, "kind": p.kind, "rumor": ""}
	var reward := 0
	match p.kind:
		"treasure":
			reward = rng.randi_range(90, 220)
		"skull":
			reward = rng.randi_range(120, 260)
		"wreck":
			reward = rng.randi_range(40, 140)
		"bottle":
			reward = rng.randi_range(15, 40)
			res["rumor"] = _make_rumor(p)
		"wisps":
			reward = rng.randi_range(150, 230)
		"village":
			res["rumor"] = _make_rumor(p)
			if p.data.get("home", false):
				res["text"] = "Port Brine: home. The harbourmaster waves you off with a pouch of bread and a warning about the weather."
		"lighthouse":
			_start_flare(p.position)
	res["gold"] = reward
	if reward > 0:
		add_gold(reward)
		fx.burst_gold(p.position if p.kind in ["treasure", "skull", "wisps"] else p.anchor, 20)
		Sfx.play("coin", -2.0)
	if p.kind == "lighthouse":
		Sfx.play("horn", -4.0)
	else:
		Sfx.play("arrive", -4.0)
	Game.haptic(35, 0.4)
	poi_visited.emit(p, res)


func _start_flare(pos: Vector2) -> void:
	_flare_pos = pos
	_flare = 0.0
	var tw := create_tween()
	tw.tween_method(func(v: float): _flare = v, 300.0, 2900.0, 2.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): _flare = 0.0)


func _make_rumor(source: Poi) -> String:
	var best: Poi = null
	var best_d := 1e9
	for p in pois:
		if p.discovered or p.rumored or p.kind == "bottle" or p.kind == "whirlpool" or p.is_night_only():
			continue
		var d := p.position.distance_to(source.position)
		if d < best_d and d < 7000.0:
			best_d = d
			best = p
	if best == null:
		return ""
	best.rumored = true
	rumor_added.emit(best)
	var dir := best.position - source.position
	var names := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
	var idx := int(round(dir.angle() / (PI / 4.0))) & 7
	var noun: String = {"village": "a harbour town", "lighthouse": "a lighthouse", "treasure": "a lonely islet with palms", "skull": "a rock shaped like a skull", "wreck": "a wreck"}.get(best.kind, "something")
	return "Rumour: %s lies far to the %s." % [noun.capitalize(), names[idx]]


func _update_whirlpools(dt: float) -> void:
	_whirl_cd = maxf(0.0, _whirl_cd - dt)
	if title_mode:
		return
	for p in pois:
		if p.kind != "whirlpool":
			continue
		var d := p.position - ship.position
		var dist := d.length()
		if dist > 330.0:
			continue
		var inward := d / maxf(dist, 1.0)
		var tangent := Vector2(-inward.y, inward.x)
		var k := 1.0 - dist / 330.0
		ship.external += (inward * 0.55 + tangent * 0.9) * 1700.0 * k * k * dt
		ship.speed = maxf(0.0, ship.speed - 150.0 * k * dt)
		ship.ang_vel += k * 0.8 * dt
		shake = maxf(shake, k * 0.35)
		if dist < 120.0 and _whirl_cd <= 0.0:
			_whirl_cd = 4.0
			ship.external = -inward * 520.0
			shake = 1.0
			fx.splash(ship.position, 1.6)
			Sfx.play("splash", 0.0, 0.8)
			Game.haptic(120, 0.8)
			if not p.visited:
				p.visited = true
				stats_pois_visited += 1
				poi_visited.emit(p, {"title": p.poi_name, "text": "The sea spins you round and spits you out. Your crew will be telling this one for years.", "gold": 0, "kind": "whirlpool", "rumor": ""})


# ------------------------------------------------------------------ helpers

func teleport(pos: Vector2) -> void:
	ship.place(pos, ship.heading)
	cam.position = pos
	wake.clear()


func nearest_poi_dir(kinds: Array = []) -> Poi:
	var best: Poi = null
	var best_d := 1e9
	for p in pois:
		if p.visited or (not kinds.is_empty() and not p.kind in kinds):
			continue
		var d := p.position.distance_to(ship.position)
		if d < best_d:
			best_d = d
			best = p
	return best
