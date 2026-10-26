extends SceneTree

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func run() -> void:
	test_progress()
	test_touchpad()
	test_persistence()
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	# Dummy audio backends do not consume looping playbacks; test driving independently.
	game.audio.enabled = false
	test_audio(game)
	check(root.use_hdr_2d and root.msaa_3d == Viewport.MSAA_4X, "Fixed HDR and 4x MSAA are enabled")
	check(game.get_node("WorldEnvironment").environment.glow_enabled, "Bloom is always enabled")
	print("Circuit length: %.1f m" % game.circuit.length)
	var start: Transform3D = game.circuit.frame(0)
	var end: Transform3D = game.circuit.frame(game.circuit.length - 0.01)
	check(start.origin.distance_to(end.origin) < 0.1, "Circuit position closes")
	check(start.basis.z.dot(end.basis.z) > 0.999, "Circuit tangent closes")
	test_track_layout(game.circuit)
	test_tunnels(game.circuit)
	test_camera_clearance(game)
	game.start_race()
	game.state = game.State.RACING
	game.ui.show_screen("")
	var player: Racer = game.racers[0]
	player.speed = 80.0
	for i in range(300):
		player.simulate(1.0 / 60.0, Vector3(0, 1, 1), (i + 1) / 60.0)
	check(player.boost_charge < 0.03, "Boost drains")
	check(player.boost_locked, "Empty boost locks until replenished")
	for i in range(360):
		player.simulate(1.0 / 60.0, Vector3(0, 1, 0), 5 + (i + 1) / 60.0)
	check(player.boost_charge > 0.4, "Boost recharges after cooldown")
	player.speed = 80
	player.lateral_offset = 12
	player.lateral_velocity = 10
	player.simulate(1.0 / 60.0, Vector3(1, 1, 0), 11.1)
	check(player.speed < 70 and absf(player.lateral_offset) <= 11, "Wall slows and contains racer")
	check(player.lateral_velocity < 0, "Wall pushes inward")
	check(player.speed <= player.tuning.top_speed + 0.1, "Normal throttle respects maximum speed")
	var distance_before := player.progress.distance
	player.lateral_offset = 100
	player.simulate(1.0 / 60.0, Vector3.ZERO, 11.2)
	check(absf(player.lateral_offset) < 1, "Recovery centers racer")
	check(player.progress.distance - distance_before < 2, "Recovery does not skip progress")
	var previous_speed := player.speed
	player.simulate(0.1, Vector3(0, -1, 0), 11.3)
	check(player.speed < previous_speed, "Brake reduces speed")
	game.start_race()
	check(game.state == game.State.COUNTDOWN and not game.driving.enabled, "Play enters countdown without calibration")
	game._physics_process(4.0)
	game._physics_process(0.016)
	var pad_rect: Rect2 = game.ui.get_pad_rect()
	var pad_top := pad_rect.get_center() - Vector2(0, pad_rect.size.y * 0.49)
	touch(game.driving, 0, pad_top, true)
	for i in range(60):
		game._physics_process(1.0 / 60.0)
	check(player.speed > 20, "HUD pad accelerates actual racer")
	drag(game.driving, 0, pad_top + Vector2(110, 0))
	for i in range(30):
		game._physics_process(1.0 / 60.0)
	check(player.lateral_offset > 1, "HUD diagonal accelerates and steers actual racer")
	check(game.ui.get_node("SafeArea/HUD/DrivingPad").finger_active, "Pad indicator follows capture")
	touch(game.driving, 4, game.ui.get_boost_rect().get_center(), true)
	game._physics_process(0.016)
	check(player.boost_active, "Independent HUD Boost finger activates actual boost")
	game.pause_race()
	var paused_distance: float = game.racers[0].track_distance
	game._physics_process(1.0)
	check(game.racers[0].track_distance == paused_distance, "Pause stops simulation")
	check(game.driving.boost_touches.is_empty(), "Pause clears touch boost")
	check(game.driving.pad_pointer == DrivingInput.NO_POINTER, "Pause clears driving finger")
	game._on_action("resume")
	check(game.state == game.State.RACING, "Resume restores race directly")
	drag(game.driving, 0, pad_top)
	check(game.driving.read_controls(0.016) == Vector3.ZERO, "Held HUD finger cannot resume driving")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.state == game.State.PAUSED, "Focus loss pauses")
	game._on_action("restart")
	check(game.state == game.State.COUNTDOWN and game.elapsed == 0, "Restart returns to countdown")
	game._physics_process(4.0)
	check(game.state == game.State.RACING, "Countdown starts racing")
	game.start_race()
	game.state = game.State.RACING
	game.demo_mode = true
	var jump_counts := [0, 0, 0]
	var previously_airborne := [false, false, false]
	# Exercise the actual controller, AI and finish/results transition at fixed 60 Hz.
	for i in range(60 * 600):
		game._physics_process(1.0 / 60.0)
		for index in range(3):
			if game.racers[index].airborne and not previously_airborne[index]:
				jump_counts[index] += 1
			previously_airborne[index] = game.racers[index].airborne
		if i % 6000 == 0:
			print("TRACE time=", game.elapsed, " distance=", player.track_distance, " progress length=", player.progress.circuit_length, " laps=", player.progress.completed_laps, " speed=", player.speed, " boost=", player.boost_charge)
		if game.finish_order.size() == 3:
			break
	check(jump_counts == [6, 6, 6], "All racers take both jumps on every lap")
	check(game.finish_order.size() == 3, "All three racers finish")
	check(game.state == game.State.RESULTS, "Player finish shows results")
	check(player.progress.completed_laps == 3, "Player completes exactly three laps")
	check(game.racers[1].progress.completed_laps == 3 and game.racers[2].progress.completed_laps == 3, "Both AI complete three laps")
	check(player.progress.finish_time > 300 and player.progress.finish_time < 480,
		"Revised race duration stays between five and eight minutes")
	check(player.finished_rank >= 1 and player.finished_rank <= 3, "Finish rank assigned")
	check(is_finite(player.progress.best_lap), "Best lap recorded")
	print("Finish times: player=%.3f, ION=%.3f, EMBER=%.3f" % [player.progress.finish_time, game.racers[1].progress.finish_time, game.racers[2].progress.finish_time])
	var ranks := [game.racers[0].finished_rank, game.racers[1].finished_rank, game.racers[2].finished_rank]
	ranks.sort()
	check(ranks == [1, 2, 3], "Finishing order contains unique ranks")
	game._on_action("restart")
	check(game.finish_order.is_empty() and player.progress.completed_laps == 0 and player.boost_charge == 1, "Completed race restarts cleanly")
	game.apply_settings()
	game.free()
	print("CHECKS: %d  FAILURES: %d" % [checks, failures])
	call_deferred("quit", 1 if failures else 0)


func test_audio(game: Node) -> void:
	var audio: Node = game.audio
	audio.enabled = true
	var engine: AudioStreamPlayer = audio.get_node("EngineIdle")
	var loaded: AudioStreamPlayer = audio.get_node("EngineLoad")
	var rival: AudioStreamPlayer3D = audio.get_node("RivalOneIdle")
	var turbine: AudioStreamPlayer3D = audio.get_node("RivalTwoIdle")
	var boost: AudioStreamPlayer = audio.get_node("Boost")
	for name: String in ["EngineIdle", "EngineLoad", "RivalOneIdle", "RivalOneLoad",
			"RivalTwoIdle", "RivalTwoLoad", "Boost"]:
		var stream := audio.get_node(name).stream as AudioStreamWAV
		check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD
			and stream.loop_end == stream.mix_rate * 2, "Full seamless loop: " + name)
	var rival_loaded: AudioStreamPlayer3D = audio.get_node("RivalOneLoad")
	check(engine.stream.data == rival.stream.data and loaded.stream.data == rival_loaded.stream.data
		and rival.stream.data != turbine.stream.data,
		"Player shares ION's idle/loaded profile while EMBER keeps its turbine sound")
	audio.countdown_tick(3)
	var first_pitch: float = audio.get_node("Countdown").pitch_scale
	audio.countdown_tick(1)
	check(audio.get_node("Countdown").pitch_scale > first_pitch, "Countdown urgency rises toward GO")
	check(audio.get_node("Go").stream != audio.get_node("Finish").stream,
		"Launch and finish have distinct racing signals")
	var player: Racer = game.racers[0]
	player.reset()
	player.simulate(1.0 / 60.0, Vector3(0, 0.5, 0), 0.0)
	check(is_equal_approx(player.engine_load, 0.5), "Engine load follows proportional throttle")
	player.simulate(1.0 / 60.0, Vector3(0, 0, 1), 0.0)
	check(player.engine_load == 1.0, "Boost demands full engine load")
	player.simulate(1.0 / 60.0, Vector3(0, -1, 0), 0.0)
	check(player.engine_load == 0.0, "Braking releases engine load")
	player.reset()
	check(player.engine_load == 0.0, "Restart clears engine load")
	game.start_race()
	game._physics_process(0.016)
	check(engine.playing and rival.playing, "Countdown includes gentle idle engines")
	var idle_pitch := engine.pitch_scale
	player.speed = player.tuning.top_speed
	player.engine_load = 1.0
	player.boost_active = true
	for i in range(30):
		audio.update_racers(game.racers, true, 1.0 / 60.0)
	check(engine.pitch_scale > idle_pitch, "Mechanical engine RPM rises with speed and load")
	check(loaded.volume_db > engine.volume_db, "Acceleration crossfades into the loaded recording")
	check(boost.playing and boost.volume_db > -30.0, "Boost roar fades in")
	check(rival.global_position.is_equal_approx(game.racers[1].global_position),
		"Rival audio follows its ship in 3D")
	player.engine_load = 0.0
	player.boost_active = false
	for i in range(60):
		audio.update_racers(game.racers, true, 1.0 / 60.0)
	check(engine.volume_db > loaded.volume_db, "Coasting crossfades back to idle texture")
	check(not boost.playing, "Boost roar fades out after release")
	# Stage a straight pass so distance and radial speed have unambiguous signs.
	var other: Racer = game.racers[1]
	player.transform = Transform3D.IDENTITY
	player.speed = 0.0
	other.transform = Transform3D(Basis.IDENTITY, Vector3(0, 0, 20))
	other.speed = other.tuning.top_speed
	var approaching: float = audio.passby_pitch(other, player)
	other.position.z = -20.0
	var receding: float = audio.passby_pitch(other, player)
	check(approaching > 1.0 and receding < 1.0, "Passing rivals change from higher to lower pitch")
	other.position.z = 100000.0
	check(audio.passby_pitch(other, player) <= 1.25 and receding >= 0.8,
		"Pass-by pitch remains bounded after teleports")
	game.state = game.State.RACING
	game.pause_race()
	check(not engine.playing and not loaded.playing and not rival.playing
		and not audio.get_node("Countdown").playing, "Pause stops all layers and cues")
	game.start_race()
	check(not engine.playing and not boost.playing, "Restart clears previous audio playback")
	var original_volume: float = game.data.volume
	game.data.volume = 0.0
	game.apply_settings()
	check(AudioServer.get_bus_volume_db(0) < -70.0, "Volume setting can silence the new mix")
	game.data.volume = original_volume
	game.apply_settings()
	player.progress.finish_time = 1.0
	player.engine_load = 1.0
	player.simulate(1.0 / 60.0, Vector3(0, 1, 0), 1.0)
	check(player.engine_load == 0.0, "Finished racers release engine load")
	game._on_action("main")
	audio.enabled = false


func test_track_layout(circuit: Circuit) -> void:
	var samples := ceili(circuit.length / 5.0)
	var step := circuit.length / samples
	var minimum_height := INF
	var maximum_height := -INF
	var maximum_grade := 0.0
	var frames_valid := true
	var straight_length := 0.0
	var longest_straight := 0.0
	var short_straights := 0
	var longest_slope := 0.0
	var slope_length := 0.0
	var sustained_slopes := 0
	var maximum_bend := 0.0
	var previous_turn := 0.0
	var turn_reversals := 0
	var previous_slope := 0.0
	var crests := 0
	var dips := 0
	var positions: Array[Vector3] = []
	# A second pass includes straight sections and hills crossing the lap seam.
	for i in range(samples * 2):
		var distance := i * step
		var pose := circuit.frame(distance)
		frames_valid = frames_valid and pose.origin.is_finite() and pose.basis.is_finite()
		frames_valid = frames_valid and pose.basis.is_equal_approx(pose.basis.orthonormalized())
		var forward := -pose.basis.z
		var grade := forward.y / Vector2(forward.x, forward.z).length()
		maximum_grade = maxf(maximum_grade, absf(grade))
		minimum_height = minf(minimum_height, pose.origin.y)
		maximum_height = maxf(maximum_height, pose.origin.y)
		if i < samples:
			positions.append(pose.origin)
			if absf(grade) > 0.01:
				slope_length += step
				longest_slope = maxf(longest_slope, slope_length)
			else:
				if slope_length >= 990.0:
					sustained_slopes += 1
				slope_length = 0.0
			if absf(grade) > 0.01:
				if previous_slope > 0.0 and grade < 0.0:
					crests += 1
				elif previous_slope < 0.0 and grade > 0.0:
					dips += 1
				previous_slope = grade
		var bend := circuit.curvature(distance)
		maximum_bend = maxf(maximum_bend, absf(bend))
		if absf(bend) < 0.0006:
			straight_length += step
			longest_straight = maxf(longest_straight, straight_length)
		else:
			if i < samples and straight_length >= 100.0 and straight_length <= 180.0:
				short_straights += 1
			straight_length = 0.0
			if i < samples and previous_turn * bend < 0.0:
				turn_reversals += 1
			previous_turn = bend
	check(frames_valid, "Track frames remain finite and orthonormal over hills")
	check(longest_straight <= 180.0, "Straight sections stay within 180 metres, including the seam")
	check(short_straights >= 1, "Starting grid retains a short 100–180 metre straight")
	check(circuit.length >= 8451.0 and circuit.length <= 10329.0,
		"Circuit stays within ten percent of original length")
	if slope_length >= 990.0:
		sustained_slopes += 1
	check(sustained_slopes >= 8 and longest_slope <= 1120.0,
		"Four sustained climbs and descents around 1,000–1,100 metres")
	check(maximum_bend >= 1.0 / 110.0 and maximum_bend <= 1.0 / 75.0,
		"Hardest corners have approximately 75–110 metre radii")
	check(turn_reversals >= 6, "Track includes at least three alternating S-bend sequences")
	check(maximum_height - minimum_height >= 125.0 and maximum_height - minimum_height <= 135.0,
		"Track elevation range is approximately 130 metres")
	check(crests >= 4 and dips >= 3, "Track has four distinct climbs and descents")
	check(maximum_grade <= 0.20, "Track grades remain within twenty percent")
	# Non-neighbouring road samples must leave room for the full track width.
	var clearance_valid := true
	var neighbour_samples := ceili(100.0 / step)
	for i in range(samples):
		for j in range(i + neighbour_samples, samples):
			if samples - j + i < neighbour_samples:
				continue
			if positions[i].distance_to(positions[j]) < Circuit.WIDTH + 2.0:
				clearance_valid = false
	check(clearance_valid, "Separate track sections do not overlap")
	var road_center := circuit.frame(circuit.length / 2.0).origin
	road_center.y = -50.0
	check(not circuit.has_scenery_clearance(road_center, 40.0),
		"Scenery clearance rejects buildings below elevated road sections")
	check(circuit.has_scenery_clearance(Vector3(10000, -50, 10000), 40.0),
		"Scenery clearance allows buildings away from the road")
	# Changing pitch on an otherwise straight path must not steer the ship.
	var climb := Circuit.new()
	var path := Path3D.new()
	path.curve = Curve3D.new()
	path.curve.add_point(Vector3.ZERO, Vector3.ZERO, Vector3(0, 0, -50))
	path.curve.add_point(Vector3(0, 40, -150), Vector3(0, -30, 50), Vector3(0, 30, -50))
	path.curve.add_point(Vector3(0, 100, -300), Vector3(0, 0, 50))
	climb.add_child(path)
	climb.route = path
	climb.length = path.curve.get_baked_length()
	check(absf(climb.curvature(70.0)) < 0.000001, "Pitch changes do not create steering curvature")
	climb.free()
	print("Track profile: %.1f m, %.1f m elevation, %.1f%% maximum grade, %.1f m longest straight" % [
		circuit.length, maximum_height - minimum_height, maximum_grade * 100.0, longest_straight])


func test_tunnels(circuit: Circuit) -> void:
	var tunnels := circuit.get_node("Tunnels").get_children()
	check(tunnels.size() == 3, "Three authored tunnel sections")
	for tunnel: TrackTunnel in tunnels:
		check(tunnel.tunnel_length >= 600.0 and tunnel.tunnel_length <= 800.0,
			"Tunnel length is between 600 and 800 metres")
		check(tunnel.start_distance > 0.0 and tunnel.start_distance + tunnel.tunnel_length < circuit.length,
			"Tunnels leave the grid and lap seam open")
		var shell: Mesh = tunnel.get_node("Shell").mesh
		check(shell != null and shell.get_surface_count() == 1, "Tunnel has an opaque continuous shell")
		for node_name: String in ["Ribs", "Guides"]:
			check(tunnel.get_node(node_name).mesh.get_surface_count() == 1, "Tunnel neon outlines exist")
	var climb: TrackTunnel = tunnels[0]
	check(-circuit.frame(climb.start_distance + climb.tunnel_length / 2.0).basis.z.y > 0.1,
		"Hill tunnel follows a sustained climb")
	var bend: TrackTunnel = tunnels[1]
	check(absf(circuit.curvature(bend.start_distance + bend.tunnel_length / 2.0)) > 0.003,
		"Bend tunnel follows a sweeping corner")
	var sprint: TrackTunnel = tunnels[2]
	var fast_samples := 0
	var sample_count := 0
	for distance in range(ceili(sprint.start_distance),
			floori(sprint.start_distance + sprint.tunnel_length), 5):
		sample_count += 1
		if absf(circuit.curvature(distance)) < 0.006:
			fast_samples += 1
	check(float(fast_samples) / sample_count > 0.65, "Fast tunnel mostly follows gentler bends")



func test_camera_clearance(game: Node) -> void:
	var player: Racer = game.racers[0]
	var minimum_clearance := INF
	var tunnel_clearance := true
	for lane: float in [-10.0, 0.0, 10.0]:
		player.lateral_offset = lane
		for speed: float in [player.tuning.top_speed, player.tuning.boost_speed]:
			game.camera.snap_next = true
			player.boost_active = speed == player.tuning.boost_speed
			var steps := ceili((game.circuit.length + 100.0) / (speed / 60.0))
			for i in range(steps):
				player.track_distance = i * speed / 60.0
				player.speed = speed
				player.update_pose(1.0 / 60.0)
				game.camera._process(1.0 / 60.0)
				var offset: float = game.circuit.route.curve.get_closest_offset(game.camera.global_position)
				var road: Transform3D = game.circuit.frame(offset)
				var local_camera: Vector3 = road.affine_inverse() * game.camera.global_position
				minimum_clearance = minf(minimum_clearance, local_camera.y)
				for tunnel: TrackTunnel in game.circuit.get_node("Tunnels").get_children():
					if offset < tunnel.start_distance or offset > tunnel.start_distance + tunnel.tunnel_length:
						continue
					# Leave a metre of clearance, including under the chamfered shoulders.
					var ceiling := TrackTunnel.HEIGHT - maxf(0.0, absf(local_camera.x) - 12.0) * 0.8
					tunnel_clearance = tunnel_clearance and absf(local_camera.x) < TrackTunnel.HALF_WIDTH - 1.0
					tunnel_clearance = tunnel_clearance and local_camera.y < ceiling - 1.0
	player.lateral_offset = 0.0
	player.boost_active = false
	check(minimum_clearance > 1.0,
		"Chase camera clears road throughout normal and boosted laps in all lanes")
	check(tunnel_clearance,
		"Chase camera clears tunnel walls, shoulders, ceilings, and portals in all lanes")
	print("Minimum camera clearance: %.2f m" % minimum_clearance)


func test_progress() -> void:
	var progress := RaceProgress.new(1600)
	check(not progress.advance(-1, 0.1, 0.1), "Reverse finish rejected")
	check(not progress.advance(1599, 0.1, 0.1), "Checkpoint skip rejected")
	check(progress.completed_laps == 0, "No lap awarded for skip")
	for step in range(1, 481):
		check(progress.advance(step * 10.0, 0.1, step * 0.1), "Legitimate progress accepted")
	check(progress.completed_laps == 3 and is_equal_approx(progress.finish_time, 48.0), "Valid checkpoint sequence finishes")
	check(not progress.advance(4810, 0.1, 48.1), "Finish time locked")
	progress.reset()
	check(progress.completed_laps == 0 and progress.next_checkpoint == 1, "Progress reset")
	progress.distance = 200.0
	check(not progress.advance(201.0, 0.1, 1.0), "Out-of-order checkpoint state rejected")


func touch(input: DrivingInput, index: int, position: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	event.canceled = canceled
	input._input(event)


func drag(input: DrivingInput, index: int, position: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	input._input(event)


func test_touchpad() -> void:
	var input := DrivingInput.new()
	input.set_regions(Rect2(100, 100, 240, 240), Rect2(0, 400, 100, 100))
	touch(input, 0, Vector2(220, 120), true)
	check(input.read_controls(0.016) == Vector3.ZERO, "Hidden controls ignore touches")
	input.enabled = true
	touch(input, 0, Vector2(220, 220), true)
	check(input.read_controls(0.016) == Vector3.ZERO, "Pad center is neutral")
	drag(input, 0, Vector2(230, 210))
	check(input.read_controls(0.016) == Vector3.ZERO, "Each axis has a center dead zone")
	var positions: Array[Vector2] = [Vector2(100, 220), Vector2(340, 220),
		Vector2(220, 100), Vector2(220, 340), Vector2(100, 100),
		Vector2(340, 100), Vector2(100, 340), Vector2(340, 340)]
	var expected: Array[Vector3] = [Vector3(-1, 0, 0), Vector3(1, 0, 0),
		Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(-1, 1, 0),
		Vector3(1, 1, 0), Vector3(-1, -1, 0), Vector3(1, -1, 0)]
	for i in range(positions.size()):
		drag(input, 0, positions[i])
		check(input.read_controls(0.016).is_equal_approx(expected[i]), "Pad edge/diagonal %d" % i)
	drag(input, 0, Vector2(286, 154))
	check(input.read_controls(0.016).is_equal_approx(Vector3(0.5, 0.5, 0)), "Whole pad provides proportional independent axes")
	drag(input, 0, Vector2(900, -100))
	check(input.read_controls(0.016) == Vector3(1, 1, 0), "Captured drag clamps outside pad")
	touch(input, 1, Vector2(120, 320), true)
	drag(input, 1, Vector2(100, 340))
	check(input.read_controls(0.016) == Vector3(1, 1, 0), "Extra driving finger cannot steal pad")
	touch(input, 1, Vector2.ZERO, false)
	check(input.pad_pointer == 0, "Extra finger release preserves owner")
	touch(input, 2, Vector2(50, 450), true)
	check(input.read_controls(0.016) == Vector3(1, 1, 1), "Driving and second-finger Boost combine")
	touch(input, 0, Vector2.ZERO, false)
	check(input.read_controls(0.016) == Vector3(0, 0, 1), "Driving release preserves Boost")
	touch(input, 0, Vector2(110, 110), true)
	touch(input, 2, Vector2.ZERO, false)
	check(input.read_controls(0.016).z == 0 and input.read_controls(0.016).y > 0.9, "Boost release preserves driving")
	touch(input, 0, Vector2.ZERO, true, true)
	check(input.read_controls(0.016) == Vector3.ZERO, "Canceled driving touch releases both axes")
	touch(input, 2, Vector2(50, 450), true)
	touch(input, 2, Vector2.ZERO, true, true)
	check(input.read_controls(0.016) == Vector3.ZERO, "Canceled Boost releases button")
	touch(input, 2, Vector2(50, 450), true)
	drag(input, 2, Vector2(120, 450))
	check(input.read_controls(0.016).z == 0, "Dragging off Boost releases it")
	touch(input, 0, Vector2(110, 110), true)
	input.clear()
	drag(input, 0, Vector2(339, 100))
	check(input.read_controls(0.016) == Vector3.ZERO, "Reset requires a fresh touch press")
	touch(input, 0, Vector2(110, 110), true)
	input.enabled = false
	input.enabled = true
	drag(input, 0, Vector2(339, 100))
	check(input.read_controls(0.016) == Vector3.ZERO, "Resume never recaptures a held finger")
	touch(input, 0, Vector2(110, 110), true)
	input.set_regions(Rect2(110, 100, 240, 240), input.boost_rect)
	check(input.read_controls(0.016) == Vector3.ZERO, "Resize safely releases captures")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = Vector2(349, 101)
	mouse.pressed = true
	input._input(mouse)
	check(input.read_controls(0.016).x > 0.9 and input.read_controls(0.016).y > 0.9, "Mouse drives the pad")
	mouse.pressed = false
	input._input(mouse)
	check(input.read_controls(0.016) == Vector3.ZERO, "Mouse release centers the pad")
	input.free()


func test_persistence() -> void:
	var data := SaveData.new()
	data.save_path = "user://test_settings.cfg"
	data.volume = 0.31
	data.sensitivity = 1.35
	data.camera_shake = false
	data.best_race = 333.125
	data.best_lap = 109.5
	check(data.save_settings() == OK, "Settings saved")
	# Existing installs may still contain the removed Low-quality preference.
	var legacy_config := ConfigFile.new()
	legacy_config.load(data.save_path)
	legacy_config.set_value("settings", "high_quality", false)
	legacy_config.save(data.save_path)
	var loaded := SaveData.new()
	loaded.save_path = data.save_path
	loaded.load_settings()
	check(is_equal_approx(loaded.volume, 0.31) and is_equal_approx(loaded.sensitivity, 1.35), "Volume and sensitivity persist")
	check(not loaded.camera_shake, "Camera shake persists")
	check(loaded.best_race == 333.125 and loaded.best_lap == 109.5, "Records persist")
	loaded.save_settings()
	legacy_config.clear()
	legacy_config.load(data.save_path)
	check(not legacy_config.has_section_key("settings", "high_quality"),
		"Saving settings removes the obsolete quality preference")
