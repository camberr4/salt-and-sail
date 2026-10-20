class_name Ship3D
extends Node3D
## The player's sloop as a procedural 3D model: lofted hull, deck, masts,
## fore-and-aft sails that billow with the wind, boom swing, crow's nest, flag.
## Built facing +X; the owner sets position and rotation.y = -heading.

const L := 3.6    # half length (units); 1 unit = 24 px
const B := 1.25   # half beam
const DECK := 0.85

var wood_mat: ShaderMaterial
var sail_mat: ShaderMaterial
var hull: MeshInstance3D
var masts_mi: MeshInstance3D
var art_hull: MeshInstance3D
var art_main: MeshInstance3D
var art_fore: MeshInstance3D
var art_jib: MeshInstance3D
var main_mesh: MeshInstance3D
var fore_mesh: MeshInstance3D
var sails_root: Node3D
var main_pivot: Node3D
var fore_pivot: Node3D
var jib_node: MeshInstance3D
var flag: MeshInstance3D
var _t := randf() * 10.0
var _boom := 0.0
var sgn_cache := 1.0
var look := {"sail": Color(0.95, 0.9, 0.78), "hull": Color(0.3, 0.16, 0.08), "trim": Color(0.6, 0.15, 0.1)}

# Written by the owner each frame.
var heel := 0.0
var speed01 := 0.0
var wind_local := Vector2(0.3, 0.2)  # wind in ship space (x forward, y starboard)
var waves := 0.2


func _ready() -> void:
	var common := load("res://assets/textures/noise_atlas.png")
	wood_mat = ShaderMaterial.new()
	wood_mat.shader = load("res://shaders/3d/wood.gdshader")
	wood_mat.set_shader_parameter("noise_tex", common)
	sail_mat = ShaderMaterial.new()
	sail_mat.shader = load("res://shaders/3d/sail.gdshader")
	sail_mat.set_shader_parameter("noise_tex", common)
	_build()


func bind_world(world: SeaWorld) -> void:
	for m in [wood_mat, sail_mat]:
		m.set_shader_parameter("height_tex", world.height_tex)
		m.set_shader_parameter("explored_tex", world.fog.texture)


# ------------------------------------------------------------------ building

func _half_w(u: float) -> float:
	if u >= 0.0:
		return B * pow(maxf(1.0 - pow(u, 2.2), 0.0), 0.75)
	return B * (0.55 + 0.45 * pow(maxf(1.0 - pow(-u, 2.8), 0.0), 0.6))


func _sheer(u: float) -> float:
	return DECK + 0.35 * pow(absf(u), 3.0) * (1.0 if u > 0 else 0.55)


func _build() -> void:
	hull = MeshInstance3D.new()
	hull.mesh = _hull_mesh()
	hull.material_override = wood_mat
	add_child(hull)
	masts_mi = MeshInstance3D.new()
	masts_mi.mesh = _mast_mesh()
	masts_mi.material_override = wood_mat
	add_child(masts_mi)
	_build_rig()
	_apply_art()


func _hull_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 24
	var rows := [  # (v: 0 keel..1 gunwale, width factor, y offset from sheer)
		[0.0, 0.0, -0.75], [0.25, 0.55, -0.6], [0.5, 0.82, -0.32], [0.62, 0.95, -0.1], [0.75, 1.0, 0.0], [0.88, 1.0, 0.18], [1.0, 0.95, 0.3],
	]
	var hull_col: Color = look["hull"]
	var trim: Color = look["trim"]
	var stations := []
	for i in range(n + 1):
		var u := lerpf(-1.0, 1.0, float(i) / n)
		var x := u * L
		var w := _half_w(u)
		var sh := _sheer(u)
		var ring := []
		for r in rows:
			var y: float = sh + r[2] - 0.12
			if r[0] == 0.0:
				y = 0.05 - 0.55 * (1.0 - absf(u) * 0.4) + 0.0
			ring.append(Vector3(x, y, w * r[1]))
		stations.append(ring)
	# starboard (+z) and port (-z) skins
	for side in [1.0, -1.0]:
		for i in range(n):
			for j in range(rows.size() - 1):
				var a: Vector3 = stations[i][j]
				var b: Vector3 = stations[i + 1][j]
				var c: Vector3 = stations[i][j + 1]
				var d: Vector3 = stations[i + 1][j + 1]
				a.z *= side
				b.z *= side
				c.z *= side
				d.z *= side
				var band := hull_col.lerp(hull_col.lightened(0.18), float(j % 2))
				if j >= rows.size() - 3:
					band = trim if j == rows.size() - 2 else hull_col.darkened(0.2)
				var tri_a := [a, c, b] if side > 0 else [a, b, c]
				var tri_b := [b, c, d] if side > 0 else [b, d, c]
				for tri in [tri_a, tri_b]:
					for p in tri:
						st.set_color(band)
						st.add_vertex(p)
	# deck
	var deck_col := Color(0.5, 0.34, 0.19)
	for i in range(n):
		var ua := lerpf(-1.0, 1.0, float(i) / n)
		var ub := lerpf(-1.0, 1.0, float(i + 1) / n)
		var wa := _half_w(ua) * 0.93
		var wb := _half_w(ub) * 0.93
		var ya := _sheer(ua) - 0.18
		var yb := _sheer(ub) - 0.18
		var p := [Vector3(ua * L, ya, -wa), Vector3(ua * L, ya, wa), Vector3(ub * L, yb, -wb), Vector3(ub * L, yb, wb)]
		for tri in [[p[0], p[2], p[1]], [p[1], p[2], p[3]]]:
			for q in tri:
				st.set_color(deck_col)
				st.add_vertex(q)
	# stern castle and cabin block
	_box(st, Vector3(-L * 0.62, DECK - 0.05, 0), Vector3(1.05, 0.5, 1.5), Color(0.5, 0.2, 0.14))
	_box(st, Vector3(-L * 0.62, DECK + 0.32, 0), Vector3(1.0, 0.1, 1.55), Color(0.3, 0.17, 0.09))
	# hatch, barrels, wheel
	_box(st, Vector3(L * 0.2, DECK - 0.1, 0), Vector3(0.6, 0.25, 0.7), Color(0.28, 0.16, 0.08))
	for bp in [Vector3(-L * 0.22, DECK - 0.1, 0.8), Vector3(-L * 0.22, DECK - 0.1, -0.8), Vector3(-L * 0.12, DECK - 0.1, 0.85)]:
		_cyl(st, bp, 0.26, 0.26, 0.4, Color(0.45, 0.28, 0.14), 8)
	st.generate_normals()
	return st.commit()


## Masts, bowsprit and crow's nest. Always 3D, so painted hulls still carry them.
func _mast_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cyl_dir(st, Vector3(L * 0.8, DECK + 0.1, 0), Vector3(L * 1.32, DECK + 0.5, 0), 0.09, Color(0.28, 0.16, 0.08))
	for mx in [L * 0.12, L * 0.62]:
		_cyl(st, Vector3(mx, DECK - 0.2, 0), 0.11, 0.07, 5.2 if mx < L * 0.3 else 4.1, Color(0.3, 0.17, 0.08), 8)
	_cyl(st, Vector3(L * 0.12, 4.3, 0), 0.34, 0.3, 0.28, Color(0.34, 0.2, 0.1), 8)
	st.generate_normals()
	return st.commit()


func _build_rig() -> void:
	sails_root = Node3D.new()
	add_child(sails_root)
	# Main: gaff sail aft of the main mast, swung by a boom pivot at the mast.
	main_pivot = Node3D.new()
	main_pivot.position = Vector3(L * 0.12, DECK, 0)
	sails_root.add_child(main_pivot)
	var mm := MeshInstance3D.new()
	main_mesh = mm
	mm.mesh = _sail_mesh([Vector3(0, 0.55, 0), Vector3(-3.5, 0.65, 0), Vector3(-2.6, 4.6, 0), Vector3(0.0, 5.1, 0)], 10, 12)
	mm.material_override = sail_mat
	main_pivot.add_child(mm)
	var boom := MeshInstance3D.new()
	var bst := SurfaceTool.new()
	bst.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cyl_dir(bst, Vector3(0, 0.55, 0), Vector3(-3.6, 0.65, 0), 0.07, Color(0.3, 0.17, 0.08))
	_cyl_dir(bst, Vector3(0, 5.0, 0), Vector3(-2.7, 4.7, 0), 0.05, Color(0.3, 0.17, 0.08))
	bst.generate_normals()
	boom.mesh = bst.commit()
	boom.material_override = wood_mat
	main_pivot.add_child(boom)
	# Fore sail on the second mast.
	fore_pivot = Node3D.new()
	fore_pivot.position = Vector3(L * 0.62, DECK, 0)
	sails_root.add_child(fore_pivot)
	var fm := MeshInstance3D.new()
	fore_mesh = fm
	fm.mesh = _sail_mesh([Vector3(0, 0.5, 0), Vector3(-2.4, 0.6, 0), Vector3(-1.6, 3.5, 0), Vector3(0, 3.9, 0)], 8, 10)
	fm.material_override = sail_mat
	fore_pivot.add_child(fm)
	# Jib from the forward mast head to the bowsprit.
	jib_node = MeshInstance3D.new()
	jib_node.mesh = _sail_mesh([Vector3(L * 1.28, DECK + 0.55, 0), Vector3(L * 0.66, DECK + 0.45, 0), Vector3(L * 0.64, DECK + 3.9, 0), Vector3(L * 0.64, DECK + 3.9, 0)], 8, 10, true)
	jib_node.material_override = sail_mat
	sails_root.add_child(jib_node)
	# Flag on the crow's nest.
	flag = MeshInstance3D.new()
	var fst := SurfaceTool.new()
	fst.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := Color(0.08, 0.08, 0.1)
	for i in range(8):
		var a := float(i) / 8.0
		var b := float(i + 1) / 8.0
		var ha := lerpf(0.5, 0.15, a)
		var hb := lerpf(0.5, 0.15, b)
		var pa := [Vector3(-a * 1.6, ha * 0.5, 0), Vector3(-a * 1.6, -ha * 0.5, 0), Vector3(-b * 1.6, hb * 0.5, 0), Vector3(-b * 1.6, -hb * 0.5, 0)]
		for tri in [[pa[0], pa[1], pa[2]], [pa[1], pa[3], pa[2]]]:
			for q in tri:
				fst.set_color(cols)
				fst.add_vertex(q)
	fst.generate_normals()
	flag.mesh = fst.commit()
	var fm_mat := StandardMaterial3D.new()
	fm_mat.vertex_color_use_as_albedo = true
	fm_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	flag.material_override = fm_mat
	flag.position = Vector3(L * 0.12, 4.9, 0)
	add_child(flag)


## Quad sail from four corners, subdivided. UV.x along the foot, UV.y foot -> head.
func _sail_mesh(c: Array, nx: int, ny: int, fan: bool = false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid := []
	for j in range(ny + 1):
		var v := float(j) / ny
		var row := []
		for i in range(nx + 1):
			var u := float(i) / nx
			var foot := (c[0] as Vector3).lerp(c[1], u)
			var head := (c[3] as Vector3).lerp(c[2], u)
			row.append([foot.lerp(head, v), Vector2(u, v)])
		grid.append(row)
	for j in range(ny):
		for i in range(nx):
			var a: Array = grid[j][i]
			var b: Array = grid[j][i + 1]
			var cc: Array = grid[j + 1][i]
			var d: Array = grid[j + 1][i + 1]
			for tri in [[a, cc, b], [b, cc, d]]:
				for q in tri:
					st.set_uv(q[1])
					st.add_vertex(q[0])
	st.generate_normals()
	return st.commit()


func _box(st: SurfaceTool, c: Vector3, size: Vector3, col: Color) -> void:
	var h := size * 0.5
	var v := [
		Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z),
		Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z),
	]
	var faces := [[0, 2, 1, 0, 3, 2], [4, 5, 6, 4, 6, 7], [0, 1, 5, 0, 5, 4], [3, 7, 6, 3, 6, 2], [0, 4, 7, 0, 7, 3], [1, 2, 6, 1, 6, 5]]
	for f in faces:
		for idx in f:
			st.set_color(col)
			st.add_vertex(c + v[idx])


func _cyl(st: SurfaceTool, base: Vector3, r0: float, r1: float, h: float, col: Color, seg: int) -> void:
	for s in seg:
		var a0 := TAU * s / seg
		var a1 := TAU * (s + 1) / seg
		var p00 := base + Vector3(cos(a0) * r0, 0, sin(a0) * r0)
		var p01 := base + Vector3(cos(a1) * r0, 0, sin(a1) * r0)
		var p10 := base + Vector3(cos(a0) * r1, h, sin(a0) * r1)
		var p11 := base + Vector3(cos(a1) * r1, h, sin(a1) * r1)
		for p in [p00, p01, p10, p01, p11, p10]:
			st.set_color(col)
			st.add_vertex(p)


func _cyl_dir(st: SurfaceTool, a: Vector3, b: Vector3, r: float, col: Color) -> void:
	var dir := (b - a).normalized()
	var up := Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT
	var u := dir.cross(up).normalized() * r
	var v := dir.cross(u).normalized() * r
	var seg := 6
	for s in seg:
		var a0 := TAU * s / seg
		var a1 := TAU * (s + 1) / seg
		var o0 := u * cos(a0) + v * sin(a0)
		var o1 := u * cos(a1) + v * sin(a1)
		for p in [a + o0, b + o0, a + o1, a + o1, b + o0, b + o1]:
			st.set_color(col)
			st.add_vertex(p)


# ------------------------------------------------------------------ animation

func _process(delta: float) -> void:
	_t += delta
	var wl := wind_local
	var strength := clampf(wl.length(), 0.0, 1.3)
	# Boom swings out to leeward; sail belly follows.
	var side := -1.0 if wl.y >= 0.0 else 1.0
	var target := clampf(side * (0.25 + 0.7 * (1.0 - absf(wl.x))), -1.1, 1.1) * (0.4 + 0.6 * strength)
	_boom = lerp_angle(_boom, target, 1.0 - exp(-2.0 * delta))
	main_pivot.rotation.y = _boom
	fore_pivot.rotation.y = _boom * 0.8
	var drive := clampf(strength * (0.5 + 0.8 * absf(wl.y)) , 0.0, 1.0)
	var belly := 0.6 + 1.0 * drive + 0.3 * speed01
	var sgn := signf(_boom) if absf(_boom) > 0.02 else side
	sgn_cache = sgn
	sail_mat.set_shader_parameter("billow", -sgn * belly)
	sail_mat.set_shader_parameter("flutter", 0.05 + 0.12 * clampf(1.0 - drive, 0.0, 1.0))
	# Roll and pitch with the sea; heel under sail pressure.
	var roll := sin(_t * 1.6) * (0.015 + waves * 0.05) + heel
	var pitch := sin(_t * 1.1 + 1.3) * (0.01 + waves * 0.03)
	hull.rotation.x = roll
	hull.rotation.z = pitch
	masts_mi.rotation.x = roll
	masts_mi.rotation.z = pitch
	if art_hull != null:
		art_hull.rotation.x = roll
		art_hull.rotation.z = pitch
	var flip := (1.0 if sgn_cache >= 0.0 else -1.0) * (0.85 + 0.3 * drive)
	if art_main != null:
		art_main.scale.z = flip
	if art_fore != null:
		art_fore.scale.z = flip
	sails_root.rotation.x = roll
	sails_root.rotation.z = pitch
	flag.rotation.x = roll
	# Flag streams downwind.
	var wd := Vector2(-wl.x, -wl.y)
	var ang := atan2(wd.y, wd.x)
	flag.rotation.y = -ang + sin(_t * 9.0) * 0.12
	flag.position.y = 4.9 + 0.0
	position.y = sin(_t * 1.3) * (0.03 + waves * 0.1)


# ------------------------------------------------------------------ painted art

## A flat painted quad. Image "up" maps to the ship's bow (+X), image "right" to
## starboard (+Z). `size` is (length along the ship, width across it) in units.
func _art_quad(tex: Texture2D, size: Vector2, mirror_v: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var corners := [
		[Vector3(hx, 0, -hz), Vector2(0, 0)], [Vector3(hx, 0, hz), Vector2(1, 0)],
		[Vector3(-hx, 0, -hz), Vector2(0, 1)], [Vector3(-hx, 0, hz), Vector2(1, 1)],
	]
	for tri in [[0, 2, 1], [1, 2, 3]]:
		for i in tri:
			st.set_normal(Vector3.UP)
			st.set_uv(corners[i][1])
			st.add_vertex(corners[i][0])
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.85
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mi.material_override = m
	return mi


func _apply_art() -> void:
	var th := Art.tex("ship/hull")
	if th != null:
		var aspect := float(th.get_height()) / maxf(float(th.get_width()), 1.0)
		var width := 2.0 * B * 1.5
		art_hull = _art_quad(th, Vector2(width * aspect, width))
		art_hull.position = Vector3(0, DECK + 0.05, 0)
		add_child(art_hull)
		hull.visible = false
	var tm := Art.tex("ship/sail_main")
	if tm != null:
		art_main = _art_quad(tm, Vector2(3.9, 3.0))
		art_main.position = Vector3(-1.95, 3.2, 0)
		main_pivot.add_child(art_main)
		main_mesh.visible = false
	var tf := Art.tex("ship/sail_fore")
	if tf != null:
		art_fore = _art_quad(tf, Vector2(2.7, 2.2))
		art_fore.position = Vector3(-1.35, 2.7, 0)
		fore_pivot.add_child(art_fore)
		fore_mesh.visible = false
	var tj := Art.tex("ship/sail_jib")
	if tj != null:
		art_jib = _art_quad(tj, Vector2(3.4, 1.4))
		art_jib.position = Vector3(L * 1.0, DECK + 2.6, 0)
		sails_root.add_child(art_jib)
		jib_node.visible = false
