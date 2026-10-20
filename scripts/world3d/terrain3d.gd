class_name Terrain3D
extends Node3D
## Land as chunked meshes. Geometry is only a flat grid; the vertex shader lifts
## it from the height field, so the CPU just decides which chunks have land.

const CHUNK := 24      # cells per chunk side
const STEP := 0.5      # vertex spacing in cells

var material: ShaderMaterial
var chunks := {}


func build(gen: WorldGen, world: SeaWorld) -> void:
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/3d/terrain.gdshader")
	material.set_shader_parameter("height_tex", world.height_tex)
	material.set_shader_parameter("explored_tex", world.fog.texture)
	material.set_shader_parameter("noise_tex", load("res://assets/textures/noise_atlas.png"))
	var nx := ceili(float(WorldGen.GRID_W) / CHUNK)
	var nz := ceili(float(WorldGen.GRID_H) / CHUNK)
	var n := int(CHUNK / STEP)
	var verts_per_side := n + 1
	for cz in nz:
		for cx in nx:
			var x0 := cx * CHUNK
			var z0 := cz * CHUNK
			if not _has_land(gen, x0, z0):
				continue
			var heights := PackedFloat32Array()
			heights.resize(verts_per_side * verts_per_side)
			for j in verts_per_side:
				for i in verts_per_side:
					heights[j * verts_per_side + i] = gen.height_at(Vector2((x0 + i * STEP) * WorldGen.CELL, (z0 + j * STEP) * WorldGen.CELL))
			var indices := PackedInt32Array()
			for j in n:
				for i in n:
					var a := j * verts_per_side + i
					if maxf(maxf(heights[a], heights[a + 1]), maxf(heights[a + verts_per_side], heights[a + verts_per_side + 1])) < WorldGen.SEA - 0.035:
						continue
					indices.append_array([a, a + 1, a + verts_per_side, a + 1, a + verts_per_side + 1, a + verts_per_side])
			if indices.is_empty():
				continue
			var verts := PackedVector3Array()
			verts.resize(verts_per_side * verts_per_side)
			for j in verts_per_side:
				for i in verts_per_side:
					verts[j * verts_per_side + i] = Vector3(x0 + i * STEP, 0.0, z0 + j * STEP)
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = verts
			arrays[Mesh.ARRAY_INDEX] = indices
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.custom_aabb = AABB(Vector3(x0, -1.0, z0), Vector3(CHUNK, Space3D.HS * 0.55 + 4.0, CHUNK))
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.material_override = material
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			add_child(mi)
			chunks[Vector2i(cx, cz)] = mi


func _has_land(gen: WorldGen, x0: int, z0: int) -> bool:
	for j in range(0, CHUNK + 1, 3):
		for i in range(0, CHUNK + 1, 3):
			if gen.height_at(Vector2((x0 + i) * WorldGen.CELL, (z0 + j) * WorldGen.CELL)) > WorldGen.SEA - 0.04:
				return true
	return false
