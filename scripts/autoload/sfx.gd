extends Node
## Audio: three buses (Music, Sfx, Ambience), a pooled one-shot player, looping
## weather ambience that follows the weather system, and a music director that
## crossfades between per-weather tracks. Missing files are skipped silently, so
## the game runs fine with any subset of the audio assets.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const POOL_SIZE := 14

var _cache := {}
var _pool: Array[AudioStreamPlayer] = []
var _amb := {}
var _music: Array[AudioStreamPlayer] = []
var _music_idx := 0
var _music_key := ""
var _music_tween: Tween
var _bus := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in ["Music", "Sfx", "Ambience"]:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, n)
		AudioServer.set_bus_send(i, "Master")
		_bus[n] = i
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Sfx"
		add_child(p)
		_pool.append(p)
	for name in ["sea", "wind", "rain", "night"]:
		var p := AudioStreamPlayer.new()
		p.bus = "Ambience"
		p.volume_db = -60.0
		add_child(p)
		var s := _load(SFX_DIR + "amb_" + name)
		if s != null:
			p.stream = s
			p.play()
		_amb[name] = p
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = "Music"
		m.volume_db = -60.0
		add_child(m)
		_music.append(m)
	apply_volumes()


func apply_volumes() -> void:
	if _bus.is_empty():
		return
	var s: Dictionary = Game.settings
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(s["master"]), 0.0001)))
	AudioServer.set_bus_volume_db(_bus["Music"], linear_to_db(maxf(float(s["music"]), 0.0001)))
	AudioServer.set_bus_volume_db(_bus["Sfx"], linear_to_db(maxf(float(s["sfx"]), 0.0001)))
	AudioServer.set_bus_volume_db(_bus["Ambience"], linear_to_db(maxf(float(s["sfx"]), 0.0001)))


func _load(path_no_ext: String) -> AudioStream:
	if _cache.has(path_no_ext):
		return _cache[path_no_ext]
	var stream: AudioStream = null
	for ext in [".ogg", ".wav"]:
		if ResourceLoader.exists(path_no_ext + ext):
			stream = load(path_no_ext + ext)
			break
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = path_no_ext.contains("amb_") or path_no_ext.contains("/music/")
	elif stream is AudioStreamWAV and (path_no_ext.contains("amb_") or path_no_ext.contains("/music/")):
		var w := stream as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = w.data.size() / (4 if w.stereo else 2) if w.format == AudioStreamWAV.FORMAT_16_BITS else w.data.size()
	_cache[path_no_ext] = stream
	return stream


func play(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var s := _load(SFX_DIR + name)
	if s == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = s
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return


## Smoothly drives the looping ambience from the weather profile.
func update_mix(cur: Dictionary, speed01: float, shake: float) -> void:
	var dt := get_process_delta_time()
	var k := 1.0 - exp(-2.0 * dt)
	var targets := {
		"sea": -16.0 + speed01 * 3.0 + cur["waves"] * 6.0,
		"wind": lerpf(-48.0, -9.0, clampf(float(cur["wind"]) / 1.0, 0.0, 1.0)),
		"rain": lerpf(-60.0, -7.0, float(cur["rain"])) if float(cur["rain"]) > 0.02 else -60.0,
		"night": lerpf(-60.0, -16.0, float(cur["night"])),
	}
	for n in targets:
		var p: AudioStreamPlayer = _amb[n]
		if p.stream != null:
			p.volume_db = lerpf(p.volume_db, targets[n], k)


func set_ambience_silent() -> void:
	for n in _amb:
		_amb[n].volume_db = -60.0


## Crossfade to the music track for `key` (title, calm, fog, rain, storm, night).
func music(key: String, fade: float = 3.0, volume_db: float = -6.0) -> void:
	if key == _music_key:
		return
	_music_key = key
	var s := _load(MUSIC_DIR + key)
	var old := _music[_music_idx]
	_music_idx = 1 - _music_idx
	var nw := _music[_music_idx]
	if _music_tween != null:
		_music_tween.kill()
	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_property(old, "volume_db", -60.0, fade)
	if s != null:
		nw.stream = s
		nw.volume_db = -60.0
		nw.play()
		_music_tween.tween_property(nw, "volume_db", volume_db, fade)
	_music_tween.chain().tween_callback(func(): if old.playing and old.volume_db <= -59.0: old.stop())


func music_for_weather(state: int) -> void:
	music(["calm", "fog", "rain", "storm", "night"][state])
