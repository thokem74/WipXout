class_name Racer
extends Node3D

@export var profile: PilotProfile
@export var tuning: RaceTuning
@export var racer_name: String = "VECTOR"
@export var ai_index: int = -1
@export var neon_color: Color = Color(1, 0.015, 0.8)

var took_off: bool = false
var landed: bool = false
var airborne: bool = false
var air_height: float = 0.0
var vertical_velocity: float = 0.0
var previous_air_height: float = 0.0

var circuit: Circuit
var progress: RaceProgress
var track_distance: float = 0.0
var lateral_offset: float = 0.0
var lateral_velocity: float = 0.0
var speed: float = 0.0
var engine_load: float = 0.0
var boost_charge: float = 1.0
var boost_active: bool = false
var recharge_delay: float = 0.0
var boost_locked: bool = false
var wall_cooldown: float = 0.0
var wall_hit: bool = false
var visual_time: float = 0.0
var finished_rank: int = 0
var previous_track_distance: float = 0.0
var previous_lateral_offset: float = 0.0
var contact_hit: bool = false
var contact_cooldown: float = 0.0

@onready var effects: Node3D = $Effects
@onready var collision_shape: CollisionShape3D = $CollisionHull/CollisionShape3D


func setup(track: Circuit, start_distance: float, lane: float) -> void:
	circuit = track
	progress = RaceProgress.new(track.length)
	reset(start_distance, lane)
	$Wireframe.set_color(neon_color)


func reset(start_distance: float = 0.0, lane: float = 0.0) -> void:
	clear_flight()
	effects.stop()
	effects.set_color(neon_color)
	track_distance = start_distance
	lateral_offset = lane
	lateral_velocity = 0.0
	speed = 0.0
	engine_load = 0.0
	boost_charge = 1.0
	boost_active = false
	boost_locked = false
	recharge_delay = 0.0
	wall_cooldown = 0.0
	finished_rank = 0
	visual_time = 0.0
	previous_track_distance = start_distance
	previous_lateral_offset = lane
	contact_hit = false
	contact_cooldown = 0.0
	progress.reset(start_distance)
	update_pose(0.0)


func ai_input(time: float) -> Vector3:
	# Look across the braking distance so linked corners cannot hide behind a
	# gentle section. Air steering is weaker, so AI holds a steady landing lane.
	var bend := 0.0
	for sample in range(4):
		var lookahead := float(sample) * 40.0
		bend = maxf(bend, absf(circuit.curvature(track_distance + lookahead)))
	var target_speed: float = profile.cruise_speed
	target_speed *= clampf(1.0 - bend * (25.0 + min(ai_index, 2) * 5.0), 0.69, 1.0)
	var lane_amplitude := 2.0 if airborne else 5.0
	var desired_lane := sin(time * (0.22 + ai_index * 0.04) + ai_index * 2.0) * lane_amplitude
	var steering := clampf((desired_lane - lateral_offset) * 0.25 - lateral_velocity * 0.12, -1, 1)
	var throttle := clampf((target_speed - speed) * 0.25, -1, 1)
	var can_boost := bend < 0.0015 and speed > 65 and boost_charge > 0.4
	var boost := 1.0 if can_boost and sin(time * 0.16 + ai_index) > 0.6 else 0.0
	return Vector3(steering, throttle, boost)


func simulate(delta: float, controls: Vector3, race_time: float) -> void:
	prepare_step(delta, controls)
	finish_step(delta, race_time)


func prepare_step(delta: float, controls: Vector3) -> void:
	# Keep the start of the sweep; contacts are resolved before committing progress.
	took_off = false
	landed = false
	previous_track_distance = track_distance
	previous_lateral_offset = lateral_offset
	previous_air_height = air_height
	contact_hit = false
	contact_cooldown = maxf(0.0, contact_cooldown - delta)
	wall_hit = false
	wall_cooldown = maxf(0.0, wall_cooldown - delta)
	if progress.finish_time >= 0.0:
		engine_load = 0.0
		boost_active = false
		speed = move_toward(speed, 0.0, 25.0 * delta)
		return
	advance_flight(delta)
	var throttle := clampf(controls.y, -1.0, 1.0)
	if boost_locked and boost_charge >= 0.25:
		boost_locked = false
	boost_active = controls.z > 0.5 and boost_charge > 0.0 and not boost_locked and throttle >= 0.0
	# Audio load follows the pilot's demand independently of the current speed.
	engine_load = 1.0 if boost_active else maxf(throttle, 0.0)
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
	var steering_force := controls.x * tuning.steering_acceleration
	if airborne:
		steering_force *= tuning.air_steering_factor
	lateral_velocity += (steering_force + turn * speed * speed * 0.16) * delta
	lateral_velocity *= exp(-tuning.lateral_damping * delta)
	lateral_offset += lateral_velocity * delta
	var limit := lateral_limit()
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
	track_distance += speed * delta


func finish_step(delta: float, race_time: float) -> void:
	if progress.finish_time >= 0.0:
		clear_flight()
		update_pose(delta)
		return
	if not progress.advance(track_distance, delta, race_time):
		recover()
	if progress.finish_time >= 0.0:
		engine_load = 0.0
		clear_flight()
	else:
		try_takeoff(delta)
	update_pose(delta)
	effects.update_racer(self, delta)


func clear_flight() -> void:
	took_off = false
	landed = false
	airborne = false
	air_height = 0.0
	previous_air_height = 0.0
	vertical_velocity = 0.0
	$Wireframe.rotation.x = 0.0


func advance_flight(delta: float) -> void:
	if not airborne:
		return
	air_height += vertical_velocity * delta - 0.5 * tuning.jump_gravity * delta * delta
	vertical_velocity -= tuning.jump_gravity * delta
	if air_height <= 0.0 and vertical_velocity < 0.0:
		landed = true
		# Landing preserves forward speed and progress; the road is always beneath us.
		air_height = 0.0
		vertical_velocity = 0.0
		airborne = false


func try_takeoff(delta: float) -> void:
	if airborne or speed < tuning.minimum_jump_speed or track_distance <= previous_track_distance:
		return
	for jump: TrackJump in circuit.jumps:
		# Find the next lip in unwrapped race distance, including later laps.
		var lap := floorf((previous_track_distance - jump.takeoff_distance) / circuit.length) + 1.0
		var lip := jump.takeoff_distance + lap * circuit.length
		if track_distance < lip:
			continue
		took_off = true
		airborne = true
		air_height = 0.0
		vertical_velocity = minf(speed * jump.launch_strength, tuning.maximum_launch_speed)
		# Contacts have already limited progress. Only simulate the time after the
		# actual crossing, so long frames neither launch early nor extend airtime.
		var remaining := (track_distance - lip) / (track_distance - previous_track_distance)
		advance_flight(delta * remaining)
		return


func register_contact() -> void:
	if contact_cooldown <= 0.0:
		contact_hit = true
		contact_cooldown = 0.4


func lateral_limit() -> float:
	var box := collision_shape.shape as BoxShape3D
	return maxf(0.0, Circuit.WIDTH * 0.5 - box.size.x * 0.5 - 0.2)


func recover() -> void:
	clear_flight()
	track_distance = progress.distance
	lateral_offset = 0.0
	# Recovery teleports, so it must not sweep through every lane on the way back.
	previous_track_distance = track_distance
	previous_lateral_offset = lateral_offset
	lateral_velocity = 0.0
	speed *= 0.45
	boost_active = false
	engine_load = 0.0


func update_pose(delta: float) -> void:
	visual_time += delta
	transform = circuit.surface_frame(track_distance)
	var bob := 0.0 if airborne else sin(visual_time * 3.0) * 0.10
	position += basis.x * lateral_offset + basis.y * (tuning.hover_height + air_height + bob)
	var pitch := atan2(vertical_velocity, maxf(speed, 1.0)) if airborne else 0.0
	$Wireframe.rotation.x = lerp_angle($Wireframe.rotation.x, pitch, 1.0 - exp(-delta * 8.0))
	$Wireframe.rotation.z = lerp_angle($Wireframe.rotation.z, -lateral_velocity * 0.035, 1.0 - exp(-delta * 8.0))
	$Wireframe.rotation.y = -lateral_velocity * 0.012
