extends Node3D
var frames := 0
var gen: WorldGen
var world: SeaWorld
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
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.25
	sun.shadow_enabled = not Dev.has("noshadow")
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)
	var terrain := Terrain3D.new()
	add_child(terrain)
	terrain.build(gen, world)
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
	set_meta("water", water)
func _process(_d):
	frames += 1
	if frames == int(Dev.get_num("frames", 40)):
		get_viewport().get_texture().get_image().save_png(Dev.get_str("shot", "/tmp/work/p3d.png"))
		get_tree().quit()
