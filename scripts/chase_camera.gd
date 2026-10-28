extends Camera3D

@export var tuning: RaceTuning
var target: Racer
var shake_enabled: bool = true
var time: float = 0.0
var snap_next: bool = true
var impulse: float = 0.0


func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	time += delta
	var path_frame := target.circuit.surface_frame(target.track_distance)
	# Road-relative offsets keep the camera above the surface on hills.
	var desired := (
			target.global_position
			+ path_frame.basis.z * tuning.camera_distance
			+ path_frame.basis.y * tuning.camera_height
	)
	# Anticipate the actual road, including linked bends and steep descents.
	var ahead := target.circuit.surface_frame(target.track_distance + tuning.camera_lookahead)
	var look_point := ahead.origin + ahead.basis.x * target.lateral_offset
	look_point += path_frame.basis.y * (tuning.hover_height + target.air_height + 0.8)
	impulse = move_toward(impulse, 0.0, delta * 1.8)
	if shake_enabled:
		desired += path_frame.basis.y * sin(time * 45.0) * impulse
	if shake_enabled and target.boost_active:
		desired += path_frame.basis.x * sin(time * 34.0) * 0.045
	if snap_next:
		global_position = desired
		snap_next = false
	else:
		global_position = global_position.lerp(desired, 1.0 - exp(-delta * tuning.camera_response))
	look_at(look_point, Vector3.UP)
	var target_fov := 70.0 + target.speed / tuning.boost_speed * tuning.camera_speed_fov
	if target.boost_active:
		target_fov += tuning.camera_boost_fov
	fov = lerpf(fov, target_fov, 1.0 - exp(-delta * 3.0))


func add_impulse(strength: float) -> void:
	if shake_enabled:
		impulse = minf(maxf(impulse, strength), tuning.maximum_camera_impulse)


func clear_impulse() -> void:
	impulse = 0.0
