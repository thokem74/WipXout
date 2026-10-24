class_name RaceProgress
extends RefCounted
## Only consecutive forward checkpoint crossings can advance the lap counter.

var circuit_length: float
var checkpoint_count: int = 16
var distance: float = 0.0
var next_checkpoint: int = 1
var completed_laps: int = 0
var lap_started_at: float = 0.0
var best_lap: float = INF
var finish_time: float = -1.0
var last_lap: float = 0.0


func _init(length_meters: float = 8000.0) -> void:
	circuit_length = length_meters


func reset(start_distance: float = 0.0) -> void:
	distance = start_distance
	next_checkpoint = 1
	completed_laps = 0
	lap_started_at = 0.0
	best_lap = INF
	last_lap = 0.0
	finish_time = -1.0


func advance(new_distance: float, delta: float, race_time: float) -> bool:
	if finish_time >= 0.0:
		return false
	var movement := new_distance - distance
	# Recovery and externally supplied positions must not turn into race progress.
	if movement < -0.001 or movement > 150.0 * delta + 0.5:
		return false
	var checkpoint_spacing := circuit_length / checkpoint_count
	var target := completed_laps * circuit_length + next_checkpoint * checkpoint_spacing
	if new_distance >= target:
		if distance > target or new_distance - target >= checkpoint_spacing:
			return false
		next_checkpoint += 1
		if next_checkpoint > checkpoint_count:
			var crossing_time := race_time
			if movement > 0.0:
				crossing_time -= delta * (new_distance - target) / movement
			last_lap = crossing_time - lap_started_at
			best_lap = minf(best_lap, last_lap)
			lap_started_at = crossing_time
			completed_laps += 1
			next_checkpoint = 1
			if completed_laps == 3:
				finish_time = crossing_time
	distance = new_distance
	return true
