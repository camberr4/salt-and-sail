extends Node3D
var frames := 0
var gen: WorldGen
var world: SeaWorld
var foliage: Foliage3D
var ship3: Ship3D
var wake3: Wake3D
var ship_pos := Vector2.ZERO
var heading := 0.0
var cam_ref: Camera3D
func _ready():
	gen = WorldGen.new()
	gen.generate(int(Dev.get_num("seed", 7)))
	world = SeaWorld.new()
	add_child(world)
	world.setup(gen, false)
	world.set_reveal_all(true)
	var at: Vector2 = Dev.get_vec("at", gen.start_pos)
	Game.gset("g_ship", Vector4(at.x, at.y, 99999, 0))
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.03, 0.1, 0.2)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.74, 0.9)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 160, 0)
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.25
	sun.shadow_enabled = not Dev.has("noshadow")
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)
	var terrain := Terrain3D.new()
	add_child(terrain)
	var t0 := Time.get_ticks_msec()
	terrain.build(gen, world)
	print('terrain ms ', Time.get_ticks_msec() - t0)
	foliage = Foliage3D.new()
	add_child(foliage)
	foliage.build(gen, world, load("res://assets/textures/noise_atlas.png"))
	var water := Water3D.new()
	add_child(water)
	water.setup(world)
	var cam := Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = Dev.get_num("fov", 48)
	cam.near = 1.0
	cam.far = 600.0
	add_child(cam)
	var target := Space3D.to3(at)
	var pitch := deg_to_rad(Dev.get_num("pitch", 66))
	var dist := Dev.get_num("dist", 70)
	cam.position = target + Vector3(0, sin(pitch) * dist, cos(pitch) * dist)
	cam.look_at(target)
	water.follow(target)
	ship3 = Ship3D.new()
	add_child(ship3)
	ship3.bind_world(world)
	ship3.position = target
	wake3 = Wake3D.new()
	add_child(wake3)
	ship_pos = at
	heading = Dev.get_num("heading", -1.2)
	cam_ref = cam
	set_meta("water", water)
	set_meta("foliage", foliage)
	set_meta("at", at)
func _process(d):
	frames += 1
	if ship3 != null:
		var sp := 8.0 * 24.0 * Dev.get_num("speed", 1.0)
		ship_pos += Vector2.from_angle(heading) * sp * d
		var p3 := Space3D.to3(ship_pos)
		ship3.position = Vector3(p3.x, ship3.position.y, p3.z)
		ship3.rotation.y = -heading
		var w := Vector2.from_angle(Dev.get_num("wind", 2.0)) * Dev.get_num("ws", 0.6)
		ship3.wind_local = w.rotated(-heading)
		ship3.heel = Dev.get_num("heel", 0.08)
		ship3.speed01 = Dev.get_num("speed", 1.0)
		wake3.update_wake(ship_pos / 24.0, heading, Dev.get_num("speed", 1.0), d)
		var tgt := Space3D.to3(ship_pos)
		var pitch := deg_to_rad(Dev.get_num("pitch", 66))
		var dist := Dev.get_num("dist", 70)
		cam_ref.position = tgt + Vector3(0, sin(pitch) * dist, cos(pitch) * dist)
		cam_ref.look_at(tgt)
		Game.gset("g_ship", Vector4(ship_pos.x, ship_pos.y, 99999, 0))
		get_meta("water").follow(tgt)
		set_meta("at", ship_pos)
	var t1 := Time.get_ticks_msec()
	foliage.update(Vector2(get_meta("at")) / WorldGen.CELL, 3, 2)
	if frames % 20 == 0:
		print('frame ', frames, ' foliage ms ', Time.get_ticks_msec() - t1)
	if frames == int(Dev.get_num("frames", 90)):
		get_viewport().get_texture().get_image().save_png(Dev.get_str("shot", "/tmp/work/p3d.png"))
		get_tree().quit()
