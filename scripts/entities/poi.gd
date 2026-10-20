class_name Poi
extends Node2D
## A point of interest on the map. Hidden under the fog until the ship's
## spyglass reaches it; then it pops into view and can be visited.

signal discovered_signal(poi: Poi)

const FLAVOR := {
	"village": [
		"Fishwives mend nets on the quay. One of them swears she saw something strange out past the reef.",
		"The harbourmaster tips his hat. \"Fair winds, captain. Mind the rocks east of here.\"",
		"A grizzled sailor buys you a round and sketches a rough chart on a coaster.",
		"Children race along the pier to wave at your ship. Their grandmother mutters about ghost lights.",
	],
	"lighthouse": [
		"You climb the spiral stair and light the great lamp. The mist peels back for miles around.",
		"The keeper is long gone, but the lens still turns. You polish it and the whole sea opens up.",
	],
	"treasure": [
		"A landing party digs beneath the red X. The spade rings on iron: a small, salt-stained chest!",
		"Under the shade of the palms your crew unearths a sack of coins. Somebody got here first, but not by much.",
		"The X marks a hollow. Inside: tarnished coins, a bent compass and a very angry crab.",
	],
	"skull": [
		"The jaw of the rock yawns open at low tide. Something glints between the teeth.",
		"Your crew refuses to land, so you row alone. The skull keeps its gold in its cheek.",
	],
	"wreck": [
		"You dive the ribs of the old hull and surface with a dripping coin purse.",
		"Barnacled and broken, she still has something in her bilge worth hauling up.",
		"Your best swimmer returns from the wreck with a lantern, a ring, and a story.",
	],
	"bottle": [
		"A scrap of tar-stained paper: a crude map and a name scratched out. Worth keeping.",
		"The note inside is soaked, but you can make out a coastline and a small black cross.",
		"Someone wanted this found. A few coins, and a hand-drawn sketch of a nearby shore.",
	],
	"wisps": [
		"The pale lights circle your bow, then dive. In the shallows you find a drowned lantern full of old coins.",
		"Cold blue flames lead you to a sunken chest. They vanish the moment you touch it.",
	],
}

var data := {}
var kind := ""
var poi_name := ""
var anchor := Vector2.ZERO
var interact_radius := 150.0
var discovered := false
var visited := false
var rumored := false
var appear := 0.0
var t := 0.0
var night := 0.0
var wind := Vector2.RIGHT * 0.3
var layout := {}
var normal_angle := 0.0
var active := false
var cooldown := 0.0

var _rng := RandomNumberGenerator.new()


func setup(d: Dictionary) -> void:
	data = d
	kind = d["kind"]
	poi_name = d["name"]
	position = d["art"]
	anchor = d["pos"]
	interact_radius = d["radius"]
	normal_angle = (d["normal"] as Vector2).angle()
	_rng.seed = d["seed"]
	t = _rng.randf() * 10.0
	layout = PoiArt.build(self, _rng)
	visible = false
	z_index = 1


func id() -> int:
	return data["id"]


func is_night_only() -> bool:
	return kind == "wisps"


func discover() -> void:
	if discovered:
		return
	discovered = true
	visible = active
	set_process(active)
	appear = 0.0
	discovered_signal.emit(self)


func set_active(on: bool) -> void:
	active = on
	visible = on and discovered
	set_process(on and discovered)


func _process(dt: float) -> void:
	t += dt
	cooldown = maxf(0.0, cooldown - dt)
	appear = move_toward(appear, 1.0, dt * 1.6)
	queue_redraw()


func _draw() -> void:
	if not discovered:
		return
	var k := appear
	# Overshoot ease so discoveries pop.
	var s := 1.0 + (sin(k * PI) * 0.18 if k < 1.0 else 0.0)
	var sc := clampf(k * 3.0, 0.0, 1.0) * s
	PoiArt.draw(self, sc)


func interact_text(rng: RandomNumberGenerator) -> String:
	var opts: Array = FLAVOR.get(kind, ["You look around."])
	return opts[rng.randi() % opts.size()]


## Distance from `p` to the nearest point the ship could interact from.
func distance_to_anchor(p: Vector2) -> float:
	return p.distance_to(anchor)
