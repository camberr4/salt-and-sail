extends Node2D
var frames := 0
var world: SeaWorld
var cam: Camera2D
func _ready():
	var t0 := Time.get_ticks_msec()
	var g := WorldGen.new()
	g.generate(int(Dev.get_num("seed", 7)))
	print("gen ms: ", Time.get_ticks_msec() - t0, " islands ", g.islands.size(), " pois ", g.pois.size())
	for p in g.pois:
		print(p["id"], " ", p["kind"], " ", p["name"], " ", p["pos"])
	world = SeaWorld.new()
	add_child(world)
	world.setup(g)
	world.set_reveal_all(Dev.has("reveal"))
	cam = Camera2D.new()
	add_child(cam)
	var at: Vector2 = Dev.get_vec("at", g.start_pos)
	cam.position = at
	var z := Dev.get_num("zoom", 1.0)
	cam.zoom = Vector2(z, z)
	Game.gset("g_ship", Vector4(at.x, at.y, 700, 0))
	Game.gset("g_quality", Dev.get_num("q", 2))
func _process(_d):
	frames += 1
	if frames == 8:
		get_viewport().get_texture().get_image().save_png(Dev.get_str("shot", "/tmp/work/terrain.png"))
		get_tree().quit()
