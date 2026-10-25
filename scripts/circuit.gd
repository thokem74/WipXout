@tool
class_name Circuit
extends Node3D
## The Curve3D is the single source of truth for geometry and racer progress.

const WIDTH: float = 26.0
const CHECKPOINT_COUNT: int = 16
const SAMPLE_STEP: float = 8.0

@onready var route: Path3D = $Route
var length: float = 0.0


func _ready() -> void:
	length = route.curve.get_baked_length()
	build_track()
	build_city()
	build_landmarks()


func frame(distance: float) -> Transform3D:
	var offset := fposmod(distance, length)
	var position_on_path := route.curve.sample_baked(offset, true)
	# Sampling across the seam avoids an orientation discontinuity at lap start.
	var ahead := route.curve.sample_baked(fposmod(offset + 2.0, length), true)
	var behind := route.curve.sample_baked(fposmod(offset - 2.0, length), true)
	var forward := (ahead - behind).normalized()
	var right := forward.cross(Vector3.UP).normalized()
	var up := right.cross(forward).normalized()
	return Transform3D(Basis(right, up, -forward), position_on_path)


func curvature(distance: float) -> float:
	var first := -frame(distance).basis.z
	var second := -frame(distance + 28.0).basis.z
	# Steering responds to heading changes, not the pitch of a climb or descent.
	first.y = 0.0
	second.y = 0.0
	return first.normalized().signed_angle_to(second.normalized(), Vector3.UP) / 28.0


func build_track() -> void:
	var rails: Array = []
	var grid: Array = []
	var chevrons: Array = []
	var supports: Array = []
	var road_vertices := PackedVector3Array()
	var road_indices := PackedInt32Array()
	var samples := ceili(length / SAMPLE_STEP)
	for i in range(samples):
		var distance := float(i) / samples * length
		var next_distance := float(i + 1) / samples * length
		var here := frame(distance)
		var there := frame(next_distance)
		for side: float in [-1.0, 1.0]:
			for height: float in [0.10, 2.2]:
				NeonLines.add_line(rails, here * Vector3(side * WIDTH / 2.0, height, 0),
					there * Vector3(side * WIDTH / 2.0, height, 0))
			if i % 3 == 0:
				NeonLines.add_line(rails, here * Vector3(side * WIDTH / 2.0, 0, 0),
					here * Vector3(side * WIDTH / 2.0, 2.2, 0))
		for lane: float in [-0.75, -0.5, -0.25, 0.0, 0.25, 0.5, 0.75]:
			NeonLines.add_line(grid, here * Vector3(lane * WIDTH / 2.0, 0.035, 0),
				there * Vector3(lane * WIDTH / 2.0, 0.035, 0))
		if i % 2 == 0:
			NeonLines.add_line(grid, here * Vector3(-WIDTH / 2.0, 0.04, 0),
				here * Vector3(WIDTH / 2.0, 0.04, 0))
		var base := road_vertices.size()
		road_vertices.append_array(PackedVector3Array([
			here * Vector3(-WIDTH / 2.0 - 0.4, -0.08, 0),
			here * Vector3(WIDTH / 2.0 + 0.4, -0.08, 0),
			there * Vector3(WIDTH / 2.0 + 0.4, -0.08, 0),
			there * Vector3(-WIDTH / 2.0 - 0.4, -0.08, 0)]))
		road_indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
		if i % 5 == 0 and absf(curvature(distance)) > 0.0006:
			var turn := signf(curvature(distance))
			var marker := here * Vector3(turn * (WIDTH / 2.0 - 0.5), 3.2, 0)
			var along := -here.basis.z * 2.0
			var up := Vector3.UP * 1.0
			NeonLines.add_line(chevrons, marker - along - up, marker + along)
			NeonLines.add_line(chevrons, marker + along, marker - along + up)
		if i % 18 == 0:
			for side: float in [-1.0, 1.0]:
				var top := here * Vector3(side * 12.0, -0.3, 0)
				var bottom := Vector3(top.x, -55, top.z)
				NeonLines.add_line(supports, top, bottom)
				NeonLines.add_line(supports, top + here.basis.z * 6, bottom)
	$Rails.mesh = NeonLines.mesh(rails, 0.14)
	$Rails.material_override = NeonLines.material(Color(0.0, 0.74, 1.0), 2.0)
	$Grid.mesh = NeonLines.mesh(grid, 0.045)
	$Grid.material_override = NeonLines.material(Color(0.12, 0.065, 0.38), 0.25)
	$Chevrons.mesh = NeonLines.mesh(chevrons, 0.20)
	$Chevrons.material_override = NeonLines.material(Color(1.0, 0.01, 0.65), 2.0)
	$Supports.mesh = NeonLines.mesh(supports, 0.09)
	$Supports.material_override = NeonLines.material(Color(0.025, 0.16, 0.3), 0.4)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = road_vertices
	arrays[Mesh.ARRAY_INDEX] = road_indices
	var road := ArrayMesh.new()
	road.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	$RoadOccluder.mesh = road
	var road_material := StandardMaterial3D.new()
	road_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	road_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	road_material.albedo_color = Color(0.001, 0.001, 0.004)
	$RoadOccluder.material_override = road_material
	build_start_gate()


func build_start_gate() -> void:
	var lines: Array = []
	var start := frame(0)
	for x in range(-13, 14):
		NeonLines.add_line(lines, start * Vector3(x, 0.1, -1.5), start * Vector3(x, 0.1, 1.5))
	for side: float in [-1.0, 1.0]:
		NeonLines.add_line(lines, start * Vector3(side * 14, 0, 0), start * Vector3(side * 14, 10, 0))
	NeonLines.add_line(lines, start * Vector3(-14, 10, 0), start * Vector3(14, 10, 0))
	$StartGate.mesh = NeonLines.mesh(lines, 0.15)
	$StartGate.material_override = NeonLines.material(Color(0.8, 0.08, 1.0), 2.0)
	$GateLabel.transform = start
	$GateLabel.position += Vector3(0, 8, 0)


func build_city() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 1986
	for chunk_index in range(40):
		var lines: Array = []
		var extra: Array = []
		for building_index in range(6):
			var distance := (chunk_index + building_index / 6.0) / 40.0 * length
			var path_frame := frame(distance)
			var side := -1.0 if building_index % 2 == 0 else 1.0
			var center := path_frame * Vector3(side * random.randf_range(45, 220), 0, 0)
			center.y = -50
			var height := random.randf_range(65, 210)
			var width := random.randf_range(10, 26)
			var depth := random.randf_range(10, 25)
			# Inside a tight bend, an offset building can reach another part of the road.
			# Leave a conservative footprint clearance along the whole route.
			var clearance := Vector2(width, depth).length() + WIDTH / 2.0 + 4.0
			if not has_scenery_clearance(center, clearance):
				# Consume the skipped antenna height to keep later scenery deterministic.
				random.randf_range(8, 28)
				continue
			var corners: Array[Vector3] = []
			for corner: Vector3 in [Vector3(-width, 0, -depth), Vector3(width, 0, -depth),
					Vector3(width, 0, depth), Vector3(-width, 0, depth)]:
				corners.append(center + corner)
			for j in range(4):
				NeonLines.add_line(lines, corners[j], corners[j] + Vector3.UP * height)
				NeonLines.add_line(lines, corners[j] + Vector3.UP * height,
					corners[(j + 1) % 4] + Vector3.UP * height)
				for floor_height: float in [height * 0.4, height * 0.72]:
					NeonLines.add_line(extra, corners[j] + Vector3.UP * floor_height,
						corners[(j + 1) % 4] + Vector3.UP * floor_height)
			var roof := center + Vector3.UP * height
			NeonLines.add_line(lines, roof, roof + Vector3.UP * random.randf_range(8, 28))
		var chunk := MeshInstance3D.new()
		chunk.name = "CityChunk%02d" % chunk_index
		chunk.mesh = NeonLines.mesh(lines, 0.24)
		var colors := [Color(0.025, 0.32, 0.65), Color(0.18, 0.07, 0.55), Color(0.4, 0.02, 0.48)]
		chunk.material_override = NeonLines.material(colors[chunk_index % 3], 0.5)
		chunk.visibility_range_end = 1100.0
		chunk.visibility_range_end_margin = 100.0
		$City.add_child(chunk)
		var detail := MeshInstance3D.new()
		detail.mesh = NeonLines.mesh(extra, 0.15)
		detail.material_override = chunk.material_override
		detail.visibility_range_end = 650.0
		$City.add_child(detail)


func has_scenery_clearance(center: Vector3, clearance: float) -> bool:
	# Buildings span the track's elevation, so check their horizontal footprint.
	var footprint := Vector2(center.x, center.z)
	for point in route.curve.get_baked_points():
		if footprint.distance_squared_to(Vector2(point.x, point.z)) < clearance * clearance:
			return false
	return true


func build_landmarks() -> void:
	var lines: Array = []
	for landmark_index in range(5):
		var path_frame := frame((landmark_index + 0.35) / 5.0 * length)
		var center := path_frame * Vector3(-110.0, 110.0, 0)
		for height: float in [-1.5, 1.5]:
			for segment in range(48):
				var angle := segment * TAU / 48.0
				var next_angle := (segment + 1) * TAU / 48.0
				NeonLines.add_line(lines, center + Vector3(cos(angle) * 28, height, sin(angle) * 28),
					center + Vector3(cos(next_angle) * 28, height, sin(next_angle) * 28))
		for side: float in [-1.0, 1.0]:
			for axis: Vector3 in [Vector3.RIGHT, Vector3.FORWARD]:
				var base := center + axis * side * 8
				NeonLines.add_line(lines, base - Vector3.UP * 150, base + Vector3.UP * 42)
				NeonLines.add_line(lines, base + Vector3.UP * 42, center + Vector3.UP * 57)
		NeonLines.add_line(lines, center + Vector3.UP * 57, center + Vector3.UP * 75)
	$Landmarks.mesh = NeonLines.mesh(lines, 0.19)
	$Landmarks.material_override = NeonLines.material(Color(0.04, 0.45, 0.7), 0.7)
