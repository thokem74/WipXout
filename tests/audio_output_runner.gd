extends SceneTree
## Real mixer regression check. Run with --audio-driver PulseAudio on Linux.
## Dummy playback flags cannot prove that racer audio reaches the output bus.

var failures: int = 0
var capture := AudioEffectCapture.new()


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)


func sample_output() -> Vector2:
	# Drain any samples queued before the current playback/volume change.
	await create_timer(0.1).timeout
	capture.clear_buffer()
	await create_timer(0.25).timeout
	var frames := capture.get_buffer(capture.get_frames_available())
	var power := 0.0
	var peak := 0.0
	for frame in frames:
		power += frame.length_squared()
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	return Vector2(sqrt(power / maxf(1.0, frames.size() * 2.0)), peak)


func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.audio.stop_all()
	var original_volume := AudioServer.get_bus_volume_db(0)
	AudioServer.set_bus_volume_db(0, linear_to_db(0.65))
	capture.buffer_length = 1.0
	var effect_index := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, capture)
	# Keep rivals out of range while measuring the player's direct mix.
	for index in range(1, game.racers.size()):
		game.racers[index].global_position = Vector3(10000 + index * 1000, 0, 0)
	var player: Racer = game.racers[0]
	player.speed = 0.0
	player.engine_load = 0.0
	game.audio.update_racers(game.racers, true, 1.0)
	var idle_output := await sample_output()
	check(idle_output.x > 0.01, "Idle engine produces audible mixer samples")
	player.speed = player.tuning.top_speed
	player.engine_load = 1.0
	game.audio.update_racers(game.racers, true, 1.0)
	var loaded_output := await sample_output()
	check(loaded_output.x > 0.02 and loaded_output.y < 0.95,
		"Loaded engine reaches output with headroom")
	game.audio.stop_all()
	var rival: AudioStreamPlayer3D = game.audio.get_node("RivalOneLoad")
	rival.global_position = game.camera.global_position + Vector3(0, 0, -8)
	rival.volume_db = -8.0
	rival.play()
	var rival_output := await sample_output()
	check(rival_output.x > 0.003, "Nearby positional rival reaches the mixer")
	game.audio.stop_all()
	# Stage overlapping racers, boost, and a cue at maximum user volume.
	AudioServer.set_bus_volume_db(0, 0.0)
	for racer: Racer in game.racers:
		racer.global_position = player.global_position
		racer.speed = racer.tuning.top_speed
		racer.engine_load = 1.0
	player.boost_active = true
	game.audio.update_racers(game.racers, true, 1.0)
	game.audio.cue("Finish")
	game.audio.cue("Takeoff")
	game.audio.cue("Landing")
	game.audio.cue("PositionGain")
	var combined_output := await sample_output()
	check(combined_output.y <= db_to_linear(-1.0) + 0.002,
		"Combined racers, boost and cue retain peak headroom")
	# Capture is pre-fader; the main test runner separately checks the volume UI.
	print("AUDIO_OUTPUT RMS idle=%.4f loaded=%.4f rival=%.4f peak=%.4f" % [
		idle_output.x, loaded_output.x, rival_output.x, combined_output.y])
	# Verify the shared engine bus responds to tunnel entry and exit smoothly.
	player.track_distance = 500.0
	game.audio.update_racers(game.racers, true, 0.05)
	check(game.audio.tunnel_wet > 0.0 and game.audio.tunnel_wet < 0.18,
		"Tunnel reverb fades in rather than switching abruptly")
	game.audio.update_racers(game.racers, true, 1.0)
	var tunnel_mix := await sample_output()
	check(tunnel_mix.y <= db_to_linear(-1.0) + 0.002, "Tunnel mix retains limiter headroom")
	player.track_distance = 2000.0
	game.audio.update_racers(game.racers, true, 1.0)
	check(game.audio.tunnel_wet < 0.001, "Tunnel reverb fades away in open air")
	game.audio.stop_all()
	await create_timer(0.1).timeout
	AudioServer.remove_bus_effect(0, effect_index)
	AudioServer.set_bus_volume_db(0, original_volume)
	game.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)
