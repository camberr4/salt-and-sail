extends Node2D
var frames := 0
func _ready():
	var g := WorldGen.new()
	g.generate(7)
	var world := SeaWorld.new()
	add_child(world)
	world.setup(g)
	world.set_reveal_all(true)
	var wake := Wake.new()
	add_child(wake)
	var ship := Ship.new()
	ship.world = g
	add_child(ship)
	var heading := Dev.get_num("heading", 0.3)
	ship.place(g.start_pos, heading)
	ship.wind = Vector2.from_angle(Dev.get_num("wind", 0.0)) * Dev.get_num("ws", 0.5)
	var cam := Camera2D.new()
	add_child(cam)
	var z := Dev.get_num("zoom", 2.0)
	cam.zoom = Vector2(z, z)
	cam.position = g.start_pos
	ship.steer = Vector2.from_angle(heading) * Dev.get_num("push", 1.0)
	Game.gset("g_ship", Vector4(g.start_pos.x, g.start_pos.y, 900, 0))
	Game.gset("g_wind", ship.wind)
	set_meta("ship", ship); set_meta("wake", wake); set_meta("cam", cam)
func _process(d):
	frames += 1
	var ship: Ship = get_meta("ship")
	ship.tick(minf(d, 0.05))
	(get_meta("wake") as Wake).update_wake(ship.position, ship.heading, ship.speed / Ship.MAX_SPEED, 0.3, d)
	(get_meta("cam") as Camera2D).position = ship.position
	if frames == int(Dev.get_num("frames", 90)):
		get_viewport().get_texture().get_image().save_png(Dev.get_str("shot", "/tmp/work/ship.png"))
		get_tree().quit()
