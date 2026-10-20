extends Node2D
var frames := 0
var sea: Sea
func _ready():
	sea = Sea.new()
	add_child(sea)
	sea.begin_world(int(Dev.get_num("seed", 7)), Dev.has("title"))
	sea.steer = Vector2.from_angle(Dev.get_num("heading", 0.0)) * Dev.get_num("push", 0.0)
func _process(d):
	if sea.loading: return
	frames += 1
	if frames == int(Dev.get_num("frames", 120)):
		get_viewport().get_texture().get_image().save_png(Dev.get_str("shot", "/tmp/work/sea.png"))
		print("pois discovered: ", sea.stats_pois_found, " weather ", sea.weather.state, " pos ", sea.ship.position)
		get_tree().quit()
