extends Camera3D

@export var tuning: RaceTuning
var target: Racer
var shake_enabled: bool = true
var time: float = 0.0
var snap_next: bool = true


func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	time += delta
	var path_frame := target.circuit.surface_frame(target.track_distance)
	# Road-relative offsets keep the camera above the surface on hills.
	var desired := (target.global_position + path_frame.basis.z * tuning.camera_distance
		+ path_frame.basis.y * tuning.camera_height)
	var look_point := (target.global_position - path_frame.basis.z * 19.0
		+ path_frame.basis.y * 0.8)
	if shake_enabled and target.boost_active:
		desired += path_frame.basis.x * sin(time * 34.0) * 0.045
	if snap_next:
		global_position = desired
		snap_next = false
	else:
		global_position = global_position.lerp(desired, 1.0 - exp(-delta * tuning.camera_response))
	look_at(look_point, Vector3.UP)
	fov = lerpf(fov, 70.0 + target.speed / tuning.boost_speed * 9.0, 1.0 - exp(-delta * 3.0))
