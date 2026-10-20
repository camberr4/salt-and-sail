class_name Fx
extends Node2D
## Tiny pooled particle system drawn in a single _draw call: spray, sparkles,
## smoke, splinters, ripples, coins. One instance is normal-blended, another
## additive (set `additive` before adding to the tree).

enum Kind { DOT, RING, STAR, SPLINTER, SMOKE }

const MAX := 700

var additive := false

var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _life := PackedFloat32Array()
var _max_life := PackedFloat32Array()
var _s0 := PackedFloat32Array()
var _s1 := PackedFloat32Array()
var _drag := PackedFloat32Array()
var _grav := PackedFloat32Array()
var _rot := PackedFloat32Array()
var _rotv := PackedFloat32Array()
var _c0 := PackedColorArray()
var _c1 := PackedColorArray()
var _kind := PackedInt32Array()
var _count := 0


func _ready() -> void:
	if additive:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = m
	for arr in [_pos, _vel, _life, _max_life, _s0, _s1, _drag, _grav, _rot, _rotv, _c0, _c1, _kind]:
		arr.resize(MAX)


func emit(kind: int, pos: Vector2, vel: Vector2, life: float, s0: float, s1: float, c0: Color, c1: Color, drag: float = 0.0, grav: Vector2 = Vector2.ZERO, rotv: float = 0.0) -> void:
	if _count >= MAX:
		return
	var i := _count
	_count += 1
	_pos[i] = pos
	_vel[i] = vel
	_life[i] = life
	_max_life[i] = life
	_s0[i] = s0
	_s1[i] = s1
	_c0[i] = c0
	_c1[i] = c1
	_drag[i] = drag
	_grav[i] = grav.y  # only used as a scalar "rise" for smoke
	_rot[i] = randf() * TAU
	_rotv[i] = rotv
	_kind[i] = kind


func _process(delta: float) -> void:
	var i := 0
	while i < _count:
		_life[i] -= delta
		if _life[i] <= 0.0:
			_count -= 1
			if i != _count:
				_swap(i, _count)
			continue
		_vel[i] *= maxf(0.0, 1.0 - _drag[i] * delta)
		_vel[i].y += _grav[i] * delta
		_pos[i] += _vel[i] * delta
		_rot[i] += _rotv[i] * delta
		i += 1
	queue_redraw()


func _swap(a: int, b: int) -> void:
	_pos[a] = _pos[b]
	_vel[a] = _vel[b]
	_life[a] = _life[b]
	_max_life[a] = _max_life[b]
	_s0[a] = _s0[b]
	_s1[a] = _s1[b]
	_drag[a] = _drag[b]
	_grav[a] = _grav[b]
	_rot[a] = _rot[b]
	_rotv[a] = _rotv[b]
	_c0[a] = _c0[b]
	_c1[a] = _c1[b]
	_kind[a] = _kind[b]


func _draw() -> void:
	for i in range(_count):
		var k := 1.0 - _life[i] / _max_life[i]
		var s := lerpf(_s0[i], _s1[i], k)
		var c := _c0[i].lerp(_c1[i], k)
		match _kind[i]:
			Kind.DOT, Kind.SMOKE:
				draw_circle(_pos[i], s, c)
			Kind.RING:
				draw_arc(_pos[i], s, 0.0, TAU, 24, c, maxf(1.0, 3.0 * (1.0 - k)), true)
			Kind.STAR:
				var r := s
				var d := Vector2.from_angle(_rot[i])
				var e := d.rotated(PI * 0.5)
				draw_line(_pos[i] - d * r, _pos[i] + d * r, c, 2.0)
				draw_line(_pos[i] - e * r, _pos[i] + e * r, c, 2.0)
				draw_circle(_pos[i], r * 0.35, c)
			Kind.SPLINTER:
				var d2 := Vector2.from_angle(_rot[i]) * s
				draw_line(_pos[i] - d2, _pos[i] + d2, c, 2.4)


# ---------------------------------------------------------------- recipes

func spray(pos: Vector2, dir: Vector2, amount: int = 3) -> void:
	for n in amount:
		var a := dir.rotated(randf_range(-0.7, 0.7)) * randf_range(40.0, 120.0)
		emit(Kind.DOT, pos + Vector2(randf_range(-3, 3), randf_range(-3, 3)), a, randf_range(0.35, 0.7), randf_range(2.0, 3.6), 0.6, Color(1, 1, 1, 0.8), Color(0.9, 0.97, 1, 0.0), 2.0)


func splash(pos: Vector2, size: float = 1.0) -> void:
	emit(Kind.RING, pos, Vector2.ZERO, 0.9, 6.0 * size, 46.0 * size, Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.0))
	for n in int(10 * size):
		var a := Vector2.from_angle(randf() * TAU) * randf_range(30.0, 130.0) * size
		emit(Kind.DOT, pos, a, randf_range(0.4, 0.8), randf_range(2.0, 3.4), 0.5, Color(1, 1, 1, 0.9), Color(0.85, 0.95, 1, 0), 2.5)


func sparkles(pos: Vector2, radius: float, amount: int = 14, col: Color = Color(1.0, 0.9, 0.5)) -> void:
	for n in amount:
		var p := pos + Vector2.from_angle(randf() * TAU) * randf() * radius
		var v := Vector2(randf_range(-10, 10), randf_range(-34, -8))
		emit(Kind.STAR, p, v, randf_range(0.6, 1.4), randf_range(3.0, 7.0), 0.5, Color(col, 1.0), Color(col, 0.0), 0.5, Vector2.ZERO, randf_range(-2.0, 2.0))


func burst_gold(pos: Vector2, amount: int = 18) -> void:
	for n in amount:
		var v := Vector2.from_angle(randf() * TAU) * randf_range(60.0, 220.0)
		emit(Kind.DOT, pos, v, randf_range(0.7, 1.3), randf_range(3.0, 5.0), 1.5, Color(1.0, 0.82, 0.25, 1.0), Color(1.0, 0.7, 0.2, 0.0), 2.2)
	sparkles(pos, 40.0, 8)


func splinters(pos: Vector2, dir: Vector2, amount: int = 8) -> void:
	for n in amount:
		var v := dir.rotated(randf_range(-1.0, 1.0)) * randf_range(60.0, 180.0)
		emit(Kind.SPLINTER, pos, v, randf_range(0.5, 1.0), randf_range(3.0, 6.0), 2.0, Color(0.55, 0.36, 0.18, 1), Color(0.4, 0.25, 0.12, 0), 1.8, Vector2.ZERO, randf_range(-8, 8))


func smoke(pos: Vector2, wind: Vector2, strength: float = 1.0) -> void:
	emit(Kind.SMOKE, pos, wind * 26.0 + Vector2(randf_range(-4, 4), -14.0), randf_range(2.2, 3.4), 3.0 * strength, 15.0 * strength, Color(0.92, 0.92, 0.94, 0.38), Color(0.8, 0.82, 0.86, 0.0), 0.4)


func ripple(pos: Vector2, size: float = 1.0, col: Color = Color(1, 1, 1, 0.6)) -> void:
	emit(Kind.RING, pos, Vector2.ZERO, 1.4, 4.0 * size, 60.0 * size, col, Color(col, 0.0))
