@tool
class_name TrackTunnel
extends Node3D
## Static enclosure sampled from the road; placement stays editable in the scene.

const HALF_WIDTH: float = 17.0
const HEIGHT: float = 13.0
const STEP: float = 6.0

@export var start_distance: float = 0.0
@export_range(100.0, 1000.0) var tunnel_length: float = 550.0
@export var neon_color: Color = Color(0.05, 0.8, 1.0)


func build(circuit: Circuit) -> void:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var ribs: Array = []
	var guides: Array = []
	# Chamfered shoulders leave a broad ceiling above the chase camera.
	var profile: Array[Vector3] = [
		Vector3(-HALF_WIDTH, -0.3, 0),
		Vector3(-HALF_WIDTH, 9, 0),
		Vector3(-12, HEIGHT, 0),
		Vector3(12, HEIGHT, 0),
		Vector3(HALF_WIDTH, 9, 0),
		Vector3(HALF_WIDTH, -0.3, 0),
		Vector3(-HALF_WIDTH, -0.3, 0),
	]
	var sample_count := ceili(tunnel_length / STEP)
	for sample_index in range(sample_count + 1):
		var distance := start_distance + tunnel_length * float(sample_index) / sample_count
		var current_frame := circuit.frame(distance)
		for point: Vector3 in profile:
			vertices.append(current_frame * point)
		if sample_index % 3 == 0 or sample_index == sample_count:
			for edge in range(profile.size() - 1):
				NeonLines.add_line(
						ribs, current_frame * profile[edge], current_frame * profile[edge + 1]
				)
		if sample_index == sample_count:
			continue
		var next_frame := circuit.frame(
				start_distance + tunnel_length * float(sample_index + 1) / sample_count
		)
		for side: float in [-1.0, 1.0]:
			for height: float in [3.5, 8.8]:
				NeonLines.add_line(
						guides,
						current_frame * Vector3(side * 16.8, height, 0),
						next_frame * Vector3(side * 16.8, height, 0)
				)
		for edge in range(profile.size() - 1):
			var base := sample_index * profile.size() + edge
			var next := base + profile.size()
			indices.append_array(PackedInt32Array([base, next, next + 1, base, next + 1, base + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var shell := ArrayMesh.new()
	shell.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	$Shell.mesh = shell
	$Ribs.material_override = NeonLines.material(neon_color, 2.1)
	$Guides.material_override = NeonLines.material(neon_color.lightened(0.25), 1.7)
	$Ribs.mesh = NeonLines.mesh(ribs, 0.18)
	$Guides.mesh = NeonLines.mesh(guides, 0.10)
