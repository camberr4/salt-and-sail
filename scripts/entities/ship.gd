class_name Ship
extends Node2D
## Sailing physics: the ship turns towards the stick, pushing further adds
## speed. Wind helps and hinders a little, land scrapes and slides.

signal scraped(strength: float, point: Vector2)

const MAX_SPEED := 238.0
const ACCEL := 105.0
const DECEL := 80.0
const TURN_RATE := 1.75
const TURN_ACCEL := 4.2

var world: WorldGen
var steer := Vector2.ZERO
var wind := Vector2.ZERO
var external := Vector2.ZERO
var heading := 0.0
var speed := 0.0
var ang_vel := 0.0
var heel := 0.0
var velocity := Vector2.ZERO
var control_enabled := true
var autopilot := false
var night := 0.0
var visual: ShipVisual

var _hull_points: Array[Vector2] = []
var _auto_target := 0.0
var _auto_t := 0.0
var _scrape_cd := 0.0


func _ready() -> void:
	visual = ShipVisual.new()
	add_child(visual)
	var hl := ShipVisual.HL * 0.86
	var hb := ShipVisual.HB * 0.8
	_hull_points = [
		Vector2(hl, 0), Vector2(hl * 0.62, hb * 0.55), Vector2(hl * 0.62, -hb * 0.55),
		Vector2(hl * 0.2, hb), Vector2(hl * 0.2, -hb), Vector2(-hl * 0.3, hb), Vector2(-hl * 0.3, -hb),
		Vector2(-hl * 0.8, hb * 0.75), Vector2(-hl * 0.8, -hb * 0.75), Vector2(-hl, 0),
	]


func place(pos: Vector2, p_heading: float) -> void:
	position = pos
	heading = p_heading
	rotation = heading
	speed = 0.0
	ang_vel = 0.0
	velocity = Vector2.ZERO
	external = Vector2.ZERO


func tick(dt: float) -> void:
	_scrape_cd = maxf(0.0, _scrape_cd - dt)
	var want := steer if control_enabled else Vector2.ZERO
	if autopilot:
		want = _autopilot(dt)
	var mag := minf(want.length(), 1.0)
	var diff := 0.0
	if mag > 0.1:
		diff = angle_difference(heading, want.angle())
		var cap := TURN_RATE * (0.5 + 0.5 * clampf(speed / 90.0, 0.0, 1.0))
		var desired := clampf(diff * 3.2, -cap, cap)
		ang_vel = move_toward(ang_vel, desired, TURN_ACCEL * dt)
	else:
		ang_vel = move_toward(ang_vel, 0.0, TURN_ACCEL * 0.6 * dt)
	heading = wrapf(heading + ang_vel * dt, -PI, PI)

	var target := 0.0
	if mag > 0.1:
		target = MAX_SPEED * clampf((mag - 0.12) / 0.8, 0.0, 1.0)
		target *= 1.0 - 0.32 * clampf(absf(diff) / PI, 0.0, 1.0)
		var fwd := Vector2.from_angle(heading)
		target *= 1.0 + 0.16 * wind.dot(fwd)
	speed = move_toward(speed, target, (ACCEL if target > speed else DECEL) * dt)

	var side_wind := wind.dot(Vector2.from_angle(heading + PI * 0.5))
	var heel_target := clampf(-ang_vel * 0.55 + side_wind * 0.22, -0.8, 0.8) * (0.4 + 0.6 * speed / MAX_SPEED)
	heel = lerpf(heel, heel_target, 1.0 - exp(-4.0 * dt))

	velocity = Vector2.from_angle(heading) * speed + external
	_move(velocity * dt)
	external = external.lerp(Vector2.ZERO, 1.0 - exp(-2.5 * dt))

	rotation = heading
	visual.speed01 = speed / MAX_SPEED
	visual.heel = heel
	visual.wind_local = wind.rotated(-heading)
	visual.night = night


func _move(step: Vector2) -> void:
	var p := position + step
	p.x = clampf(p.x, 140.0, WorldGen.WORLD_W - 140.0)
	p.y = clampf(p.y, 140.0, WorldGen.WORLD_H - 140.0)
	var hit := _push_out(p)
	if hit.length() > 0.0:
		p += hit
		var impact := clampf(speed / MAX_SPEED, 0.0, 1.0)
		if _scrape_cd <= 0.0 and impact > 0.12:
			_scrape_cd = 0.45
			scraped.emit(impact, p + Vector2.from_angle(heading) * ShipVisual.HL * 0.6)
		speed *= 0.82
		ang_vel += randf_range(-0.4, 0.4)
	position = p


## Returns the displacement needed to get the hull out of land.
func _push_out(p: Vector2) -> Vector2:
	var total := Vector2.ZERO
	for iter in 6:
		var push := Vector2.ZERO
		var count := 0
		var xf := Transform2D(heading, p + total)
		for hp in _hull_points:
			var wp := xf * hp
			if world.height_at(wp) > WorldGen.COLLIDE:
				push -= world.gradient_at(wp)
				count += 1
		if count == 0:
			break
		if push.length() < 0.00001:
			push = -Vector2.from_angle(heading)
		total += push.normalized() * 5.0
	return total


func _autopilot(dt: float) -> Vector2:
	_auto_t -= dt
	if _auto_t <= 0.0:
		_auto_t = randf_range(4.0, 9.0)
		_auto_target = heading + randf_range(-0.8, 0.8)
	var best := _auto_target
	var fwd := Vector2.from_angle(_auto_target)
	if world.march(position, fwd, 520.0) != Vector2.INF or not world.in_bounds(position + fwd * 520.0, 500.0):
		var best_clear := -1.0
		for a in [-0.5, 0.5, -1.0, 1.0, -1.6, 1.6, 2.6]:
			var d := Vector2.from_angle(_auto_target + a)
			var hit := world.march(position, d, 700.0)
			var clear := 700.0 if hit == Vector2.INF else position.distance_to(hit)
			if not world.in_bounds(position + d * 600.0, 500.0):
				clear *= 0.3
			if clear > best_clear:
				best_clear = clear
				best = _auto_target + a
		_auto_target = best
	return Vector2.from_angle(best) * 0.62
