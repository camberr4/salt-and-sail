class_name Foliage3D
extends Node3D
## Trees and rocks scattered over the terrain as per-chunk MultiMeshes.

const CHUNK := 24
const TREE_SPACING := 0.95

var density := 1.0

var material: ShaderMaterial
var _tree_round: ArrayMesh
var _tree_pine: ArrayMesh
var _rock: ArrayMesh
var _rng := RandomNumberGenerator.new()
var _gen: WorldGen
var _chunks := {}
var _cur_key := Vector2i.ZERO


func build(gen: WorldGen, world: SeaWorld, noise_tex: Texture2D) -> void:
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/3d/foliage.gdshader")
	material.set_shader_parameter("height_tex", world.height_tex)
	material.set_shader_parameter("explored_tex", world.fog.texture)
	material.set_shader_parameter("noise_tex", noise_tex)
	_setup_cards(world, noise_tex)
	_tree_round = _make_round_tree()
	_tree_pine = _make_pine()
	_rock = _make_rock()
	_gen = gen


## Streams chunks in and out around `center` (cell units). Call every frame;
## builds at most `budget` chunks per call so frames stay smooth.
func update(center: Vector2, radius_chunks: int = 4, budget: int = 1) -> void:
	var cc := Vector2i(floori(center.x / CHUNK), floori(center.y / CHUNK))
	var built := 0
	for ring in range(0, radius_chunks + 1):
		for dz in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dz)) != ring:
					continue
				var key := Vector2i(cc.x + dx, cc.y + dz)
				if key.x < 0 or key.y < 0 or key.x * CHUNK >= WorldGen.GRID_W or key.y * CHUNK >= WorldGen.GRID_H:
					continue
				if _chunks.has(key):
					continue
				if built >= budget:
					return
				_chunks[key] = []
				_scatter_chunk(_gen, key.x, key.y)
				built += 1
	for key in _chunks.keys():
		if maxi(absi(key.x - cc.x), absi(key.y - cc.y)) > radius_chunks + 2:
			for n in _chunks[key]:
				n.queue_free()
			_chunks.erase(key)


func clear() -> void:
	for key in _chunks:
		for n in _chunks[key]:
			n.queue_free()
	_chunks.clear()


func _scatter_chunk(gen: WorldGen, cx: int, cz: int) -> void:
	_cur_key = Vector2i(cx, cz)
	_rng.seed = hash(Vector3i(gen.seed_value, cx, cz))
	var card_t := {}
	var card_c := {}
	var round_t: Array[Transform3D] = []
	var round_c: Array[Color] = []
	var pine_t: Array[Transform3D] = []
	var pine_c: Array[Color] = []
	var rock_t: Array[Transform3D] = []
	var rock_c: Array[Color] = []
	var x0 := cx * CHUNK
	var z0 := cz * CHUNK
	var any := false
	for j in range(0, CHUNK, 3):
		for i in range(0, CHUNK, 3):
			if gen.height_at(Vector2((x0 + i + 1) * WorldGen.CELL, (z0 + j + 1) * WorldGen.CELL)) > WorldGen.SEA + 0.01:
				any = true
				break
		if any:
			break
	if not any:
		return
	var sx := float(x0)
	while sx < x0 + CHUNK:
		var sz := float(z0)
		while sz < z0 + CHUNK:
			var px := sx + _rng.randf() * TREE_SPACING
			var pz := sz + _rng.randf() * TREE_SPACING
			sz += TREE_SPACING
			if px >= WorldGen.GRID_W or pz >= WorldGen.GRID_H:
				continue
			var wp := Vector2(px, pz) * WorldGen.CELL
			var h := gen.height_at(wp)
			var e := h - WorldGen.SEA
			if e < 0.035 or _rng.randf() > density:
				continue
			var ix := clampi(int(px), 0, WorldGen.GRID_W - 1)
			var iz := clampi(int(pz), 0, WorldGen.GRID_H - 1)
			var idx := iz * WorldGen.GRID_W + ix
			var forest := gen.forest[idx]
			var biome := gen.biome[idx]
			var grad := gen.gradient_at(wp).length()
			var y := e * Space3D.HS
			var scale := _rng.randf_range(0.8, 1.35)
			var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * scale)
			var t := Transform3D(basis, Vector3(px, y - 0.05, pz))
			if grad > 0.55 or e > 0.62:
				if _rng.randf() < 0.08:
					var rs := _rng.randf_range(0.8, 2.2)
					rock_t.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(rs, rs * _rng.randf_range(0.7, 1.2), rs)), Vector3(px, y - 0.1, pz)))
					rock_c.append(Color.from_hsv(0.08, 0.12, _rng.randf_range(0.55, 0.85)))
				continue
			if _cards_ok and e < 0.1 and e > 0.04 and biome < 0.6 and _rng.randf() < 0.06 and not _cards_missing.has("palm"):
				_add_card(card_t, card_c, "palm_" + ["a", "b"][_rng.randi() % 2], px, y, pz, _rng.randf_range(0.9, 1.4), Color.WHITE)
				continue
			if forest * _rng.randf_range(0.6, 1.4) < 0.28:
				if _rng.randf() < 0.02 and e < 0.12:
					var rs2 := _rng.randf_range(0.4, 0.9)
					rock_t.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(rs2, rs2 * 0.7, rs2)), Vector3(px, y - 0.05, pz)))
					rock_c.append(Color.from_hsv(0.1, 0.15, _rng.randf_range(0.6, 0.9)))
				continue
			var tint := Color.from_hsv(0.27 + _rng.randf_range(-0.04, 0.03) - biome * 0.08, 0.6 + _rng.randf() * 0.2, 0.42 + _rng.randf() * 0.28)
			if biome > 0.6 or e > 0.22:
				if _cards_ok and not _cards_missing.has("pine"):
					_add_card(card_t, card_c, "tree_pine_a", px, y, pz, scale, tint)
				else:
					pine_t.append(t)
					pine_c.append(Color.from_hsv(0.38, 0.55, 0.36 + _rng.randf() * 0.2))
			else:
				if _cards_ok and not _cards_missing.has("broadleaf"):
					_add_card(card_t, card_c, "tree_broadleaf_" + ["a", "b"][_rng.randi() % 2], px, y, pz, scale, tint)
				else:
					round_t.append(t)
					round_c.append(tint)
		sx += TREE_SPACING
	_emit_cards(card_t, card_c)
	_emit(round_t, round_c, _tree_round, 130.0)
	_emit(pine_t, pine_c, _tree_pine, 130.0)
	_emit(rock_t, rock_c, _rock, 160.0)


func _emit(ts: Array[Transform3D], cs: Array[Color], mesh: Mesh, vis_end: float) -> void:
	if ts.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = ts.size()
	for i in ts.size():
		mm.set_instance_transform(i, ts[i])
		mm.set_instance_custom_data(i, cs[i])
		mm.set_instance_color(i, Color.WHITE)
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = material
	mi.visibility_range_end = vis_end
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_chunks[_cur_key].append(mi)


# ------------------------------------------------------------------ meshes

func _blob(st: SurfaceTool, center: Vector3, radius: Vector3, col_bottom: Color, col_top: Color, seg: int = 9, rings: int = 5, wobble: float = 0.14) -> void:
	var pts := []
	for r in range(rings + 1):
		var v := float(r) / rings
		var phi := PI * v
		var row := []
		for s in range(seg):
			var u := float(s) / seg
			var th := TAU * u
			var k := 1.0 + wobble * sin(th * 3.0 + v * 5.0) * sin(phi)
			row.append(center + Vector3(sin(phi) * cos(th) * radius.x * k, -cos(phi) * radius.y, sin(phi) * sin(th) * radius.z * k))
		pts.append(row)
	for r in range(rings):
		for s in range(seg):
			var s2 := (s + 1) % seg
			var a: Vector3 = pts[r][s]
			var b: Vector3 = pts[r][s2]
			var c: Vector3 = pts[r + 1][s]
			var d: Vector3 = pts[r + 1][s2]
			for tri in [[a, c, b], [b, c, d]]:
				for p in tri:
					var tcol := col_bottom.lerp(col_top, clampf((p.y - center.y) / radius.y * 0.5 + 0.5, 0.0, 1.0))
					st.set_color(tcol)
					st.add_vertex(p)


func _make_round_tree() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# trunk
	_cyl(st, Vector3.ZERO, 0.12, 0.09, 1.0, Color(0.32, 0.2, 0.1), 6)
	_blob(st, Vector3(0, 1.45, 0), Vector3(0.95, 0.85, 0.95), Color(0.35, 0.42, 0.3), Color(0.95, 1.0, 0.75))
	_blob(st, Vector3(0.28, 1.95, 0.1), Vector3(0.62, 0.55, 0.62), Color(0.5, 0.58, 0.4), Color(1.05, 1.1, 0.8), 8, 4)
	st.generate_normals()
	return st.commit()


func _make_pine() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cyl(st, Vector3.ZERO, 0.1, 0.08, 0.7, Color(0.3, 0.2, 0.1), 6)
	for i in 3:
		var y := 0.6 + i * 0.7
		var r := 0.95 - i * 0.25
		_cone(st, Vector3(0, y, 0), r, 1.1, Color(0.38, 0.5, 0.4), Color(0.95, 1.0, 0.9), 8)
	st.generate_normals()
	return st.commit()


func _make_rock() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_blob(st, Vector3(0, 0.3, 0), Vector3(0.7, 0.5, 0.6), Color(0.5, 0.5, 0.5), Color(1.2, 1.15, 1.1), 7, 4, 0.3)
	st.generate_normals()
	return st.commit()


func _cyl(st: SurfaceTool, base: Vector3, r0: float, r1: float, h: float, col: Color, seg: int) -> void:
	for s in seg:
		var a0 := TAU * s / seg
		var a1 := TAU * (s + 1) / seg
		var p00 := base + Vector3(cos(a0) * r0, 0, sin(a0) * r0)
		var p01 := base + Vector3(cos(a1) * r0, 0, sin(a1) * r0)
		var p10 := base + Vector3(cos(a0) * r1, h, sin(a0) * r1)
		var p11 := base + Vector3(cos(a1) * r1, h, sin(a1) * r1)
		for p in [p00, p10, p01, p01, p10, p11]:
			st.set_color(col)
			st.add_vertex(p)


func _cone(st: SurfaceTool, base: Vector3, r: float, h: float, c0: Color, c1: Color, seg: int) -> void:
	var tip := base + Vector3(0, h, 0)
	for s in seg:
		var a0 := TAU * s / seg
		var a1 := TAU * (s + 1) / seg
		var p0 := base + Vector3(cos(a0) * r, 0, sin(a0) * r)
		var p1 := base + Vector3(cos(a1) * r, 0, sin(a1) * r)
		for pair in [[p0, c0], [tip, c1], [p1, c0]]:
			st.set_color(pair[1])
			st.add_vertex(pair[0])


# ------------------------------------------------------------------ painted cards

var _cards_ok := false
var _cards_missing := {}
var _card_mats := {}
var _card_mesh: ArrayMesh


## Camera-facing quads for painted tree/rock sprites (assets/art/props/*.png).
func _setup_cards(world: SeaWorld, noise_tex: Texture2D) -> void:
	_card_mats.clear()
	_cards_missing.clear()
	for name in ["tree_broadleaf_a", "tree_broadleaf_b", "tree_pine_a", "palm_a", "palm_b", "bush_a", "rock_a", "rock_b", "rock_spire"]:
		var t := Art.tiled("props/" + name)
		if t == null:
			continue
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/3d/card.gdshader")
		m.set_shader_parameter("card_tex", t)
		m.set_shader_parameter("height_tex", world.height_tex)
		m.set_shader_parameter("explored_tex", world.fog.texture)
		m.set_shader_parameter("noise_tex", noise_tex)
		_card_mats[name] = m
	_cards_ok = not _card_mats.is_empty()
	if not _card_mats.has("tree_broadleaf_a"):
		_cards_missing["broadleaf"] = true
	if not _card_mats.has("tree_pine_a"):
		_cards_missing["pine"] = true
	if not _card_mats.has("palm_a"):
		_cards_missing["palm"] = true
	# One quad, standing on the ground and leaning back to face the camera.
	var up := Vector3(0.0, SeaScene3D.COS_P, -SeaScene3D.SIN_P)  # screen-up along the ground plane tilt
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [
		[Vector3(-0.5, 0, 0), Vector2(0, 1)], [Vector3(0.5, 0, 0), Vector2(1, 1)],
		[up + Vector3(-0.5, 0, 0), Vector2(0, 0)], [up + Vector3(0.5, 0, 0), Vector2(1, 0)],
	]
	for tri in [[0, 1, 2], [1, 3, 2]]:
		for i in tri:
			st.set_uv(corners[i][1])
			st.add_vertex(corners[i][0])
	_card_mesh = st.commit()


func _add_card(ts: Dictionary, cs: Dictionary, name: String, px: float, y: float, pz: float, scale: float, tint: Color) -> void:
	if not _card_mats.has(name):
		return
	var size := 3.2 * scale if name.begins_with("tree") else (3.0 * scale if name.begins_with("palm") else 1.6 * scale)
	if name == "tree_pine_a":
		size = 4.2 * scale
	if not ts.has(name):
		ts[name] = []
		cs[name] = []
	var flip := -1.0 if _rng.randf() < 0.5 else 1.0
	(ts[name] as Array).append(Transform3D(Basis.IDENTITY.scaled(Vector3(size * flip, size, size)), Vector3(px, y - 0.05, pz)))
	(cs[name] as Array).append(tint)


func _emit_cards(ts: Dictionary, cs: Dictionary) -> void:
	for name in ts:
		var arr: Array = ts[name]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = _card_mesh
		mm.instance_count = arr.size()
		for i in arr.size():
			mm.set_instance_transform(i, arr[i])
			mm.set_instance_custom_data(i, (cs[name] as Array)[i])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = _card_mats[name]
		mi.visibility_range_end = 150.0
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_chunks[_cur_key].append(mi)
