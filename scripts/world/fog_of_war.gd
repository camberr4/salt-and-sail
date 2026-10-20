class_name FogOfWar
extends RefCounted
## Persistent "explored" mask. One byte per 48px cell, uploaded as a texture
## the world and chart shaders sample with linear filtering (so edges are soft).

const CELL := 48.0
const W := int(WorldGen.WORLD_W / CELL)
const H := int(WorldGen.WORLD_H / CELL)

var texture: ImageTexture
var data := PackedByteArray()
var explored_cells := 0
var total_cells := 0

var _image: Image
var _dirty := false
var _last_stamp := Vector2(-1e9, -1e9)


func _init() -> void:
	data.resize(W * H)
	data.fill(0)
	_image = Image.create_from_data(W, H, false, Image.FORMAT_R8, data)
	texture = ImageTexture.create_from_image(_image)
	# Border cells never count towards the chart percentage.
	total_cells = (W - 12) * (H - 12)


## Stamps a soft disc. Returns true if anything new was revealed.
func reveal(pos: Vector2, radius: float, feather: float = 90.0, min_move: float = 14.0) -> bool:
	if pos.distance_to(_last_stamp) < min_move and radius < 900.0:
		return false
	_last_stamp = pos
	var cx := pos.x / CELL
	var cy := pos.y / CELL
	var rc := radius / CELL
	var fc := maxf(feather / CELL, 0.5)
	var x0 := maxi(0, int(cx - rc - 1.0))
	var x1 := mini(W - 1, int(cx + rc + 1.0))
	var y0 := maxi(0, int(cy - rc - 1.0))
	var y1 := mini(H - 1, int(cy + rc + 1.0))
	var changed := false
	for y in range(y0, y1 + 1):
		var row := y * W
		for x in range(x0, x1 + 1):
			var d := Vector2(x + 0.5 - cx, y + 0.5 - cy).length()
			var v := int(clampf((rc - d) / fc, 0.0, 1.0) * 255.0)
			var old := data[row + x]
			if v > old:
				if old < 128 and v >= 128 and x > 5 and x < W - 6 and y > 5 and y < H - 6:
					explored_cells += 1
				data[row + x] = v
				changed = true
	if changed:
		_dirty = true
	return changed


func reveal_all() -> void:
	data.fill(255)
	explored_cells = total_cells
	_dirty = true
	flush()


## Uploads to the GPU if anything changed. Call once per frame.
func flush() -> void:
	if not _dirty:
		return
	_dirty = false
	_image.set_data(W, H, false, Image.FORMAT_R8, data)
	texture.update(_image)


func percent() -> float:
	return clampf(100.0 * explored_cells / maxf(total_cells, 1.0), 0.0, 100.0)


func explored_at(pos: Vector2) -> float:
	var x := clampi(int(pos.x / CELL), 0, W - 1)
	var y := clampi(int(pos.y / CELL), 0, H - 1)
	return data[y * W + x] / 255.0
