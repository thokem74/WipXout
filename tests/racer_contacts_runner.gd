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
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.audio.enabled = false
	var rear: Racer = game.racers[0]
	var front: Racer = game.racers[1]
	var pair: Array[Racer] = [rear, front]
	var shape := rear.collision_shape.shape as BoxShape3D
	check(
			shape.size.x >= 8.0 and shape.size.z >= 6.7, "Scene hull covers ship wings, nose and tail"
	)
	for delta: float in [1.0 / 60.0, 0.2, 0.5]:
		rear.reset(140.0, 0.0)
		front.reset(148.0, 0.0)
		rear.speed = rear.tuning.boost_speed
		front.speed = 20.0
		rear.prepare_step(delta, Vector3(0, 0, 1))
		front.prepare_step(delta, Vector3.ZERO)
		RacerContacts.resolve(pair)
		check(
				front.track_distance - rear.track_distance >= shape.size.z,
				"Boosting rear ship cannot pass through a slower racer at delta %.3f" % delta
		)
		check(rear.speed <= front.speed, "Rear contact limits closing speed")
		rear.finish_step(delta, delta)
		front.finish_step(delta, delta)
		check(
				rear.track_distance >= 140.0 and rear.progress.distance == rear.track_distance,
				"Contact commits valid forward progress without rewinding"
		)
	# Two steering trajectories cross in one frame; endpoints alone would miss it.
	rear.reset(140.0, -5.0)
	front.reset(140.0, 5.0)
	rear.lateral_velocity = 120.0
	front.lateral_velocity = -120.0
	rear.prepare_step(0.1, Vector3.ZERO)
	front.prepare_step(0.1, Vector3.ZERO)
	RacerContacts.resolve(pair)
	check(
			front.lateral_offset - rear.lateral_offset >= shape.size.x,
			"Swept side contact prevents ships swapping lanes through each other"
	)
	check(
			rear.lateral_velocity <= 0.0 and front.lateral_velocity >= 0.0,
			"Side impacts rebound away from the other ship"
	)
	check(rear.contact_hit and front.contact_hit, "Both ships receive contact feedback")
	rear.reset(140.0, -10.9)
	front.reset(140.0, -5.0)
	rear.prepare_step(0.016, Vector3.ZERO)
	front.prepare_step(0.016, Vector3.ZERO)
	RacerContacts.resolve(pair)
	check(
			(
					front.lateral_offset - rear.lateral_offset >= shape.size.x
					and rear.lateral_offset >= -rear.lateral_limit()
					and front.lateral_offset <= front.lateral_limit()
			),
			"Side contact at a rail separates ships within track bounds"
	)
	# A clear adjacent lane must still permit a legitimate overtake.
	rear.reset(140.0, -5.0)
	front.reset(148.0, 5.0)
	rear.speed = rear.tuning.boost_speed
	rear.prepare_step(0.2, Vector3(0, 0, 1))
	front.prepare_step(0.2, Vector3.ZERO)
	RacerContacts.resolve(pair)
	check(
			rear.track_distance > front.track_distance and not rear.contact_hit,
			"Clear adjacent lanes permit overtaking"
	)
	rear.reset(140.0, 100.0)
	front.reset(140.0, 8.6)
	rear.prepare_step(0.016, Vector3.ZERO)
	front.prepare_step(0.016, Vector3.ZERO)
	RacerContacts.resolve(pair)
	check(
			not rear.contact_hit and is_zero_approx(rear.lateral_offset),
			"Off-track recovery does not sweep through another racer"
	)
	# Contact straddling the finish seam must be solved before a lap is awarded.
	var length: float = game.circuit.length
	rear.reset(length - 14.0, 0.0)
	rear.progress.next_checkpoint = rear.progress.checkpoint_count
	front.reset(1.0, 0.0)
	rear.speed = rear.tuning.boost_speed
	rear.prepare_step(0.2, Vector3(0, 0, 1))
	front.prepare_step(0.2, Vector3.ZERO)
	RacerContacts.resolve(pair)
	rear.finish_step(0.2, 0.2)
	front.finish_step(0.2, 0.2)
	check(
			rear.track_distance < length and rear.progress.completed_laps == 0,
			"A blocked finish crossing cannot award a lap"
	)
	check(rear.track_distance >= length - 14.0, "Seam contact cannot rewind progress")
	rear.reset(140.0, 0.0)
	front.reset(length + 148.0, 0.0)
	front.progress.completed_laps = 1
	rear.speed = rear.tuning.boost_speed
	rear.prepare_step(0.2, Vector3(0, 0, 1))
	front.prepare_step(0.2, Vector3.ZERO)
	RacerContacts.resolve(pair)
	check(
			rear.track_distance <= 148.0 - shape.size.z,
			"Ships on different lap counts still collide at the same track location"
	)
	# Resolve a three-ship pile-up without manufacturing race progress.
	for lane: float in [0.0, rear.lateral_limit()]:
		for racer: Racer in game.racers.slice(0, 3):
			racer.reset(140.0, lane)
			racer.prepare_step(0.016, Vector3.ZERO)
		RacerContacts.resolve([game.racers[0], game.racers[1], game.racers[2]])
		var separated := true
		for i in range(3):
			for j in range(i + 1, 3):
				separated = (
						separated
						and (
								absf(game.racers[i].lateral_offset - game.racers[j].lateral_offset)
								>= shape.size.x
						)
				)
		for racer: Racer in game.racers.slice(0, 3):
			racer.finish_step(0.016, 0.016)
			separated = separated and absf(racer.lateral_offset) <= racer.lateral_limit()
			separated = separated and racer.progress.distance == 140.0
		check(separated, "Three overlapping racers separate within the road at lane %.1f" % lane)
	rear.reset(140.0, 0.0)
	front.reset(148.0, 0.0)
	front.progress.finish_time = 1.0
	rear.speed = rear.tuning.boost_speed
	rear.prepare_step(0.2, Vector3(0, 0, 1))
	front.prepare_step(0.2, Vector3.ZERO)
	RacerContacts.resolve(pair)
	check(
			rear.track_distance > front.track_distance and not rear.contact_hit,
			"Finished parked ships do not block remaining racers"
	)
	rear.reset()
	check(
			not rear.contact_hit and rear.contact_cooldown == 0.0,
			"Restart clears contact feedback and cooldown"
	)
	# Height participates in the sweep: a clear airborne pass must not be blocked.
	for delta: float in [0.2, 0.5]:
		rear.reset(140.0)
		front.reset(148.0)
		rear.speed = rear.tuning.boost_speed
		rear.airborne = true
		rear.air_height = 6.0
		rear.prepare_step(delta, Vector3(0, 1, 1))
		front.prepare_step(delta, Vector3.ZERO)
		RacerContacts.resolve(pair)
		check(
				rear.track_distance > front.track_distance and not rear.contact_hit,
				"Vertically separated racers can overtake at delta %.2f" % delta
		)
	# Ships on the same flight arc still collide longitudinally.
	rear.reset(140.0)
	front.reset(148.0)
	for racer: Racer in pair:
		racer.airborne = true
		racer.air_height = 5.0
	rear.speed = rear.tuning.boost_speed
	rear.prepare_step(0.2, Vector3(0, 1, 1))
	front.prepare_step(0.2, Vector3.ZERO)
	RacerContacts.resolve(pair)
	check(
			front.track_distance - rear.track_distance >= shape.size.z and rear.contact_hit,
			"Overlapping flight paths retain rear collision blocking"
	)
	# Landing through another hull must separate sideways within the rails.
	rear.reset(140.0)
	front.reset(140.0)
	rear.airborne = true
	rear.air_height = 3.0
	rear.vertical_velocity = -8.0
	rear.prepare_step(0.3, Vector3.ZERO)
	front.prepare_step(0.3, Vector3.ZERO)
	RacerContacts.resolve(pair)
	check(
			absf(front.lateral_offset - rear.lateral_offset) >= shape.size.x,
			"Swept landing contact separates racers before hulls overlap"
	)
	check(
			(
					absf(rear.lateral_offset) <= rear.lateral_limit()
					and absf(front.lateral_offset) <= front.lateral_limit()
			),
			"Landing separation respects rails"
	)
	game.queue_free()
	await process_frame
	print("RACER CONTACT CHECKS: %d FAILURES: %d" % [checks, failures])
	quit(1 if failures else 0)
