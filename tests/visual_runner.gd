extends SceneTree


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	# SubViewports need the same fixed rendering settings as the main window.
	viewport.use_hdr_2d = ProjectSettings.get_setting("rendering/viewport/hdr_2d")
	viewport.msaa_3d = ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d")
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game = load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.start_race()
	# These are staged views; focus changes must not replace the HUD with Pause.
	game.state = game.State.MENU
	game.ui.show_screen("")
	game.racers[0].track_distance = 1500.0
	game.racers[1].track_distance = 1528.0
	game.racers[2].track_distance = 1548.0
	for racer: Racer in game.racers:
		racer.speed = racer.tuning.top_speed
		racer.update_pose(0.1)
	game.camera.snap_next = true
	print(
			"Environment: ",
			game.camera.get_world_3d().environment,
			" expected ",
			game.get_node("WorldEnvironment").environment
	)
	game.ui.update_hud(game.racers[0], 3, 12.52)
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1600, 720)]:
		viewport.size = resolution
		await process_frame
		for i in range(10):
			await process_frame
		await RenderingServer.frame_post_draw
		var pad_rect: Rect2 = game.ui.get_pad_rect()
		var boost_rect: Rect2 = game.ui.get_boost_rect()
		assert(pad_rect.size == Vector2(240, 240), "Pad must remain 240 logical pixels")
		assert(boost_rect.end.x < pad_rect.position.x, "Driving controls must not overlap")
		assert(Rect2(Vector2.ZERO, Vector2(resolution)).encloses(pad_rect), "Pad stays onscreen")
		assert(
				Rect2(Vector2.ZERO, Vector2(resolution)).encloses(boost_rect), "Boost stays onscreen"
		)
		var image := viewport.get_texture().get_image()
		var name := "/tmp/neon-high-%d.png" % resolution.x
		image.save_png(name)
		print("Saved ", name)
	# Find representative sections from the authored route rather than old offsets.
	var sections := {"climb": 0.0, "descent": 0.0, "crest": 0.0, "dip": 0.0, "s-bend": 0.0}
	var steepest_climb := -INF
	var steepest_descent := INF
	var highest_point := -INF
	var lowest_point := INF
	var tightest_bend := 0.0
	for distance in range(0, ceili(game.circuit.length), 8):
		var pose: Transform3D = game.circuit.frame(distance)
		var slope := -pose.basis.z.y
		if slope > steepest_climb:
			steepest_climb = slope
			sections["climb"] = float(distance)
		if slope < steepest_descent:
			steepest_descent = slope
			sections["descent"] = float(distance)
		if pose.origin.y > highest_point:
			highest_point = pose.origin.y
			sections["crest"] = float(distance)
		# Inspect an interior dip rather than the flat starting grid.
		if distance > 300 and distance < game.circuit.length - 300 and pose.origin.y < lowest_point:
			lowest_point = pose.origin.y
			sections["dip"] = float(distance)
		var bend: float = absf(game.circuit.curvature(distance))
		if bend > tightest_bend:
			tightest_bend = bend
			sections["s-bend"] = float(distance)
	for tunnel: TrackTunnel in game.circuit.get_node("Tunnels").get_children():
		sections[tunnel.name + "-entrance"] = tunnel.start_distance - 45.0
		sections[tunnel.name + "-inside"] = tunnel.start_distance + tunnel.tunnel_length * 0.5
		sections[tunnel.name + "-exit"] = tunnel.start_distance + tunnel.tunnel_length - 20.0
	var jump_views := {}
	for jump: TrackJump in game.circuit.jumps:
		for phase: String in ["approach", "takeoff", "air", "landing"]:
			var offset: float = {"approach": -35.0, "takeoff": 8.0, "air": 140.0, "landing": 290.0}[phase]
			var view_name := jump.name + "-" + phase
			sections[view_name] = jump.takeoff_distance + offset
			jump_views[view_name] = jump.takeoff_distance
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1600, 720)]:
		viewport.size = resolution
		for section: String in sections:
			for index in range(game.racers.size()):
				var racer: Racer = game.racers[index]
				racer.reset(sections[section] + index * 24.0, -5.0 if index % 2 == 0 else 5.0)
				racer.speed = racer.tuning.top_speed
				if jump_views.has(section):
					racer.reset(jump_views[section] - 50.0, -5.0 if index % 2 == 0 else 5.0)
					racer.speed = racer.tuning.top_speed
					racer.progress.next_checkpoint = (
							floori(racer.track_distance / game.circuit.length * 16) + 1
					)
					var steps := 0
					while racer.track_distance < sections[section] + index * 24.0:
						steps += 1
						assert(steps < 600, "Staged jump must make forward progress")
						var steering := clampf(
								-racer.lateral_offset * 0.2 - racer.lateral_velocity * 0.12, -1, 1
						)
						racer.simulate(1.0 / 60.0, Vector3(steering, 1, 0), 1.0)
				racer.update_pose(0.1)
				racer.effects.update_racer(racer, 0.1)
			game.ui.update_minimap(RaceStandings.ordered(game.racers))
			game.ui.update_hud(game.racers[0], game.player_position(), 12.52)
			game.camera.snap_next = true
			for i in range(10):
				await process_frame
			await RenderingServer.frame_post_draw
			var filename := "/tmp/neon-section-%s-high-%d.png" % [section, resolution.x]
			viewport.get_texture().get_image().save_png(filename)
			print("Saved ", filename, " at ", sections[section])
	# Explicit six-racer map and arcade effect captures at both aspect ratios.
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1600, 720)]:
		viewport.size = resolution
		for view: String in ["grid", "field", "boost", "impact"]:
			game.start_race()
			game.state = game.State.MENU
			game.ui.show_screen("")
			if view != "grid":
				for index in range(game.racers.size()):
					var racer: Racer = game.racers[index]
					var distance := (
							1400.0 + index * 900.0 if view == "field" else 1400.0 + index * 14.0
					)
					racer.reset(distance, -5.0 if index % 2 == 0 else 5.0)
					racer.speed = racer.tuning.boost_speed if view == "boost" else racer.tuning.top_speed
					racer.engine_load = 1.0
					racer.boost_active = view == "boost"
					racer.update_pose(0.1)
					racer.effects.update_racer(racer, 0.1)
			game.ui.update_hud(game.racers[0], game.player_position(), 12.5)
			game.ui.update_minimap(RaceStandings.ordered(game.racers))
			if view == "impact":
				game.ui.flash_impact()
				game.racers[0].wall_hit = true
				game.racers[0].effects.update_racer(game.racers[0], 0.0)
			game.ui.update_effects(game.racers[0], 0.0, true)
			game.camera.snap_next = true
			for i in range(20):
				await process_frame
			await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png(
					"/tmp/neon-arcade-%s-%d.png" % [view, resolution.x]
			)
			print("Saved arcade view ", view, " at ", resolution.x)
	for screen: String in ["SettingsMenu", "PauseMenu", "ResultsMenu"]:
		game.ui.show_screen(screen)
		if screen == "ResultsMenu":
			game.racers[0].finished_rank = 1
			game.racers[0].progress.finish_time = 337.076
			game.racers[0].progress.best_lap = 111.0
			game.data.best_race = 337.076
			game.ui.show_results(game.racers[0], game.data)
		await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("/tmp/neon-%s.png" % screen)
	game.ui.show_screen("MainMenu")
	await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("/tmp/neon-menu.png")
	print("Rendering method: ", RenderingServer.get_current_rendering_method())
	print("Draw calls: ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	quit()
