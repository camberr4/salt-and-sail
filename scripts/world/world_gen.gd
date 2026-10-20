class_name WorldGen
extends RefCounted
## Procedural archipelago. Pure data, safe to run on a worker thread.
##
## The sea is a low-resolution height field (one cell = CELL world pixels).
## Height 0.5 is sea level. The GPU smooths it and adds detail, the CPU uses
## the same field for collisions, so what you see is what you hit.

const CELL := 24.0
const GRID_W := 450
const GRID_H := 800
const WORLD_W := GRID_W * CELL  # 10800 = 10 portrait screens of 1080
const WORLD_H := GRID_H * CELL  # 19200 = 10 portrait screens of 1920
const SEA := 0.5
const COLLIDE := 0.508
const EDGE_CELLS := 10

const BIOME_LUSH := 0.0
const BIOME_TROPIC := 0.34
const BIOME_DRY := 0.67
const BIOME_ROCK := 1.0

var seed_value := 0
var heights := PackedFloat32Array()
var forest := PackedFloat32Array()
var biome := PackedFloat32Array()
var islands: Array[Dictionary] = []
var pois: Array[Dictionary] = []
var start_pos := Vector2.ZERO
var start_heading := 0.0
var height_image: Image

var _rng := RandomNumberGenerator.new()
var _coarse := PackedByteArray()
var _fine := PackedByteArray()
var _used_names := {}


func generate(p_seed: int) -> void:
	seed_value = p_seed
	_rng.seed = p_seed
	_make_noise()
	_place_islands()
	_raster_islands()
	_place_pois()
	_build_image()


# ------------------------------------------------------------------ queries

func height_at(p: Vector2) -> float:
	var fx := p.x / CELL - 0.5
	var fy := p.y / CELL - 0.5
	var ix := floori(fx)
	var iy := floori(fy)
	var tx := fx - ix
	var ty := fy - iy
	var x0 := clampi(ix, 0, GRID_W - 1)
	var x1 := clampi(ix + 1, 0, GRID_W - 1)
	var y0 := clampi(iy, 0, GRID_H - 1)
	var y1 := clampi(iy + 1, 0, GRID_H - 1)
	var a := heights[y0 * GRID_W + x0]
	var b := heights[y0 * GRID_W + x1]
	var c := heights[y1 * GRID_W + x0]
	var d := heights[y1 * GRID_W + x1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


func is_land(p: Vector2) -> bool:
	return height_at(p) > COLLIDE


func gradient_at(p: Vector2) -> Vector2:
	var e := CELL * 0.75
	return Vector2(
		height_at(p + Vector2(e, 0)) - height_at(p - Vector2(e, 0)),
		height_at(p + Vector2(0, e)) - height_at(p - Vector2(0, e))
	)


## Marches from `from` along `dir` and returns the first point whose height
## crosses `level`, or Vector2.INF if nothing is hit within max_dist.
func march(from: Vector2, dir: Vector2, max_dist: float, level: float = COLLIDE) -> Vector2:
	var step := CELL * 0.4
	var d := 0.0
	var start_above := height_at(from) > level
	while d < max_dist:
		var p := from + dir * d
		if (height_at(p) > level) != start_above:
			return p
		d += step
	return Vector2.INF


func in_bounds(p: Vector2, margin: float = 0.0) -> bool:
	return p.x >= margin and p.y >= margin and p.x <= WORLD_W - margin and p.y <= WORLD_H - margin


func nearest_land_distance(p: Vector2, max_dist: float = 600.0) -> float:
	var best := max_dist
	for i in 16:
		var dir := Vector2.from_angle(TAU * i / 16.0)
		var hit := march(p, dir, best, COLLIDE)
		if hit != Vector2.INF:
			best = minf(best, p.distance_to(hit))
	return best


# ------------------------------------------------------------------ noise

func _make_noise() -> void:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = _rng.randi()
	n.frequency = 0.045
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 3
	_coarse = n.get_image(GRID_W, GRID_H, false, false, true).get_data()
	n.seed = _rng.randi()
	n.frequency = 0.17
	n.fractal_octaves = 2
	_fine = n.get_image(GRID_W, GRID_H, false, false, true).get_data()

	var base := FastNoiseLite.new()
	base.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	base.seed = _rng.randi()
	base.frequency = 0.012
	var bdata := base.get_image(GRID_W, GRID_H, false, false, true).get_data()
	var total := GRID_W * GRID_H
	heights.resize(total)
	forest.resize(total)
	biome.resize(total)
	for i in total:
		heights[i] = 0.17 + float(bdata[i]) * (0.07 / 255.0)
		forest[i] = 0.0
		biome[i] = 0.0


# ------------------------------------------------------------------ islands

func _add_island(c: Vector2, r: float, kind: String, force_biome: float = -1.0) -> bool:
	var squash := _rng.randf_range(0.62, 1.0) if kind != "tiny" else _rng.randf_range(0.8, 1.0)
	var isl := {
		"c": c,
		"rx": r,
		"ry": r * squash,
		"angle": _rng.randf() * TAU,
		"kind": kind,
		"r": r,
	}
	var margin := EDGE_CELLS + r * 2.0
	if c.x < margin or c.y < margin or c.x > GRID_W - margin or c.y > GRID_H - margin:
		return false
	for o in islands:
		var min_d: float = (r + float(o["r"])) * 1.5 + 7.0
		if c.distance_to(o["c"]) < min_d:
			return false
	match kind:
		"large":
			isl["elev"] = _rng.randf_range(0.34, 0.46)
			isl["warp_a"] = 0.62
			isl["warp_b"] = 0.26
			isl["forest"] = _rng.randf_range(0.7, 1.0)
		"medium":
			isl["elev"] = _rng.randf_range(0.26, 0.38)
			isl["warp_a"] = 0.55
			isl["warp_b"] = 0.28
			isl["forest"] = _rng.randf_range(0.5, 1.0)
		"small":
			isl["elev"] = _rng.randf_range(0.16, 0.26)
			isl["warp_a"] = 0.4
			isl["warp_b"] = 0.3
			isl["forest"] = _rng.randf_range(0.0, 0.8)
		_:
			isl["elev"] = _rng.randf_range(0.12, 0.2)
			isl["warp_a"] = 0.2
			isl["warp_b"] = 0.32
			isl["forest"] = 0.0
	if force_biome >= 0.0:
		isl["biome"] = force_biome
	else:
		var roll := _rng.randf()
		isl["biome"] = BIOME_LUSH if roll < 0.35 else (BIOME_TROPIC if roll < 0.7 else (BIOME_DRY if roll < 0.9 else BIOME_ROCK))
	isl["roles"] = []
	islands.append(isl)
	return true


func _place_islands() -> void:
	# The home island, with a few neighbours so there is always something to
	# sail towards in the first seconds.
	var home := Vector2(96, 700)
	_add_island(home, 15.0, "large", BIOME_LUSH)
	islands[0]["elev"] = 0.33
	islands[0]["forest"] = 0.85
	islands[0]["home"] = true
	_add_island(home + Vector2(62, -26), 4.6, "small", BIOME_TROPIC)
	_add_island(home + Vector2(98, 34), 9.0, "medium", BIOME_LUSH)
	_add_island(home + Vector2(150, -62), 2.4, "tiny", BIOME_TROPIC)
	_add_island(home + Vector2(30, -92), 11.0, "medium", BIOME_DRY)
	_add_island(home + Vector2(215, -20), 5.4, "small", BIOME_LUSH)

	var plan := [["large", 6, 19.0, 27.0], ["medium", 38, 8.5, 15.0], ["small", 62, 3.8, 7.5], ["tiny", 40, 1.7, 3.2]]
	for entry in plan:
		var placed := 0
		var attempts := 0
		while placed < entry[1] and attempts < 4000:
			attempts += 1
			var r := _rng.randf_range(entry[2], entry[3])
			var c := Vector2(_rng.randf_range(0, GRID_W), _rng.randf_range(0, GRID_H))
			if _add_island(c, r, entry[0]):
				placed += 1


func _raster_islands() -> void:
	for isl in islands:
		var c: Vector2 = isl["c"]
		var rx: float = isl["rx"]
		var ry: float = isl["ry"]
		var rmax := maxf(rx, ry)
		var reach := rmax * 2.7 + 3.0
		var x0 := maxi(0, int(c.x - reach))
		var x1 := mini(GRID_W - 1, int(c.x + reach))
		var y0 := maxi(0, int(c.y - reach))
		var y1 := mini(GRID_H - 1, int(c.y + reach))
		var ca := cos(isl["angle"])
		var sa := sin(isl["angle"])
		var wa: float = isl["warp_a"]
		var wb: float = isl["warp_b"]
		var elev: float = isl["elev"]
		var isl_forest: float = isl["forest"]
		var isl_biome: float = isl["biome"]
		var big: bool = isl["kind"] == "large" or isl["kind"] == "medium"
		for iy in range(y0, y1 + 1):
			for ix in range(x0, x1 + 1):
				var dx := ix + 0.5 - c.x
				var dy := iy + 0.5 - c.y
				var ux := (dx * ca + dy * sa) / rx
				var uy := (-dx * sa + dy * ca) / ry
				var d := sqrt(ux * ux + uy * uy)
				var i := iy * GRID_W + ix
				var warp := (float(_coarse[i]) / 255.0 - 0.5) * wa + (float(_fine[i]) / 255.0 - 0.5) * wb
				var f := 1.0 - d + warp
				var hh: float
				if f > 0.0:
					hh = SEA + pow(f, 0.9) * elev
					if big:
						var ridge := 1.0 - absf(float(_fine[i]) / 127.5 - 1.0)
						hh += ridge * 0.09 * smoothstep(0.3, 0.9, f)
				else:
					hh = SEA + f * 0.2
				if hh > heights[i]:
					heights[i] = minf(hh, 0.999)
					if f > -0.3:
						forest[i] = clampf(isl_forest * (0.6 + 0.8 * float(_coarse[i]) / 255.0 - 0.2), 0.0, 1.0)
						biome[i] = clampf(isl_biome + (float(_fine[i]) / 255.0 - 0.5) * 0.18, 0.0, 1.0)


# ------------------------------------------------------------------ POIs

const NAME_ADJ := ["Drowned", "Gilded", "Weeping", "Crooked", "Hollow", "Scarlet", "Lonely", "Black", "Mourning", "Whispering", "Rusted", "Sunken", "Salt", "Bleak", "Merry", "Dread", "Silver", "Wicked", "Forgotten", "Pale"]
const NAME_HAVEN := ["Haven", "Landing", "Harbor", "Quay", "Wharf"]
const NAME_LIGHT := ["Light", "Beacon", "Watch", "Lantern"]
const NAME_CAY := ["Cay", "Isle", "Key", "Strand", "Sands"]
const NAME_SKULL := ["Skull", "Fang", "Tooth", "Crown", "Grin"]
const NAME_SHIP := ["Mad Margaret", "Brine Duchess", "Saint Odo's Fortune", "Lucky Haddock", "Pale Marigold", "Crimson Widow", "Gull's Folly", "Dancing Tess", "Iron Lament", "Sea Tinker", "Last Promise", "Black Pearl of Ness"]
const NAME_MAW := ["Maw", "Drain", "Gullet", "Churn", "Throat"]


func _pick_name(pool: Array, fmt: String) -> String:
	for attempt in 12:
		var n := fmt % [NAME_ADJ[_rng.randi() % NAME_ADJ.size()], pool[_rng.randi() % pool.size()]]
		if not _used_names.has(n):
			_used_names[n] = true
			return n
	return fmt % ["Nameless", pool[0]]


func _ship_name() -> String:
	for attempt in 12:
		var n: String = NAME_SHIP[_rng.randi() % NAME_SHIP.size()]
		if not _used_names.has(n):
			_used_names[n] = true
			return "Wreck of the " + n
	return "Wreck of the Unknown"


func _place_pois() -> void:
	# Home harbour first: it defines the start position.
	var home: Dictionary = islands[0]
	var home_px: Vector2 = (home["c"] as Vector2) * CELL
	var best := _best_shore(home_px, 20, 0.0, Vector2(WORLD_W * 0.6, WORLD_H * 0.55))
	var normal: Vector2 = best["normal"]
	var shore: Vector2 = best["shore"]
	var harbor := {
		"kind": "village",
		"home": true,
		"name": "Port Brine",
		"art": shore - normal * 44.0,
		"pos": shore + normal * 70.0,
		"normal": normal,
		"radius": 150.0,
		"seed": _rng.randi(),
	}
	_append_poi(harbor)
	start_pos = shore + normal * 230.0
	start_heading = normal.angle()
	home["roles"].append("village")

	# One of each close to home, so the first minute is interesting.
	_force_nearby("treasure", ["small", "tiny"], 2300.0, 4200.0)
	_force_nearby("lighthouse", ["small", "tiny"], 3600.0, 6500.0)
	# Island-bound points of interest, spread evenly over the map.
	_assign_island_pois("village", 5, ["medium", "large", "small"], "village")
	_assign_island_pois("lighthouse", 3, ["small", "tiny"], "lighthouse")
	_assign_island_pois("treasure", 5, ["small", "tiny"], "treasure")
	_assign_island_pois("skull", 3, ["tiny"], "skull")

	# Open-water points of interest.
	_place_water_pois("wreck", 7, 0.06, 0.20, 5)
	_place_water_pois("bottle", 9, 0.12, 0.40, 0)
	_place_water_pois("whirlpool", 4, 0.28, 0.40, 13)
	_place_water_pois("wisps", 3, 0.20, 0.40, 8)
	# A drifting bottle just ahead of the start, as a gentle nudge.
	var ahead := start_pos + Vector2.from_angle(start_heading) * 780.0
	if height_at(ahead) < SEA - 0.1:
		_append_poi({
			"kind": "bottle", "name": "Message in a Bottle", "art": ahead, "pos": ahead,
			"normal": Vector2.RIGHT, "radius": 90.0, "seed": _rng.randi(),
		})


func _append_poi(d: Dictionary) -> void:
	d["id"] = pois.size()
	pois.append(d)


func _best_shore(center_px: Vector2, samples: int, angle_bias: float, toward: Vector2) -> Dictionary:
	var best_score := -1e9
	var best := {"shore": center_px, "normal": Vector2.RIGHT}
	var toward_dir := (toward - center_px).normalized()
	for i in samples:
		var a := TAU * i / samples + angle_bias
		var dir := Vector2.from_angle(a)
		var hit := march(center_px, dir, 5000.0, COLLIDE)
		if hit == Vector2.INF:
			continue
		# Walk a little further to the true end of land in this direction.
		var shore := hit
		var open := 0.0
		var ok := true
		for k in range(2, 11):
			var p := shore + dir * (k * CELL)
			if not in_bounds(p, 260.0) or height_at(p) > COLLIDE:
				ok = false
				break
			open += SEA - height_at(p)
		if not ok:
			continue
		var score := open + dir.dot(toward_dir) * 0.35
		if score > best_score:
			best_score = score
			best = {"shore": shore, "normal": dir}
	return best


func _free_islands(kinds: Array) -> Array:
	var out := []
	for isl in islands:
		if isl.get("home", false):
			continue
		if isl["kind"] in kinds and isl["roles"].is_empty():
			out.append(isl)
	return out


func _poi_far_enough(p: Vector2, min_d: float) -> bool:
	if p.distance_to(start_pos) < 700.0:
		return false
	for o in pois:
		if p.distance_to(o["pos"]) < min_d:
			return false
	return true


func _assign_island_pois(kind: String, count: int, kinds: Array, role: String) -> void:
	for n in count:
		var pool := _free_islands(kinds)
		if pool.is_empty():
			return
		# Best candidate: the island farthest from existing POIs (even spread).
		var best_isl: Dictionary = {}
		var best_d := -1.0
		for k in mini(pool.size(), 22):
			var isl: Dictionary = pool[_rng.randi() % pool.size()]
			var px: Vector2 = (isl["c"] as Vector2) * CELL
			var d := 1e9
			for o in pois:
				d = minf(d, px.distance_to(o["pos"]))
			d = minf(d, px.distance_to(start_pos) * 0.8)
			if d > best_d:
				best_d = d
				best_isl = isl
		if best_isl.is_empty():
			return
		_make_island_poi(best_isl, kind, role)


func _force_nearby(kind: String, kinds: Array, min_d: float, max_d: float) -> void:
	var pool := _free_islands(kinds)
	for i in range(pool.size() - 1, 0, -1):
		var j := _rng.randi() % (i + 1)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	for isl in pool:
		var d := ((isl["c"] as Vector2) * CELL).distance_to(start_pos)
		if d >= min_d and d <= max_d:
			_make_island_poi(isl, kind, kind)
			return


func _make_island_poi(isl: Dictionary, kind: String, role: String) -> void:
	var px: Vector2 = (isl["c"] as Vector2) * CELL
	var open_toward := Vector2(WORLD_W, WORLD_H) * 0.5
	var best := _best_shore(px, 16, _rng.randf() * TAU, open_toward)
	if (best["shore"] as Vector2) == px:
		return
	var shore: Vector2 = best["shore"]
	var normal: Vector2 = best["normal"]
	isl["roles"].append(role)
	var d := {
		"kind": kind,
		"island": isl,
		"normal": normal,
		"seed": _rng.randi(),
	}
	match kind:
		"village":
			d["name"] = _pick_name(NAME_HAVEN, "%s %s")
			d["art"] = shore - normal * 44.0
			d["pos"] = shore + normal * 70.0
			d["radius"] = 150.0
		"lighthouse":
			d["name"] = _pick_name(NAME_LIGHT, "%s %s")
			d["art"] = px
			d["pos"] = shore + normal * 80.0
			d["radius"] = 170.0
			isl["biome"] = BIOME_ROCK
		"treasure":
			d["name"] = _pick_name(NAME_CAY, "%s %s")
			d["art"] = px
			d["pos"] = shore + normal * 80.0
			d["radius"] = 170.0
		_:
			d["name"] = _pick_name(NAME_SKULL, "%s %s Rock")
			d["art"] = px
			d["pos"] = shore + normal * 90.0
			d["radius"] = 180.0
			isl["biome"] = BIOME_ROCK
	_append_poi(d)
	if kind == "lighthouse" or kind == "skull":
		_recolor_island(isl, BIOME_ROCK, 0.0)
	elif kind == "treasure":
		_recolor_island(isl, BIOME_TROPIC, 0.15)


func _recolor_island(isl: Dictionary, bio: float, forest_amt: float) -> void:
	var c: Vector2 = isl["c"]
	var reach: float = float(isl["r"]) * 1.6 + 2.0
	for iy in range(maxi(0, int(c.y - reach)), mini(GRID_H, int(c.y + reach))):
		for ix in range(maxi(0, int(c.x - reach)), mini(GRID_W, int(c.x + reach))):
			var i := iy * GRID_W + ix
			if heights[i] > SEA - 0.05:
				biome[i] = bio
				forest[i] = minf(forest[i], forest_amt)


func _place_water_pois(kind: String, count: int, min_depth: float, max_depth: float, clear_cells: int) -> void:
	for n in count:
		var best_p := Vector2.INF
		var best_d := -1.0
		for attempt in 60:
			var p := Vector2(
				_rng.randf_range(600.0, WORLD_W - 600.0),
				_rng.randf_range(600.0, WORLD_H - 600.0)
			)
			var depth := SEA - height_at(p)
			if depth < min_depth or depth > max_depth:
				continue
			if clear_cells > 0 and not _clear_of_land(p, clear_cells):
				continue
			if not _poi_far_enough(p, 650.0):
				continue
			var d := 1e9
			for o in pois:
				d = minf(d, p.distance_to(o["pos"]))
			if d > best_d:
				best_d = d
				best_p = p
		if best_p == Vector2.INF:
			continue
		var d := {"kind": kind, "art": best_p, "pos": best_p, "normal": Vector2.RIGHT, "seed": _rng.randi(), "radius": 130.0}
		match kind:
			"wreck":
				d["name"] = _ship_name()
				d["radius"] = 150.0
			"bottle":
				d["name"] = "Message in a Bottle"
				d["radius"] = 90.0
			"whirlpool":
				d["name"] = _pick_name(NAME_MAW, "%s %s")
				d["radius"] = 330.0
			_:
				d["name"] = "Wisp Shoal"
				d["radius"] = 190.0
		_append_poi(d)


func _clear_of_land(p: Vector2, cells: int) -> bool:
	for i in 12:
		var dir := Vector2.from_angle(TAU * i / 12.0)
		for k in [cells * 0.5, cells]:
			if height_at(p + dir * (k * CELL)) > SEA - 0.02:
				return false
	return true


# ------------------------------------------------------------------ output

func _build_image() -> void:
	var total := GRID_W * GRID_H
	var data := PackedByteArray()
	data.resize(total * 4)
	for i in total:
		var o := i * 4
		data[o] = clampi(int(heights[i] * 255.0 + 0.5), 0, 255)
		data[o + 1] = clampi(int(forest[i] * 255.0 + 0.5), 0, 255)
		data[o + 2] = clampi(int(biome[i] * 255.0 + 0.5), 0, 255)
		data[o + 3] = 255
	height_image = Image.create_from_data(GRID_W, GRID_H, false, Image.FORMAT_RGBA8, data)
