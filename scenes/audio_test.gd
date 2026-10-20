extends Node
func _ready():
	for n in ["click","discover","coin","arrive","horn","scrape","splash","creak","thunder","amb_sea","amb_wind","amb_rain","amb_night"]:
		var s = Sfx._load("res://assets/audio/sfx/" + n)
		print(n, " ", s.get_class() if s else "MISSING", " len=", s.get_length() if s else 0, " loop=", s.loop if s is AudioStreamOggVorbis else "-")
	for n in ["title","calm","fog","rain","storm","night"]:
		var s = Sfx._load("res://assets/audio/music/" + n)
		print(n, " ", s.get_class() if s else "MISSING", " len=", s.get_length() if s else 0, " loop=", s.loop if s is AudioStreamOggVorbis else "-")
	Sfx.play("discover")
	Sfx.music("calm", 0.5)
	print("buses: ", AudioServer.bus_count)
	get_tree().quit()
