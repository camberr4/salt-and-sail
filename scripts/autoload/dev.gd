extends Node
## Developer switches passed after `--` on the command line, e.g.
##   godot --path . -- --shot=/tmp/a.png --weather=storm --at=3000,2000
## Harmless in release builds: Android never passes user args.

var args := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"


func has(key: String) -> bool:
	return args.has(key)


func get_str(key: String, default: String = "") -> String:
	return args.get(key, default)


func get_num(key: String, default: float = 0.0) -> float:
	return float(args[key]) if args.has(key) else default


func get_vec(key: String, default: Vector2 = Vector2.ZERO) -> Vector2:
	if not args.has(key):
		return default
	var p: PackedStringArray = args[key].split(",")
	return Vector2(float(p[0]), float(p[1])) if p.size() >= 2 else default
