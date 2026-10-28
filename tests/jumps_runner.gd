extends SceneTree
## Flight tests use real racer movement, track ramps, and contact-adjusted progress.

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func stage(racer: Racer, distance: float) -> void:
	racer.reset(distance)
	racer.progress.completed_laps = floori(distance / racer.circuit.length)
	racer.progress.next_checkpoint = (
			floori(
					(
							fposmod(distance, racer.circuit.length)
							/ racer.circuit.length
							* racer.progress.checkpoint_count
					)
			)
			+ 1
	)


func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.audio.enabled = false
	var player: Racer = game.racers[0]
	check(game.circuit.jumps.size() == 4, "Exactly four authored jumps")
	for jump: TrackJump in game.circuit.jumps:
		var clear_landing := true
		for distance in range(int(jump.takeoff_distance), int(jump.takeoff_distance + 520), 5):
			clear_landing = clear_landing and absf(game.circuit.curvature(distance)) < 0.007
		for offset in range(-int(jump.approach_length), 521, 5):
			clear_landing = clear_landing and not game.circuit.is_in_tunnel(jump.takeoff_distance + offset)
		check(clear_landing, "Jump has an open landing corridor before tight corners and tunnels")
		check(
				jump.get_node("Markings").mesh.get_surface_count() == 1,
				"Ramp has visible takeoff markings"
		)
		for lap in range(3):
			for speed: float in [10.0, player.tuning.top_speed, player.tuning.boost_speed]:
				var lip: float = jump.takeoff_distance + lap * game.circuit.length
				player.reset(lip - 1.0)
				player.progress.completed_laps = lap
				player.progress.next_checkpoint = (
						floori(jump.takeoff_distance / game.circuit.length * 16) + 1
				)
				player.speed = speed
				var controls := Vector3(0, 1, 1 if speed > 100 else 0)
				player.simulate(0.12, controls, 0.12)
				if speed < 25:
					check(not player.airborne, "Slow ships roll over ramps without falling")
					continue
				check(
						player.airborne and player.air_height > 0.0,
						"Normal and boost crossings launch on every lap"
				)
				var peak := player.air_height
				var duration := 0.12
				while player.airborne and duration < 4.5:
					# Hold a stable line using the same correction as the game demo.
					controls.x = clampf(
							-player.lateral_offset * 0.2 - player.lateral_velocity * 0.12, -1, 1
					)
					player.simulate(1.0 / 60.0, controls, duration)
					peak = maxf(peak, player.air_height)
					duration += 1.0 / 60.0
				check(
						not player.airborne and is_zero_approx(player.air_height),
						"Flight returns smoothly to road hover height"
				)
				check(
						peak >= 20.0 and peak <= 29.0 and duration >= 3.0 and duration <= 3.7,
						"Heavy jumps reach 20–29 metres and 3–3.6 seconds of airtime"
				)
				check(
						not player.wall_hit and player.speed >= speed - 1.0,
						"A controlled landing preserves speed"
				)
				check(
						player.progress.distance == player.track_distance,
						"Flight does not manufacture or skip checkpoint progress"
				)
	var jump: TrackJump = game.circuit.jumps[0]
	for delta: float in [1.0 / 60.0, 0.2, 0.5]:
		stage(player, jump.takeoff_distance - 0.5)
		player.speed = player.tuning.top_speed
		player.simulate(delta, Vector3(0, 1, 0), delta)
		check(
				player.airborne and player.air_height > 0.0, "Swept takeoff handles delta %.3f" % delta
		)
		var takeoff_height := player.air_height
		player.simulate(0.1, Vector3(0, -1, 0), delta + 0.1)
		check(
				player.speed < player.tuning.top_speed and player.air_height > takeoff_height,
				"Midair braking works without resetting the height arc"
		)
	# A blocked crossing must not launch, even if the proposed movement passed the lip.
	var front: Racer = game.racers[1]
	stage(player, jump.takeoff_distance - 10.0)
	stage(front, jump.takeoff_distance + 1.0)
	player.speed = 140.0
	player.prepare_step(0.2, Vector3(0, 1, 1))
	front.prepare_step(0.2, Vector3.ZERO)
	RacerContacts.resolve([player, front])
	player.finish_step(0.2, 0.2)
	check(
			player.track_distance < jump.takeoff_distance and not player.airborne,
			"Contact-blocked takeoff cannot launch early"
	)
	# Pausing leaves flight completely unchanged; resuming advances it normally.
	game.start_race()
	game.state = game.State.RACING
	stage(player, jump.takeoff_distance - 1.0)
	player.speed = player.tuning.top_speed
	player.simulate(0.1, Vector3(0, 1, 0), 0.1)
	game.pause_race()
	var paused_height := player.air_height
	var paused_velocity := player.vertical_velocity
	game._physics_process(1.0)
	check(
			player.air_height == paused_height and player.vertical_velocity == paused_velocity,
			"Pause freezes the jump arc"
	)
	game._on_action("resume")
	game._physics_process(1.0 / 60.0)
	check(player.air_height != paused_height, "Resume continues flight")
	player.recover()
	check(not player.airborne and player.air_height == 0.0, "Recovery clears airborne state")
	player.airborne = true
	player.air_height = 4.0
	game.start_race()
	check(not player.airborne and player.air_height == 0.0, "Restart clears airborne state")
	# Flight steering has the configured fraction of grounded acceleration at equal speed/curvature.
	player.reset(400.0)
	front.reset(400.0)
	player.airborne = true
	player.air_height = 5.0
	player.prepare_step(0.01, Vector3(1, 0, 0))
	front.prepare_step(0.01, Vector3(1, 0, 0))
	check(
			is_equal_approx(player.lateral_velocity / player.tuning.air_steering_factor, front.lateral_velocity),
			"Air steering acceleration is uses the configured reduced acceleration"
	)
	# Finished ships must not retain a floating pose.
	player.progress.finish_time = 1.0
	player.finish_step(0.01, 1.0)
	check(not player.airborne and player.air_height == 0.0, "Finish clears flight state")
	# Exercise the actual following camera through both arcs, including outer lanes.
	var camera_clear := true
	for section: TrackJump in game.circuit.jumps:
		for lane: float in [-10.0, 0.0, 10.0]:
			for speed: float in [player.tuning.top_speed, player.tuning.boost_speed]:
				stage(player, section.takeoff_distance - 50.0)
				player.lateral_offset = lane
				player.speed = speed
				game.camera.snap_next = true
				for i in range(330):
					var controls := Vector3(
							clampf(
									(lane - player.lateral_offset) * 0.3 - player.lateral_velocity * 0.15,
									-1,
									1
							),
							1,
							1 if speed > 100 else 0
					)
					player.simulate(1.0 / 60.0, controls, (i + 1) / 60.0)
					game.camera._process(1.0 / 60.0)
					var offset: float = game.circuit.route.curve.get_closest_offset(
							game.camera.position
					)
					var local: Vector3 = (
							game.circuit.surface_frame(offset).affine_inverse() * game.camera.position
					)
					camera_clear = (
							camera_clear and local.y > 1.0 and game.camera.transform.is_finite()
					)
	check(
			camera_clear,
			"Camera clears all ramps and airborne arcs in all lanes at normal and boost speed"
	)
	game.queue_free()
	await process_frame
	print("JUMP CHECKS: %d FAILURES: %d" % [checks, failures])
	quit(1 if failures else 0)
