class_name SaveData
extends RefCounted

var volume: float = 0.65
var camera_shake: bool = true
var sensitivity: float = 1.0
var best_race: float = INF
var best_lap: float = INF
var save_path: String = "user://neon_vector.cfg"


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return
	volume = clampf(float(config.get_value("settings", "volume", volume)), 0, 1)
	camera_shake = bool(config.get_value("settings", "camera_shake", camera_shake))
	sensitivity = clampf(float(config.get_value("settings", "sensitivity", sensitivity)), 0.5, 2.0)
	best_race = float(config.get_value("records", "race", INF))
	best_lap = float(config.get_value("records", "lap", INF))


func save_settings() -> Error:
	var config := ConfigFile.new()
	config.set_value("settings", "volume", volume)
	config.set_value("settings", "camera_shake", camera_shake)
	config.set_value("settings", "sensitivity", sensitivity)
	config.set_value("records", "race", best_race)
	config.set_value("records", "lap", best_lap)
	return config.save(save_path)
