extends SceneTree


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game = load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.start_race()
	game.state = game.State.RACING
	game.ui.show_screen("")
	game.racers[0].track_distance = 1500.0
	game.racers[1].track_distance = 1528.0
	game.racers[2].track_distance = 1548.0
	for racer: Racer in game.racers:
		racer.speed = 88.0
		racer.update_pose(0.1)
	game.camera.snap_next = true
	print("Environment: ", game.camera.get_world_3d().environment, " expected ", game.get_node("WorldEnvironment").environment)
	game.ui.update_hud(game.racers[0], 3, 12.52)
	for quality: bool in [true, false]:
		game.data.high_quality = quality
		game.apply_settings()
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
			assert(Rect2(Vector2.ZERO, Vector2(resolution)).encloses(boost_rect), "Boost stays onscreen")
			var image := viewport.get_texture().get_image()
			var name := "/tmp/neon-%s-%d.png" % ["high" if quality else "low", resolution.x]
			image.save_png(name)
			print("Saved ", name)
	# Inspect the high viaduct and all menu layouts as well as the main race view.
	for distance: float in [4400.0, 7000.0]:
		for index in range(3):
			game.racers[index].track_distance = distance + index * 24.0
			game.racers[index].update_pose(0.1)
		game.camera.snap_next = true
		for i in range(10):
			await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("/tmp/neon-section-%d.png" % distance)
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
