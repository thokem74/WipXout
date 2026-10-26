@tool
class_name NeonLines
extends RefCounted
## One indexed triangle batch per colour, independent of polygon wireframe support.


static func material(color: Color, energy: float = 1.5) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = preload("res://resources/neon_core.gdshader")
	result.set_shader_parameter("line_color", color)
	result.set_shader_parameter("energy", energy)
	return result


static func mesh(segments: Array, width: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	for segment: PackedVector3Array in segments:
		var start: Vector3 = segment[0]
		var end: Vector3 = segment[1]
		var direction := (end - start).normalized()
		if direction.length_squared() < 0.5:
			continue
		var axis := Vector3.UP if absf(direction.y) < 0.95 else Vector3.RIGHT
		var side := direction.cross(axis).normalized() * width * 0.5
		var up := direction.cross(side).normalized() * width * 0.5
		var base := vertices.size()
		# Crossed ribbons have a bright core from all viewing directions.
		vertices.append_array(
				PackedVector3Array(
						[
							start - side,
							start + side,
							end + side,
							end - side,
							start - up,
							start + up,
							end + up,
							end - up,
						]
				)
		)
		var offsets: Array[Vector3] = [-side, side, side, -side, -up, up, up, -up]
		for vertex_index in range(8):
			normals.append(offsets[vertex_index].normalized())
			uvs.append(Vector2(width * 0.5, 1.0 if vertex_index % 4 in [1, 2] else 0.0))
		for offset: int in [0, 4]:
			indices.append_array(
					PackedInt32Array(
							[
								base + offset,
								base + offset + 1,
								base + offset + 2,
								base + offset,
								base + offset + 2,
								base + offset + 3,
							]
					)
			)
	var result := ArrayMesh.new()
	if vertices.is_empty():
		return result
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result


static func add_line(lines: Array, start: Vector3, end: Vector3) -> void:
	lines.append(PackedVector3Array([start, end]))


static func halo_material(color: Color) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = preload("res://resources/neon_halo.gdshader")
	result.set_shader_parameter("line_color", color)
	return result
