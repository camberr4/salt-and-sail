class_name Weather
extends Node
## Weather state machine. Five states from the design doc (clear, fog, rain,
## storm, night). Every parameter eases towards the target state's profile so
## nothing ever pops, and the result is pushed into shader globals each frame.

signal state_changed(state: int, previous: int)
signal warning(next_state: int)
signal lightning(strength: float)
signal thunder(strength: float)

enum State { CLEAR, FOG, RAIN, STORM, NIGHT }

const NAMES := ["Clear skies", "Fog", "Rain", "Storm", "Night"]
const BLURBS := [
	"The sea is calm and the sky is wide.",
	"A thick fog swallows the horizon.",
	"Rain drums on the deck.",
	"A storm! Hold on tight.",
	"Night falls. Lanterns are lit.",
]

# vision = multiplier on how far the spyglass sees.
const PROFILES := {
	State.CLEAR: {"fog": 0.0, "rain": 0.0, "storm": 0.0, "night": 0.0, "wind": 0.38, "waves": 0.22, "vision": 1.0, "sat": 1.06, "clouds": 0.85, "warm": 0.35},
	State.FOG: {"fog": 0.92, "rain": 0.0, "storm": 0.0, "night": 0.0, "wind": 0.16, "waves": 0.1, "vision": 0.5, "sat": 0.62, "clouds": 0.0, "warm": 0.0},
	State.RAIN: {"fog": 0.3, "rain": 0.65, "storm": 0.0, "night": 0.0, "wind": 0.55, "waves": 0.45, "vision": 0.78, "sat": 0.82, "clouds": 0.5, "warm": 0.0},
	State.STORM: {"fog": 0.28, "rain": 1.0, "storm": 1.0, "night": 0.0, "wind": 1.0, "waves": 1.0, "vision": 0.62, "sat": 0.7, "clouds": 0.2, "warm": 0.0},
	State.NIGHT: {"fog": 0.0, "rain": 0.0, "storm": 0.0, "night": 1.0, "wind": 0.28, "waves": 0.2, "vision": 0.62, "sat": 0.95, "clouds": 0.0, "warm": 0.0},
}

const NEXT := {
	State.CLEAR: [[State.FOG, 0.25], [State.RAIN, 0.35], [State.NIGHT, 0.4]],
	State.FOG: [[State.CLEAR, 0.5], [State.RAIN, 0.2], [State.NIGHT, 0.3]],
	State.RAIN: [[State.STORM, 0.35], [State.CLEAR, 0.45], [State.FOG, 0.2]],
	State.STORM: [[State.RAIN, 0.6], [State.CLEAR, 0.4]],
	State.NIGHT: [[State.CLEAR, 0.45], [State.FOG, 0.25], [State.RAIN, 0.3]],
}

var state := State.CLEAR
var next_state := State.RAIN
var locked := false
var cur := {}
var wind_angle := 0.6
var wind := Vector2.RIGHT * 0.4
var flash := 0.0
var vision := 1.0
var time_left := 80.0
var gust := 0.0

var _t := 0.0
var _warned := false
var _bolt_timer := 5.0
var _pulses: Array[float] = []
var _rng := RandomNumberGenerator.new()
var _warm_override := -1.0


func _ready() -> void:
	_rng.randomize()
	cur = PROFILES[State.CLEAR].duplicate()
	_apply(1.0)


func start(initial: int = State.CLEAR, first_duration: float = 85.0, seed_value: int = 0) -> void:
	if seed_value != 0:
		_rng.seed = seed_value
	state = initial
	cur = PROFILES[state].duplicate()
	time_left = first_duration
	_warned = false
	next_state = _pick_next()
	wind_angle = _rng.randf() * TAU
	_apply(1.0)


func set_state(s: int, duration: float = 70.0, instant: bool = false) -> void:
	var prev := state
	state = s
	time_left = duration
	_warned = false
	next_state = _pick_next()
	if instant:
		cur = PROFILES[state].duplicate()
	if prev != s:
		state_changed.emit(s, prev)


func set_warm(v: float) -> void:
	_warm_override = v


func _pick_next() -> int:
	var opts: Array = NEXT[state]
	var total := 0.0
	for o in opts:
		total += o[1]
	var r := _rng.randf() * total
	for o in opts:
		r -= o[1]
		if r <= 0.0:
			return o[0]
	return opts[0][0]


func _process(dt: float) -> void:
	_t += dt
	if not locked:
		time_left -= dt
		if time_left < 14.0 and not _warned:
			_warned = true
			warning.emit(next_state)
		if time_left <= 0.0:
			set_state(next_state, _rng.randf_range(55.0, 95.0))
	var target: Dictionary = PROFILES[state]
	var rate := 1.0 - exp(-0.55 * dt)
	for k in target:
		cur[k] = lerpf(cur[k], target[k], rate)
	# Wind wanders; storms gust.
	wind_angle += (sin(_t * 0.05) * 0.03 + sin(_t * 0.13 + 1.7) * 0.02) * dt
	gust = lerpf(gust, maxf(0.0, sin(_t * 0.9) * sin(_t * 0.37 + 2.0)) * cur["storm"] * 0.6, 1.0 - exp(-2.0 * dt))
	var strength: float = cur["wind"] * (1.0 + 0.18 * sin(_t * 0.31) + gust)
	wind = Vector2.from_angle(wind_angle) * strength
	vision = cur["vision"]
	_update_lightning(dt)
	_apply(dt)


func _update_lightning(dt: float) -> void:
	flash = maxf(0.0, flash - dt * 4.2)
	if cur["storm"] > 0.6:
		_bolt_timer -= dt
		if _bolt_timer <= 0.0:
			_bolt_timer = _rng.randf_range(4.0, 11.0)
			var strength := _rng.randf_range(0.6, 1.0)
			flash = strength
			_pulses = [0.12, 0.28]
			lightning.emit(strength)
			var delay := _rng.randf_range(0.4, 2.4)
			get_tree().create_timer(delay).timeout.connect(func(): thunder.emit(strength))
	if _pulses.size() > 0:
		_pulses[0] -= dt
		if _pulses[0] <= 0.0:
			_pulses.pop_front()
			flash = maxf(flash, 0.55)


func _apply(_dt: float) -> void:
	Game.gset("g_wind", wind)
	Game.gset("g_rain", cur["rain"])
	Game.gset("g_storm", cur["storm"])
	Game.gset("g_fog", cur["fog"])
	Game.gset("g_night", cur["night"])
	Game.gset("g_waves", cur["waves"])
	Game.gset("g_sat", cur["sat"])
	Game.gset("g_clouds", cur["clouds"])
	Game.gset("g_warm", cur["warm"] if _warm_override < 0.0 else _warm_override)
