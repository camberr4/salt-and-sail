class_name SeaWorld
extends Node2D
## Owns the generated world data and the single shader quad that draws it.
##
## At High quality the quad is drawn straight into the main viewport. At lower
## qualities it is rendered into a smaller SubViewport and scaled up behind
## everything else, which cuts fragment cost on weak GPUs (the sea is soft,
## procedural noise anyway, so the lost resolution is hard to see).

const SCALES := [0.62, 0.82, 1.0]

var gen: WorldGen
var fog: FogOfWar
var height_tex: ImageTexture
var world_mat: ShaderMaterial

var _quad: ColorRect
var _sub: SubViewport
var _sub_cam: Camera2D
var _bg_layer: CanvasLayer
var _bg_rect: TextureRect
var _scale := 1.0
var _mode := -1  # 0 direct, 1 sub viewport

static var _noise_tex: Texture2D


func setup(p_gen: WorldGen, render2d: bool = true) -> void:
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
	_quad.position = Vector2.ZERO
	_quad.size = Vector2(WorldGen.WORLD_W, WorldGen.WORLD_H)
	_quad.material = world_mat
	if render2d:
		apply_quality()
		if not Game.settings_changed.is_connected(apply_quality):
			Game.settings_changed.connect(apply_quality)


func _exit_tree() -> void:
	if Game.settings_changed.is_connected(apply_quality):
		Game.settings_changed.disconnect(apply_quality)


func set_reveal_all(on: bool) -> void:
	world_mat.set_shader_parameter("reveal_all", 1.0 if on else 0.0)
	Game.gset("g_reveal", 1.0 if on else 0.0)
	if on:
		fog.reveal_all()


## Picks the direct or sub-viewport path from the Graphics setting.
func apply_quality() -> void:
	if _quad == null:
		return
	_scale = SCALES[clampi(int(Game.settings["quality"]), 0, 2)]
	var want := 0 if _scale >= 0.99 else 1
	if want != _mode:
		_mode = want
		if _quad.get_parent() != null:
			_quad.get_parent().remove_child(_quad)
		if want == 0:
			_free_sub()
			add_child(_quad)
		else:
			_build_sub()
			_sub.add_child(_quad)
	_resize_sub()


func _build_sub() -> void:
	_free_sub()
	_sub = SubViewport.new()
	_sub.disable_3d = true
	_sub.transparent_bg = false
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sub.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	add_child(_sub)
	_sub_cam = Camera2D.new()
	_sub.add_child(_sub_cam)
	_sub_cam.make_current()
	_bg_layer = CanvasLayer.new()
	_bg_layer.layer = -10
	add_child(_bg_layer)
	_bg_rect = TextureRect.new()
	_bg_rect.texture = _sub.get_texture()
	_bg_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_layer.add_child(_bg_rect)


func _free_sub() -> void:
	for n in [_bg_layer, _sub]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_sub = null
	_sub_cam = null
	_bg_layer = null
	_bg_rect = null


func _resize_sub() -> void:
	if _sub == null:
		return
	var win := Vector2(DisplayServer.window_get_size())
	if win.x < 1.0:
		win = get_viewport().get_visible_rect().size
	_sub.size = Vector2i((win * _scale).ceil())


## Keeps the sub-viewport camera glued to the main one. Call every frame.
func sync_camera(center: Vector2, zoom: float) -> void:
	if _sub == null:
		return
	var virtual_w := get_viewport().get_visible_rect().size.x
	if virtual_w < 1.0:
		return
	var want := Vector2(DisplayServer.window_get_size())
	if want.x >= 1.0 and Vector2i((want * _scale).ceil()) != _sub.size:
		_resize_sub()
	_sub_cam.position = center
	_sub_cam.zoom = Vector2.ONE * zoom * (float(_sub.size.x) / virtual_w)
