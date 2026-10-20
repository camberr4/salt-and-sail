class_name Space3D
extends RefCounted
## Constants and conversions between the 2D simulation (world pixels) and the
## 3D scene (1 unit = 1 height-field cell = 24 px).

const CELL_PX := 24.0
const HS := 26.0  # height scale: field height above sea level -> units


static func to3(p: Vector2, y: float = 0.0) -> Vector3:
	return Vector3(p.x / CELL_PX, y, p.y / CELL_PX)


static func to2(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z) * CELL_PX
