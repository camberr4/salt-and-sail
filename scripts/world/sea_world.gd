class_name SeaWorld
extends Node2D
## Owns the generated world data and the single shader quad that draws it.

var gen: WorldGen
var fog: FogOfWar
var height_tex: ImageTexture
var world_mat: ShaderMaterial
var _quad: ColorRect

static var _noise_tex: Texture2D


func setup(p_gen: WorldGen) -> void:
	gen = p_gen
	fog = FogOfWar.new()
	height_tex = ImageTexture.create_from_image(gen.height_image)
	if _noise_tex == null:
		_noise_tex = load("res://assets/textures/noise_atlas.png")

	world_mat = ShaderMaterial.new()
	world_mat.shader = load("res://shaders/world.gdshader")
	world_mat.set_shader_parameter("height_tex", height_tex)
	world_mat.set_shader_parameter("explored_tex", fog.texture)
	world_mat.set_shader_parameter("noise_tex", _noise_tex)
	world_mat.set_shader_parameter("world_size", Vector2(WorldGen.WORLD_W, WorldGen.WORLD_H))
	world_mat.set_shader_parameter("grid_size", Vector2(WorldGen.GRID_W, WorldGen.GRID_H))

	if _quad == null:
		_quad = ColorRect.new()
		_quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_quad)
	_quad.position = Vector2.ZERO
	_quad.size = Vector2(WorldGen.WORLD_W, WorldGen.WORLD_H)
	_quad.material = world_mat


func set_reveal_all(on: bool) -> void:
	world_mat.set_shader_parameter("reveal_all", 1.0 if on else 0.0)
	if on:
		fog.reveal_all()
