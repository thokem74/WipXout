@tool
class_name TrackJump
extends Node3D
## The road stays continuous: this low ramp launches ships into a forgiving arc.

@export var takeoff_distance: float = 1250.0
@export_range(0.1, 0.3) var launch_strength: float = 0.18
@export var approach_length: float = 45.0
@export var landing_length: float = 65.0
@export var ramp_height: float = 1.4


func surface_height(distance: float) -> float:
	var offset := distance - takeoff_distance
	if offset < -approach_length or offset > landing_length:
		return 0.0
	var fraction := (offset + approach_length) / approach_length if offset < 0.0 else (
		1.0 - offset / landing_length)
	# Level ends avoid a visible seam where the ramp meets the underlying road.
	return ramp_height * smoothstep(0.0, 1.0, fraction)


func build(circuit: Circuit) -> void:
	var markings: Array = []
	for offset: float in [-38.0, -26.0, -14.0, -2.0]:
		var here := circuit.surface_frame(takeoff_distance + offset)
		for side: float in [-1.0, 1.0]:
			NeonLines.add_line(markings, here * Vector3(side * 10, 0.12, 3),
				here * Vector3(0, 0.12, -2))
	var lip := circuit.surface_frame(takeoff_distance)
	NeonLines.add_line(markings, lip * Vector3(-13, 0.12, 0), lip * Vector3(13, 0.12, 0))
	$Markings.mesh = NeonLines.mesh(markings, 0.22)
	$Label.transform = circuit.surface_frame(takeoff_distance - 36.0)
	$Label.position += $Label.basis.y * 4.0
