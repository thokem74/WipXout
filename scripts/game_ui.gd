extends CanvasLayer

signal action_requested(action: String)
signal setting_changed(setting: String, value: Variant)

const PANEL_NAMES := ["MainMenu", "PauseMenu", "SettingsMenu", "ResultsMenu"]
var active_screen: String = ""
var racer_count: int = 6
var impact_amount: float = 0.0
var message_time: float = 0.0

@onready var root: Control = $SafeArea
@onready var hud: Control = $SafeArea/HUD
@onready var overlay: Control = $SafeArea/Overlay


func _ready() -> void:
	for button: Button in get_tree().get_nodes_in_group("menu_button"):
		button.pressed.connect(_on_menu_button_pressed.bind(button))
	$SafeArea/HUD/Pause.pressed.connect(_on_pause_pressed)
	$SafeArea/Overlay/SettingsMenu/Volume.value_changed.connect(_on_volume_changed)
	$SafeArea/Overlay/SettingsMenu/Shake.toggled.connect(_on_camera_shake_toggled)
	$SafeArea/Overlay/SettingsMenu/Sensitivity.value_changed.connect(_on_sensitivity_changed)
	get_viewport().size_changed.connect(update_safe_area)
	update_safe_area()


func update_safe_area() -> void:
	var inset := Vector2(24, 18)
	if OS.has_feature("android"):
		var safe := DisplayServer.get_display_safe_area()
		var screen := DisplayServer.screen_get_size()
		var viewport_size := get_viewport().get_visible_rect().size
		if screen.x > 0 and screen.y > 0:
			var scale_factor := viewport_size / Vector2(screen)
			inset.x = maxf(
					inset.x, maxf(safe.position.x, screen.x - safe.end.x) * scale_factor.x + 12
			)
			inset.y = maxf(
					inset.y, maxf(safe.position.y, screen.y - safe.end.y) * scale_factor.y + 10
			)
	root.offset_left = inset.x
	root.offset_right = -inset.x
	root.offset_top = inset.y
	root.offset_bottom = -inset.y


func show_screen(screen: String) -> void:
	active_screen = screen
	overlay.visible = not screen.is_empty()
	for panel_name: String in PANEL_NAMES:
		overlay.get_node(panel_name).visible = panel_name == screen
	hud.visible = screen.is_empty()


func load_settings(data: SaveData) -> void:
	var settings := $SafeArea/Overlay/SettingsMenu
	settings.get_node("Volume").set_value_no_signal(data.volume)
	settings.get_node("Shake").set_pressed_no_signal(data.camera_shake)
	settings.get_node("Sensitivity").set_value_no_signal(data.sensitivity)


func update_hud(player: Racer, position_index: int, race_time: float) -> void:
	$SafeArea/HUD/Lap.text = "LAP\n%d / 3" % mini(player.progress.completed_laps + 1, 3)
	$SafeArea/HUD/Position.text = "POS\n%d / %d" % [position_index, racer_count]
	$SafeArea/HUD/Time.text = format_time(race_time)
	$SafeArea/HUD/Speed.text = "%03d\nKM/H" % roundi(player.speed * 3.6)
	$SafeArea/HUD/BoostMeter.value = player.boost_charge
	$SafeArea/HUD/Boost.text = "BOOST" if not player.boost_locked else "CHARGING"
	$SafeArea/HUD/Boost.modulate = Color(1, 0.4, 0.9) if player.boost_active else Color.WHITE


func set_countdown(text: String) -> void:
	$SafeArea/HUD/Countdown.text = text


func get_pad_rect() -> Rect2:
	return $SafeArea/HUD/DrivingPad.get_global_rect()


func get_boost_rect() -> Rect2:
	return $SafeArea/HUD/Boost.get_global_rect()


func set_pad_position(position: Vector2, active: bool) -> void:
	$SafeArea/HUD/DrivingPad.set_finger(position, active)


func show_results(player: Racer, data: SaveData) -> void:
	$SafeArea/Overlay/ResultsMenu/Result.text = (
			"POSITION  %d / %d\n\nRACE  %s\nBEST LAP  %s\n\nLOCAL BEST  %s"
			% [
				player.finished_rank,
				racer_count,
				format_time(player.progress.finish_time),
				format_time(player.progress.best_lap),
				format_time(data.best_race),
			]
	)
	show_screen("ResultsMenu")


static func format_time(seconds: float) -> String:
	if not is_finite(seconds) or seconds < 0:
		return "--:--.---"
	var milliseconds := roundi(seconds * 1000.0)
	return (
			"%02d:%02d.%03d" % [milliseconds / 60000, (milliseconds / 1000) % 60, milliseconds % 1000]
	)


func setup_race(circuit: Circuit, racers: Array[Racer]) -> void:
	racer_count = racers.size()
	$SafeArea/HUD/Minimap.setup(circuit, racers)
	update_minimap(RaceStandings.ordered(racers))


func update_minimap(standings: Array[Racer]) -> void:
	$SafeArea/HUD/Minimap.update_markers(standings)


func flash_impact() -> void:
	impact_amount = 1.0


func show_race_message(message: String) -> void:
	$SafeArea/HUD/RaceMessage.text = message
	message_time = 1.2


func update_effects(player: Racer, delta: float, active: bool) -> void:
	impact_amount = move_toward(impact_amount, 0.0, delta * 6.0)
	message_time = maxf(0.0, message_time - delta)
	$SafeArea/HUD/RaceMessage.modulate.a = minf(message_time * 3.0, 1.0) if active else 0.0
	var material: ShaderMaterial = $SafeArea/HUD/SpeedEffects.material
	material.set_shader_parameter("boost_amount", 1.0 if active and player.boost_active else 0.0)
	material.set_shader_parameter("impact_amount", impact_amount if active else 0.0)


func reset_effects() -> void:
	impact_amount = 0.0
	message_time = 0.0
	$SafeArea/HUD/RaceMessage.modulate.a = 0.0
	var material: ShaderMaterial = $SafeArea/HUD/SpeedEffects.material
	material.set_shader_parameter("boost_amount", 0.0)
	material.set_shader_parameter("impact_amount", 0.0)


func _on_menu_button_pressed(button: Button) -> void:
	action_requested.emit(str(button.get_meta("action")))


func _on_pause_pressed() -> void:
	action_requested.emit("pause")


func _on_volume_changed(value: float) -> void:
	setting_changed.emit("volume", value)


func _on_camera_shake_toggled(value: bool) -> void:
	setting_changed.emit("camera_shake", value)


func _on_sensitivity_changed(value: float) -> void:
	setting_changed.emit("sensitivity", value)
