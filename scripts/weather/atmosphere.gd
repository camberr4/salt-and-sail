class_name Atmosphere
extends CanvasLayer
## Screen-space weather overlay. Lantern positions arrive in world space and
## are converted to screen pixels here.

const MAX_LIGHTS := 8

var rect: ColorRect
var mat: ShaderMaterial

var _lights := PackedFloat32Array()
var _cols := PackedFloat32Array()
var _count := 0
var _beam := Vector4.ZERO


func _ready() -> void:
	layer = 5
	rect = ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/atmosphere.gdshader")
	mat.set_shader_parameter("noise_tex", load("res://assets/textures/noise_atlas.png"))
	rect.material = mat
	add_child(rect)
	_reset()


func _reset() -> void:
	_lights.resize(MAX_LIGHTS * 4)
	_lights.fill(0.0)
	_cols.resize(MAX_LIGHTS * 4)
	_cols.fill(0.0)
	_count = 0
	_beam = Vector4.ZERO


## Call at the start of each frame, before add_light().
func begin_frame() -> void:
	_reset()


func add_light(screen_pos: Vector2, radius_px: float, intensity: float, col: Color) -> void:
	if _count >= MAX_LIGHTS:
		return
	var o := _count * 4
	_lights[o] = screen_pos.x
	_lights[o + 1] = screen_pos.y
	_lights[o + 2] = radius_px
	_lights[o + 3] = intensity
	_cols[o] = col.r
	_cols[o + 1] = col.g
	_cols[o + 2] = col.b
	_cols[o + 3] = 1.0
	_count += 1


func set_beam(screen_pos: Vector2, angle: float, intensity: float) -> void:
	_beam = Vector4(screen_pos.x, screen_pos.y, angle, intensity)


func end_frame(view_size: Vector2, flash: float, fade: float) -> void:
	rect.size = view_size
	rect.position = Vector2.ZERO
	mat.set_shader_parameter("view_px", view_size)
	var la := PackedVector4Array()
	var ca := PackedVector4Array()
	for i in MAX_LIGHTS:
		var o := i * 4
		la.append(Vector4(_lights[o], _lights[o + 1], _lights[o + 2], _lights[o + 3]))
		ca.append(Vector4(_cols[o], _cols[o + 1], _cols[o + 2], 1.0))
	mat.set_shader_parameter("lights", la)
	mat.set_shader_parameter("light_cols", ca)
	mat.set_shader_parameter("beam", _beam)
	mat.set_shader_parameter("flash", flash)
	mat.set_shader_parameter("fade", fade)
