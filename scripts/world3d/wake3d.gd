class_name Wake3D
extends MeshInstance3D
## Foam trail and bow wave laid on the water as animated ribbons.

const LIFE := 4.5
const SPACING := 0.5

var _pts: Array[Dictionary] = []
var _last := Vector2(1e9, 1e9)
var material: ShaderMaterial
var _mesh := ArrayMesh.new()


func _ready() -> void:
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/3d/wake.gdshader")
	material.set_shader_parameter("noise_tex", load("res://assets/textures/noise_atlas.png"))
	material.render_priority = 2
	material_override = material
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 200.0


func clear() -> void:
	_pts.clear()
	_last = Vector2(1e9, 1e9)


## pos in cells (x, z), heading in radians (+x toward +z), speed01 0..1.
func update_wake(pos: Vector2, heading: float, speed01: float, dt: float) -> void:
	for p in _pts:
		p["age"] += dt
	while _pts.size() > 0 and _pts[0]["age"] > LIFE:
		_pts.pop_front()
	var fwd := Vector2.from_angle(heading)
	var stern := pos - fwd * 3.2
	if speed01 > 0.03 and stern.distance_to(_last) >= SPACING:
		_pts.append({"pos": stern, "age": 0.0, "dir": heading, "pow": speed01})
		_last = stern
	_rebuild(pos, fwd, speed01)


func _rebuild(pos: Vector2, fwd: Vector2, speed01: float) -> void:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var y := 0.35
	var n := _pts.size()
	# Centre trail plus two diverging arms, as three ribbons sharing one mesh.
	var lanes := [[0.0, 1.0, 1.0], [1.0, 0.0, 0.55], [-1.0, 0.0, 0.55]]  # [side, centre weight, alpha]
	for lane in lanes:
		var base := verts.size()
		for i in range(n):
			var p: Dictionary = _pts[i]
			var k: float = float(p["age"]) / LIFE
			var nrm := Vector2.from_angle(float(p["dir"]) + PI * 0.5)
			var spread: float = float(lane[0]) * (0.7 + k * 5.0 * (0.6 + 0.4 * float(p["pow"])))
			var half: float = lerpf(0.7, 2.2, k) * (0.7 + 0.6 * float(p["pow"])) if lane[0] == 0.0 else lerpf(0.25, 0.8, k)
			var c: Vector2 = (p["pos"] as Vector2) + nrm * spread
			var a: float = float(lane[2]) * pow(1.0 - k, 1.1) * minf(1.0, 0.35 + float(p["pow"]))
			var left := c + nrm * half
			var right := c - nrm * half
			verts.append(Vector3(left.x, y, left.y))
			verts.append(Vector3(right.x, y, right.y))
			cols.append(Color(1, 1, 1, a))
			cols.append(Color(1, 1, 1, a))
			uvs.append(Vector2(0, float(i) * SPACING))
			uvs.append(Vector2(1, float(i) * SPACING))
		for i in range(n - 1):
			var o := base + i * 2
			idx.append_array([o, o + 2, o + 1, o + 1, o + 2, o + 3])
	# Bow wave: two foamy wedges.
	if speed01 > 0.05:
		var nrm2 := fwd.rotated(PI * 0.5)
		for s: float in [-1.0, 1.0]:
			var base2 := verts.size()
			for i in range(8):
				var f := float(i) / 7.0
				var c2: Vector2 = pos + fwd * 3.3 - fwd * f * 3.4 + nrm2 * s * (0.1 + f * 1.15)
				var w := 0.18 + f * 0.25
				var l: Vector2 = c2 + nrm2 * w
				var r: Vector2 = c2 - nrm2 * w
				verts.append(Vector3(l.x, y + 0.05, l.y))
				verts.append(Vector3(r.x, y + 0.05, r.y))
				var a2 := (0.85 - f * 0.65) * speed01
				cols.append(Color(1, 1, 1, a2))
				cols.append(Color(1, 1, 1, a2))
				uvs.append(Vector2(0, f * 3.0 + 40.0))
				uvs.append(Vector2(1, f * 3.0 + 40.0))
			for i in range(7):
				var o2 := base2 + i * 2
				idx.append_array([o2, o2 + 2, o2 + 1, o2 + 1, o2 + 2, o2 + 3])
	_mesh.clear_surfaces()
	if verts.size() < 3 or idx.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
