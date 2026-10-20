class_name SeaScene3D
extends Node3D
## The 3D half of the sea: lighting, terrain, trees, water, the ship and its
## wake, seen through a tilted orthographic camera. Orthographic means the
## ground plane maps to the screen with a plain affine transform, so the 2D
## overlay (points of interest, particles, gulls) lines up exactly.

const PITCH_DEG := 68.0
const SIN_P := 0.9272  # sin(68 deg)
const COS_P := 0.3746

var terrain: Terrain3D
var foliage: Foliage3D
var water: Water3D
var ship: Ship3D
var wake: Wake3D
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment

var _gen: WorldGen
var _ready_done := false
var _decals := {}
var _decal_mat := {}
var _decal_mesh_cache := {}


func _ready() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.09, 0.17)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.74, 0.9)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.basis = Basis.looking_at(Vector3(-0.35, -0.62, 0.7).normalized())
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.25
	sun.shadow_bias = 0.04
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 130.0
	add_child(sun)

	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.near = 1.0
	cam.far = 500.0
	cam.size = 50.0
	add_child(cam)
	cam.make_current()

	terrain = Terrain3D.new()
	add_child(terrain)
	foliage = Foliage3D.new()
	add_child(foliage)
	water = Water3D.new()
	add_child(water)
	ship = Ship3D.new()
	ship.visible = false
	add_child(ship)
	wake = Wake3D.new()
	add_child(wake)
	_ready_done = true
	Game.settings_changed.connect(_apply_quality)
	_apply_quality()


func _apply_quality() -> void:
	var q := int(Game.settings["quality"])
	sun.shadow_enabled = q >= 2
	if foliage != null:
		foliage.density = [0.55, 0.8, 1.0][q]


func setup(gen: WorldGen, world: SeaWorld) -> void:
	_gen = gen
	for mi in _decals.values():
		mi.queue_free()
	_decals.clear()
	terrain.clear()
	foliage.clear()
	terrain.build(gen, world)
	foliage.build(gen, world, load("res://assets/textures/noise_atlas.png"))
	water.setup(world)
	ship.bind_world(world)
	wake.clear()


## Builds everything around `center_px` immediately (used while the loading
## screen is up so the first frame already has islands and trees).
func prebuild(center_px: Vector2) -> void:
	var c := center_px / WorldGen.CELL
	for i in 6:
		terrain.update(c, 3, 100)
	foliage.update(c, 3, 100)


func update(dt: float, ship_px: Vector2, heading: float, speed01: float, wind_local: Vector2, heel: float, view_center_px: Vector2, zoom: float, view_px: Vector2, weather_cur: Dictionary, night: float) -> void:
	if not _ready_done or _gen == null:
		return
	var vc := view_center_px / WorldGen.CELL
	# Orthographic camera: `size` is the world width (units) across the screen.
	cam.size = view_px.x / zoom / WorldGen.CELL
	var dist := 160.0
	var target := Vector3(vc.x, 0.0, vc.y)
	cam.position = target + Vector3(0.0, SIN_P * dist, COS_P * dist)
	cam.look_at(target, Vector3.UP)

	var sc := ship_px / WorldGen.CELL
	terrain.update(vc, 3, 2)
	foliage.update(vc, 3, 2)
	water.follow(target)

	ship.visible = true
	ship.scale = Vector3.ONE * 1.6
	ship.position = Vector3(sc.x, ship.position.y, sc.y)
	ship.rotation.y = -heading
	ship.heel = heel
	ship.speed01 = speed01
	ship.wind_local = wind_local
	ship.waves = float(weather_cur.get("waves", 0.2))
	wake.update_wake(sc, heading, speed01, dt)

	# Light follows the weather; the 2D atmosphere pass does the heavy grading.
	var storm: float = weather_cur.get("storm", 0.0)
	var fog: float = weather_cur.get("fog", 0.0)
	var rain: float = weather_cur.get("rain", 0.0)
	sun.light_energy = 1.3 * (1.0 - 0.6 * storm - 0.4 * fog - 0.15 * rain - 0.6 * night)
	sun.light_color = Color(1.0, 0.95, 0.85).lerp(Color(0.7, 0.8, 1.0), night).lerp(Color(0.8, 0.85, 0.95), storm)
	env.ambient_light_energy = 0.55 + 0.1 * fog - 0.12 * night
	env.ambient_light_color = Color(0.62, 0.74, 0.9).lerp(Color(0.4, 0.5, 0.8), night)


# ------------------------------------------------------------------ painted POIs

const DECAL_Y := 0.75


## Lays a painted sprite flat on the sea at the point of interest. Returns false
## when no sprite exists for that kind (the 2D code-drawn art is used instead).
func add_poi_decal(p: Poi, world: SeaWorld) -> bool:
	if _decals.has(p):
		return true
	var file: String = PoiArt.SPRITE_FILE.get(p.kind, p.kind)
	var tex := Art.tex("poi/" + file)
	if tex == null:
		return false
	var ts := tex.get_size()
	var size: float = p.data.get("sprite_size", PoiArt.SPRITE_SIZE.get(p.kind, 400.0))
	if p.data.get("home", false) and not p.data.has("sprite_size"):
		size *= 1.2
	var hx := size * ts.x / maxf(ts.x, ts.y) / WorldGen.CELL * 0.5
	var hz := size * ts.y / maxf(ts.x, ts.y) / WorldGen.CELL * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [
		[Vector3(-hx, 0, -hz), Vector2(0, 0)], [Vector3(hx, 0, -hz), Vector2(1, 0)],
		[Vector3(-hx, 0, hz), Vector2(0, 1)], [Vector3(hx, 0, hz), Vector2(1, 1)],
	]
	for tri in [[0, 2, 1], [1, 2, 3]]:
		for i in tri:
			st.set_normal(Vector3.UP)
			st.set_uv(corners[i][1])
			st.add_vertex(corners[i][0])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/3d/decal.gdshader")
	var t := Art.tiled("poi/" + file)
	m.set_shader_parameter("decal_tex", t if t != null else tex)
	m.set_shader_parameter("height_tex", world.height_tex)
	m.set_shader_parameter("explored_tex", world.fog.texture)
	m.set_shader_parameter("noise_tex", load("res://assets/textures/noise_atlas.png"))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var c := p.position / WorldGen.CELL
	mi.position = Vector3(c.x, DECAL_Y, c.y)
	add_child(mi)
	_decals[p] = mi
	return true


func has_decal(p: Poi) -> bool:
	return _decals.has(p)


func update_decals(dt: float, t: float) -> void:
	for p in _decals:
		var mi: MeshInstance3D = _decals[p]
		mi.visible = p.discovered
		var rot := 0.0
		var y := DECAL_Y
		var a := 1.0
		match p.kind:
			"village":
				rot = 0.0 if p.data.get("stamped", false) else p.normal_angle - PI * 0.5
			"whirlpool":
				rot = p.t * 0.7
			"bottle":
				rot = 0.5 + sin(p.t * 1.1) * 0.2
				y += sin(p.t * 1.7) * 0.12
			"wisps":
				a = clampf(p.night * 1.4 - 0.2, 0.0, 1.0)
				mi.visible = mi.visible and a > 0.01
		mi.rotation.y = -rot
		mi.position.y = y
		var m := mi.material_override as ShaderMaterial
		m.set_shader_parameter("alpha_mul", minf(1.0, p.appear * 3.0) * a)
