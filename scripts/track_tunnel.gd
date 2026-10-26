@tool
class_name TrackTunnel
extends Node3D
## Static enclosure sampled from the road; placement stays editable in the scene.

const HALF_WIDTH: float = 17.0
const HEIGHT: float = 13.0
const STEP: float = 6.0

@export var start_distance: float = 0.0
@export_range(600.0, 800.0) var tunnel_length: float = 700.0


func build(circuit: Circuit) -> void:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var ribs: Array = []
	var guides: Array = []
	# Chamfered shoulders leave a broad ceiling above the chase camera.
	var profile: Array[Vector3] = [Vector3(-HALF_WIDTH, -0.3, 0),
		Vector3(-HALF_WIDTH, 9, 0), Vector3(-12, HEIGHT, 0),
		Vector3(12, HEIGHT, 0), Vector3(HALF_WIDTH, 9, 0),
		Vector3(HALF_WIDTH, -0.3, 0), Vector3(-HALF_WIDTH, -0.3, 0)]
	var count := ceili(tunnel_length / STEP)
	for i in range(count + 1):
		var distance := start_distance + tunnel_length * float(i) / count
		var here := circuit.frame(distance)
		for point: Vector3 in profile:
			vertices.append(here * point)
		if i % 4 == 0 or i == count:
			for edge in range(profile.size() - 1):
				NeonLines.add_line(ribs, here * profile[edge], here * profile[edge + 1])
		if i == count:
			continue
		var there := circuit.frame(start_distance + tunnel_length * float(i + 1) / count)
		for side: float in [-1.0, 1.0]:
			for height: float in [3.5, 8.8]:
				NeonLines.add_line(guides, here * Vector3(side * 16.8, height, 0),
					there * Vector3(side * 16.8, height, 0))
		for edge in range(profile.size() - 1):
			var base := i * profile.size() + edge
			var next := base + profile.size()
			indices.append_array(PackedInt32Array([base, next, next + 1, base, next + 1, base + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var shell := ArrayMesh.new()
	shell.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	$Shell.mesh = shell
	$Ribs.mesh = NeonLines.mesh(ribs, 0.18)
	$Guides.mesh = NeonLines.mesh(guides, 0.10)
