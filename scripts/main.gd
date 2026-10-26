extends Node3D

const RACER_SCENE := preload("res://scenes/racer.tscn")
@export var pilot_profiles: Array[PilotProfile] = []

enum State { MENU, COUNTDOWN, RACING, PAUSED, RESULTS, SETTINGS }

@onready var circuit: Circuit = $Circuit
@onready var camera: Camera3D = $ChaseCamera
@onready var driving: DrivingInput = $DrivingInput
@onready var ui: CanvasLayer = $GameUI
@onready var audio: Node = $RaceAudio
var data := SaveData.new()
var racers: Array[Racer] = []
var finish_order: Array[Racer] = []
var state: State = State.MENU
var previous_state: State = State.MENU
var resume_state: State = State.RACING
var elapsed: float = 0.0
var countdown: float = 3.5
var last_count: int = -1
var hud_timer: float = 0.0
var demo_mode: bool = false
var standings: Array[Racer] = []
var last_player_rank: int = 6
var position_cue_cooldown: float = 0.0


func _ready() -> void:
	data.load_settings()
	for index in range(pilot_profiles.size()):
		var racer: Racer = RACER_SCENE.instantiate()
		racer.ai_index = index - 1
		racer.profile = pilot_profiles[index]
		racer.neon_color = racer.profile.color
		racer.racer_name = racer.profile.display_name
		$Racers.add_child(racer)
		racer.setup(circuit, float(index / 2) * 14.0, -5.0 if index % 2 == 0 else 5.0)
		racers.append(racer)
	ui.setup_race(circuit, racers)
	standings = RaceStandings.ordered(racers)
	camera.target = racers[0]
	ui.action_requested.connect(_on_action)
	ui.setting_changed.connect(_on_setting)
	driving.pad_changed.connect(ui.set_pad_position)
	ui.load_settings(data)
	apply_settings()
	ui.show_screen("MainMenu")
	if "--demo" in OS.get_cmdline_user_args():
		demo_mode = true
		start_race()
		state = State.RACING
		ui.show_screen("")
		for racer in racers:
			racer.speed = 78.0


func start_race() -> void:
	audio.stop_all()
	elapsed = 0.0
	finish_order.clear()
	for i in range(racers.size()):
		racers[i].reset(float(i / 2) * 14.0, -5.0 if i % 2 == 0 else 5.0)
	standings = RaceStandings.ordered(racers)
	last_player_rank = standings.find(racers[0]) + 1
	position_cue_cooldown = 0.0
	ui.reset_effects()
	camera.clear_impulse()
	camera.snap_next = true
	start_countdown()


func start_countdown() -> void:
	driving.enabled = false
	driving.clear()
	state = State.COUNTDOWN
	countdown = 3.5
	last_count = -1
	ui.show_screen("")


func _physics_process(delta: float) -> void:
	driving.set_regions(ui.get_pad_rect(), ui.get_boost_rect())
	driving.enabled = state == State.RACING
	var controls := driving.read_controls(delta)
	if state == State.COUNTDOWN:
		countdown -= delta
		var count := ceili(countdown)
		if count != last_count and count > 0 and count <= 3:
			audio.countdown_tick(count)
			last_count = count
		ui.set_countdown(str(mini(3, count)) if count > 0 else "GO")
		if countdown <= 0:
			state = State.RACING
			driving.enabled = true
			audio.cue("Go")
	elif state == State.RACING or state == State.RESULTS:
		elapsed += delta
		for racer in racers:
			var input := controls if racer.ai_index < 0 else racer.ai_input(elapsed)
			if demo_mode and racer.ai_index < 0:
				input = Vector3(clampf(-racer.lateral_offset * 0.2 - racer.lateral_velocity * 0.12, -1, 1), 1, 0)
			racer.prepare_step(delta, input)
		RacerContacts.resolve(racers)
		for racer in racers:
			racer.finish_step(delta, elapsed)
			if (racer.wall_hit or racer.contact_hit) and racer.ai_index < 0:
				audio.cue("Wall")
			if racer == racers[0]:
				update_player_feedback(racer)
		var newly_finished: Array[Racer] = []
		for racer in racers:
			if racer.progress.finish_time >= 0 and racer.finished_rank == 0:
				newly_finished.append(racer)
		newly_finished.sort_custom(func(a: Racer, b: Racer) -> bool: return a.progress.finish_time < b.progress.finish_time)
		for racer in newly_finished:
			finish_order.append(racer)
			racer.finished_rank = finish_order.size()
		if racers[0].finished_rank > 0 and state == State.RACING:
			complete_race()
		if countdown > -0.7:
			countdown -= delta
			ui.set_countdown("GO" if countdown > -0.7 else "")
	position_cue_cooldown = maxf(0.0, position_cue_cooldown - delta)
	ui.update_effects(racers[0], delta, state == State.RACING)
	hud_timer += delta
	if hud_timer > 0.08:
		hud_timer = 0.0
		standings = RaceStandings.ordered(racers)
		var rank := standings.find(racers[0]) + 1
		if state == State.RACING and elapsed > 3.0 and rank < last_player_rank and position_cue_cooldown == 0.0:
			audio.cue("PositionGain")
			ui.show_race_message("POSITION +%d" % (last_player_rank - rank))
			position_cue_cooldown = 2.0
		last_player_rank = rank
		ui.update_hud(racers[0], rank, elapsed)
		ui.update_minimap(standings)
	audio.update_racers(racers, state == State.COUNTDOWN or state == State.RACING, delta)


func player_position() -> int:
	return RaceStandings.ordered(racers).find(racers[0]) + 1


func update_player_feedback(player: Racer) -> void:
	if player.wall_hit or player.contact_hit:
		camera.add_impulse(0.18)
		ui.flash_impact()
	if player.took_off:
		audio.cue("Takeoff")
		camera.add_impulse(0.10)
	if player.landed:
		audio.cue("Landing")
		camera.add_impulse(0.24)


func complete_race() -> void:
	ui.reset_effects()
	camera.clear_impulse()
	state = State.RESULTS
	driving.enabled = false
	driving.clear()
	data.best_race = minf(data.best_race, racers[0].progress.finish_time)
	data.best_lap = minf(data.best_lap, racers[0].progress.best_lap)
	data.save_settings()
	ui.show_results(racers[0], data)
	audio.cue("Finish")


func pause_race() -> void:
	if state not in [State.RACING, State.COUNTDOWN]:
		return
	resume_state = state
	state = State.PAUSED
	audio.stop_all()
	ui.reset_effects()
	camera.clear_impulse()
	for racer: Racer in racers:
		racer.effects.stop()
	driving.enabled = false
	driving.clear()
	for racer in racers:
		racer.boost_active = false
	ui.show_screen("PauseMenu")


func _on_action(action: String) -> void:
	match action:
		"play", "restart":
			start_race()
		"pause":
			pause_race()
		"resume":
			driving.clear()
			state = resume_state
			driving.enabled = state == State.RACING
			ui.show_screen("")
		"main":
			audio.stop_all()
			ui.reset_effects()
			camera.clear_impulse()
			for racer: Racer in racers:
				racer.effects.stop()
			state = State.MENU
			driving.enabled = false
			driving.clear()
			ui.show_screen("MainMenu")
		"settings":
			previous_state = state
			state = State.SETTINGS
			driving.enabled = false
			driving.clear()
			ui.show_screen("SettingsMenu")
		"back":
			state = previous_state
			ui.show_screen("PauseMenu" if state == State.PAUSED else "MainMenu")
		"quit":
			get_tree().quit()


func _on_setting(setting: String, value: Variant) -> void:
	data.set(setting, value)
	data.save_settings()
	apply_settings()


func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(data.volume, 0.0001)))
	camera.shake_enabled = data.camera_shake
	driving.sensitivity = data.sensitivity


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if state == State.PAUSED:
			_on_action("resume")
		else:
			pause_race()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		pause_race()
		driving.clear()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready():
		pause_race()
