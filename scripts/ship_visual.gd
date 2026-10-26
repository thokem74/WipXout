@tool
extends Node3D

@export var color: Color = Color(1, 0.015, 0.8):
	set(value):
		color = value
		if is_inside_tree():
			build()


func _ready() -> void:
	build()


func set_color(value: Color) -> void:
	color = value


func build() -> void:
	var points: Array[Vector3] = [
		Vector3(0, 0, -4.2),
		Vector3(-1.0, 0, -0.4),
		Vector3(-4.2, -0.3, 2.5),
		Vector3(-1.6, -0.1, 1.8),
		Vector3(-0.85, 0.15, 2.5),
		Vector3(0.85, 0.15, 2.5),
		Vector3(1.6, -0.1, 1.8),
		Vector3(4.2, -0.3, 2.5),
		Vector3(1, 0, -0.4),
		Vector3(0, 1.0, -2.0),
		Vector3(-0.62, 0.9, 0.1),
		Vector3(0.62, 0.9, 0.1),
		Vector3(-0.65, 0.65, 1.9),
		Vector3(0.65, 0.65, 1.9),
	]
	var edges := [
		[0, 1],
		[1, 2],
		[2, 3],
		[3, 4],
		[4, 5],
		[5, 6],
		[6, 7],
		[7, 8],
		[8, 0],
		[0, 9],
		[9, 10],
		[9, 11],
		[10, 11],
		[10, 12],
		[11, 13],
		[12, 13],
		[12, 4],
		[13, 5],
		[1, 10],
		[8, 11],
		[1, 3],
		[8, 6],
		[2, 10],
		[7, 11],
		[3, 12],
		[6, 13],
		[0, 4],
		[0, 5],
	]
	var lines: Array = []
	for edge: Array in edges:
		NeonLines.add_line(lines, points[edge[0]], points[edge[1]])
	for side: float in [-1.0, 1.0]:
		var center := Vector3(side * 1.2, 0.0, 2.2)
		for segment_index in range(6):
			var angle := segment_index * TAU / 6.0
			var next_angle := (segment_index + 1) * TAU / 6.0
			var first := Vector3(cos(angle), sin(angle), 0) * 0.38
			var second := Vector3(cos(next_angle), sin(next_angle), 0) * 0.38
			NeonLines.add_line(lines, center + first, center + second)
			NeonLines.add_line(lines, center + first, center + first - Vector3(0, 0, 0.7))
	$Core.mesh = NeonLines.mesh(lines, 0.065)
	$Core.material_override = NeonLines.material(color, 2.4)
	$Halo.mesh = NeonLines.mesh(lines, 0.36)
	$Halo.material_override = NeonLines.halo_material(color)
