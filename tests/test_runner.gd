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
	print("Circuit length: %.1f m" % game.circuit.length)
	var start: Transform3D = game.circuit.frame(0)
	var end: Transform3D = game.circuit.frame(game.circuit.length - 0.01)
	check(start.origin.distance_to(end.origin) < 0.1, "Circuit position closes")
	check(start.basis.z.dot(end.basis.z) > 0.999, "Circuit tangent closes")
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
	# Exercise the actual controller, AI and finish/results transition at fixed 60 Hz.
	for i in range(60 * 600):
		game._physics_process(1.0 / 60.0)
		if i % 6000 == 0:
			print("TRACE time=", game.elapsed, " distance=", player.track_distance, " progress length=", player.progress.circuit_length, " laps=", player.progress.completed_laps, " speed=", player.speed, " boost=", player.boost_charge)
		if game.finish_order.size() == 3:
			break
	check(game.finish_order.size() == 3, "All three racers finish")
	check(game.state == game.State.RESULTS, "Player finish shows results")
	check(player.progress.completed_laps == 3, "Player completes exactly three laps")
	check(game.racers[1].progress.completed_laps == 3 and game.racers[2].progress.completed_laps == 3, "Both AI complete three laps")
	check(player.progress.finish_time > 300 and player.progress.finish_time < 360, "Race length is near requested 5–6 minutes")
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
	data.high_quality = false
	data.sensitivity = 1.35
	data.camera_shake = false
	data.best_race = 333.125
	data.best_lap = 109.5
	check(data.save_settings() == OK, "Settings saved")
	var loaded := SaveData.new()
	loaded.save_path = data.save_path
	loaded.load_settings()
	check(is_equal_approx(loaded.volume, 0.31) and is_equal_approx(loaded.sensitivity, 1.35), "Volume and sensitivity persist")
	check(not loaded.high_quality and not loaded.camera_shake, "Quality and shake persist")
	check(loaded.best_race == 333.125 and loaded.best_lap == 109.5, "Records persist")
