class_name Racer
extends Node3D

@export var tuning: RaceTuning
@export var racer_name: String = "VECTOR"
@export var ai_index: int = -1
@export var neon_color: Color = Color(1, 0.015, 0.8)

var circuit: Circuit
var progress: RaceProgress
var track_distance: float = 0.0
var lateral_offset: float = 0.0
var lateral_velocity: float = 0.0
var speed: float = 0.0
var boost_charge: float = 1.0
var boost_active: bool = false
var recharge_delay: float = 0.0
var boost_locked: bool = false
var wall_cooldown: float = 0.0
var wall_hit: bool = false
var visual_time: float = 0.0
var finished_rank: int = 0


func setup(track: Circuit, start_distance: float, lane: float) -> void:
	circuit = track
	progress = RaceProgress.new(track.length)
	reset(start_distance, lane)
	$Wireframe.set_color(neon_color)


func reset(start_distance: float = 0.0, lane: float = 0.0) -> void:
	track_distance = start_distance
	lateral_offset = lane
	lateral_velocity = 0.0
	speed = 0.0
	boost_charge = 1.0
	boost_active = false
	boost_locked = false
	recharge_delay = 0.0
	wall_cooldown = 0.0
	finished_rank = 0
	visual_time = 0.0
	progress.reset(start_distance)
	$Wireframe.reset_propulsion()
	update_pose(0.0)


func ai_input(time: float) -> Vector3:
	var bend := absf(circuit.curvature(track_distance + 55.0))
	var target_speed: float = tuning.ai_speeds[ai_index]
	target_speed *= clampf(1.0 - bend * (25.0 + ai_index * 5.0), 0.69, 1.0)
	var desired_lane := sin(time * (0.22 + ai_index * 0.04) + ai_index * 2.0) * 5.0
	var steering := clampf((desired_lane - lateral_offset) * 0.25 - lateral_velocity * 0.12, -1, 1)
	var throttle := clampf((target_speed - speed) * 0.25, -1, 1)
	var boost := 1.0 if bend < 0.0015 and speed > 65 and boost_charge > 0.4 and sin(time * 0.16 + ai_index) > 0.6 else 0.0
	return Vector3(steering, throttle, boost)


func simulate(delta: float, controls: Vector3, race_time: float) -> void:
	wall_hit = false
	wall_cooldown = maxf(0.0, wall_cooldown - delta)
	if progress.finish_time >= 0.0:
		boost_active = false
		speed = move_toward(speed, 0.0, 25.0 * delta)
		update_pose(delta)
		return
	var throttle := clampf(controls.y, -1.0, 1.0)
	if boost_locked and boost_charge >= 0.25:
		boost_locked = false
	boost_active = controls.z > 0.5 and boost_charge > 0.0 and not boost_locked and throttle >= 0.0
	if boost_active:
		boost_charge = maxf(0.0, boost_charge - tuning.boost_drain * delta)
		recharge_delay = tuning.boost_cooldown
		if boost_charge == 0.0:
			boost_locked = true
	else:
		recharge_delay = maxf(0.0, recharge_delay - delta)
		if recharge_delay == 0.0:
			boost_charge = minf(1.0, boost_charge + tuning.boost_recharge * delta)
	var maximum := tuning.boost_speed if boost_active else tuning.top_speed
	var force := throttle * (tuning.acceleration if throttle >= 0 else tuning.braking)
	if boost_active:
		force = tuning.acceleration * 1.8
	if absf(throttle) < 0.05 and not boost_active:
		force = -tuning.coast_drag
	if speed > maximum:
		speed = move_toward(speed, maximum, maxf(18.0, -force) * delta)
	else:
		speed = clampf(speed + force * delta, 0.0, maximum)
	var turn := circuit.curvature(track_distance)
	# A gentle outward drift makes lines meaningful without requiring vehicle physics.
	lateral_velocity += (controls.x * tuning.steering_acceleration + turn * speed * speed * 0.16) * delta
	lateral_velocity *= exp(-tuning.lateral_damping * delta)
	lateral_offset += lateral_velocity * delta
	var limit := Circuit.WIDTH / 2.0 - 2.0
	if absf(lateral_offset) > limit:
		if absf(lateral_offset) > Circuit.WIDTH * 1.5:
			recover()
		else:
			lateral_offset = clampf(lateral_offset, -limit, limit)
			lateral_velocity = -signf(lateral_offset) * 3.0
			if wall_cooldown <= 0.0:
				speed *= tuning.wall_speed_retention
				wall_hit = true
				wall_cooldown = 0.6
	var next_distance := track_distance + speed * delta
	if progress.advance(next_distance, delta, race_time):
		track_distance = next_distance
	else:
		recover()
	update_pose(delta)


func recover() -> void:
	track_distance = progress.distance
	lateral_offset = 0.0
	lateral_velocity = 0.0
	speed *= 0.45
	boost_active = false


func update_pose(delta: float) -> void:
	visual_time += delta
	transform = circuit.frame(track_distance)
	position += basis.x * lateral_offset + basis.y * (tuning.hover_height + sin(visual_time * 3.0) * 0.10)
	$Wireframe.rotation.z = lerp_angle($Wireframe.rotation.z, -lateral_velocity * 0.035, 1.0 - exp(-delta * 8.0))
	$Wireframe.rotation.y = -lateral_velocity * 0.012
	$Wireframe.set_propulsion(speed / tuning.top_speed, boost_active)
