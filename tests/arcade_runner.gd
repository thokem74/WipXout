extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.audio.enabled = false
	check(game.racers.size() == 6 and game.pilot_profiles.size() == 6, "Six scene-authored pilots")
	var names := {}
	var colors := {}
	for racer: Racer in game.racers:
		names[racer.racer_name] = true
		colors[racer.neon_color] = true
		check(racer.profile != null, "Every racer has a pilot profile")
		check(
				racer.effects.get_node("Flames/Left").material_override.emission == racer.neon_color,
				"Exhaust uses its pilot color without sharing another pilot's material"
		)
	check(names.size() == 6 and colors.size() == 6, "Six unique names and colors")
	var grid_clear := true
	for i in range(6):
		for j in range(i + 1, 6):
			grid_clear = (
					grid_clear
					and (
							absf(game.racers[i].track_distance - game.racers[j].track_distance) >= 6.8
							or absf(game.racers[i].lateral_offset - game.racers[j].lateral_offset) >= 8.4
					)
			)
	check(
			grid_clear and game.racers[0].track_distance == 0,
			"Three rows of two leave clear starting hulls"
	)
	var map = game.ui.get_node("SafeArea/HUD/Minimap")
	check(
			map.size == Vector2(240, 210) and map.position.y == 112,
			"Map sits directly below lap display"
	)
	check(map.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Map cannot capture driving touches")
	check(
			map.outline.size() == 257 and map.outline[0].is_equal_approx(map.outline[-1]),
			"Cached map outline closes"
	)
	game.start_race()
	game.ui.update_minimap(RaceStandings.ordered(game.racers))
	var badges_clear := true
	for i in range(6):
		check(Rect2(Vector2.ZERO, map.size).has_point(map.badges[i]), "Rank badge stays inside map")
		for j in range(i + 1, 6):
			badges_clear = badges_clear and map.badges[i].distance_to(map.badges[j]) >= 22.0
	check(badges_clear, "All six clustered grid numbers remain readable")
	var markers_match := true
	var grid_order := RaceStandings.ordered(game.racers)
	for index in range(6):
		markers_match = markers_match and map.colors[index] == grid_order[index].neon_color
		markers_match = (
				markers_match and map.get_node("Rank%d" % (index + 1)).text == str(index + 1)
		)
	check(markers_match, "Each numbered map marker uses its ranked pilot's color")

	for racer: Racer in game.racers:
		racer.progress.distance = 100.0
	var order := RaceStandings.ordered(game.racers)
	check(order == game.racers, "Exact progress ties use stable roster order")
	game.racers[5].progress.distance = game.circuit.length + 100.0
	order = RaceStandings.ordered(game.racers)
	check(order[0] == game.racers[5], "Lapped standings use unwrapped earned progress")
	game.ui.update_minimap(order)
	check(
			map.dots[0].distance_to(map.dots[1]) < 0.01,
			"Lapped racers share the same wrapped map location"
	)
	game.racers[5].track_distance = 8000.0
	game.ui.update_minimap(order)
	check(map.dots[0].distance_to(map.dots[1]) < 0.01, "Map ignores unvalidated proposed movement")
	game.racers[3].finished_rank = 1
	game.racers[4].finished_rank = 2
	order = RaceStandings.ordered(game.racers)
	check(
			order[0] == game.racers[3] and order[1] == game.racers[4],
			"Finish ranks stay ahead of active progress"
	)
	game.ui.update_minimap(order)
	check(map.dots[0].distance_to(map.outline[0]) < 0.01, "Finished markers stay at finish line")
	game.start_race()
	game.state = game.State.RACING
	var player: Racer = game.racers[0]
	player.speed = 88
	player.simulate(0.1, Vector3(0, 1, 1), 0.1)
	check(
			player.effects.visible and player.effects.get_node("Trail").emitting,
			"Boost drives reused exhaust and trails"
	)
	player.took_off = true
	player.effects.update_racer(player, 0.01)
	check(player.effects.get_node("LiftBurst").emitting, "Takeoff uses its own downward burst")
	player.took_off = false
	player.landed = true
	player.effects.update_racer(player, 0.01)
	check(player.effects.get_node("LandingBurst").emitting, "Landing uses its own heavy impact burst")
	player.landed = false
	game.ui.update_effects(player, 0.1, true)
	var feedback: ShaderMaterial = game.ui.get_node("SafeArea/HUD/SpeedEffects").material
	check(feedback.get_shader_parameter("boost_amount") == 1.0, "Boost drives edge streaks")
	game.ui.flash_impact()
	game.ui.update_effects(player, 0.01, true)
	check(
			feedback.get_shader_parameter("impact_amount") > 0.0, "Impact flashes are brief HUD effects"
	)
	game.camera.shake_enabled = false
	game.camera.clear_impulse()
	game.camera.add_impulse(0.24)
	check(game.camera.impulse == 0, "Camera shake setting disables impulses")
	game.camera.shake_enabled = true
	game.camera.add_impulse(0.24)
	game.camera._process(0.05)
	check(game.camera.impulse > 0 and game.camera.impulse < 0.24, "Camera impulses decay")
	game.camera.add_impulse(10.0)
	check(game.camera.impulse == player.tuning.maximum_camera_impulse, "Camera impulse is capped")
	game.pause_race()
	check(
			not player.effects.visible and feedback.get_shader_parameter("boost_amount") == 0.0,
			"Pause clears particle and HUD effects"
	)
	check(not player.effects.get_node("LiftBurst").emitting
			and not player.effects.get_node("LandingBurst").emitting,
			"Pause stops all pooled jump emitters")
	check(not map.is_visible_in_tree(), "Minimap hides with the paused HUD")
	game._on_action("resume")
	game._physics_process(0.02)
	check(player.effects.visible, "Resume restores active ship effects")
	game._on_action("main")
	check(not player.effects.visible and game.camera.impulse == 0, "Menu clears active effects")
	game.start_race()
	check(game.finish_order.is_empty() and player.speed == 0, "Restart resets six-racer state")
	# Six-racer rear queues must not manufacture progress or sweep through hulls.
	for i in range(6):
		var racer: Racer = game.racers[i]
		racer.reset(140.0 + i * 8.0, 0.0)
		racer.speed = 116.0 if i == 0 else 20.0
		racer.prepare_step(0.2, Vector3(0, 0, 1) if i == 0 else Vector3.ZERO)
	RacerContacts.resolve(game.racers)
	var queue_clear := true
	for i in range(5):
		queue_clear = (
				queue_clear and game.racers[i + 1].track_distance - game.racers[i].track_distance >= 6.8
		)
	check(queue_clear, "Six-racer queue preserves longitudinal hull clearance")
	game.queue_free()
	await process_frame
	print("ARCADE CHECKS: %d FAILURES: %d" % [checks, failures])
	quit(1 if failures else 0)
