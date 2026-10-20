class_name Water3D
extends MeshInstance3D
## The sea: one dense plane that follows the camera. Waves are computed from
## world position in the shader, so nothing swims when the plane moves.

var material: ShaderMaterial


func setup(world: SeaWorld) -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(110.0, 240.0)
	pm.subdivide_width = 110
	pm.subdivide_depth = 240
	mesh = pm
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/3d/water.gdshader")
	material.set_shader_parameter("height_tex", world.height_tex)
	material.set_shader_parameter("explored_tex", world.fog.texture)
	material.set_shader_parameter("noise_tex", load("res://assets/textures/noise_atlas.png"))
	var w := Art.white()
	Art.bind(material, "art_foam", "has_foam", "water/foam", w)
	Art.bind(material, "art_caustics", "has_caustics", "water/caustics", w)
	Art.bind(material, "art_wavenorm", "has_wavenorm", "water/wave_normal", w)
	Art.bind(material, "art_seabed", "has_seabed", "water/seabed_sand", w)
	Art.bind(material, "art_reef", "has_reef", "water/reef", w)
	material.render_priority = 0
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16.0


func follow(target: Vector3) -> void:
	position = Vector3(roundf(target.x), 0.0, roundf(target.z))
