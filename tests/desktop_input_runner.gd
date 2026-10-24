extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("run")


func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func check(condition: bool, text: String) -> void:
	if condition:
		print("PASS: ", text)
	else:
		push_error(text)
		failures += 1


func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	# Dummy audio backends do not consume looping playbacks; test driving independently.
	game.audio.enabled = false
	game.start_race()
	game.state = game.State.RACING
	game.ui.show_screen("")
	game._physics_process(0.016)
	key(KEY_W, true)
	for i in range(180):
		game._physics_process(1.0 / 60.0)
	check(game.racers[0].speed > 60, "Keyboard W accelerates through Input API")
	key(KEY_D, true)
	for i in range(30):
		game._physics_process(1.0 / 60.0)
	check(game.racers[0].lateral_offset > 1, "Simultaneous W+D drives and steers")
	key(KEY_D, false)
	key(KEY_SPACE, true)
	game._physics_process(0.1)
	check(game.racers[0].boost_active, "Space activates boost")
	game.pause_race()
	game._on_action("resume")
	game._physics_process(0.1)
	check(not game.racers[0].boost_active, "Held keys blocked after resume")
	key(KEY_W, false)
	key(KEY_SPACE, false)
	game._physics_process(0.016)
	var speed: float = game.racers[0].speed
	key(KEY_S, true)
	for i in range(60):
		game._physics_process(1.0 / 60.0)
	check(game.racers[0].speed < speed - 40, "Keyboard S brakes")
	key(KEY_S, false)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game._unhandled_key_input(escape)
	check(game.state == game.State.PAUSED, "Escape pauses")
	game._unhandled_key_input(escape)
	check(game.state == game.State.RACING, "Escape resumes")
	for player: AudioStreamPlayer in game.get_node("RaceAudio").get_children():
		player.stop()
	await create_timer(0.2).timeout
	game.queue_free()
	await process_frame
	await process_frame
	print("DESKTOP INPUT FAILURES: ", failures)
	call_deferred("quit", 1 if failures else 0)
