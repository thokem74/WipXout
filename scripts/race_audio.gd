extends Node

@export var enabled: bool = true:
	set(value):
		enabled = value
		if not enabled and is_node_ready():
			stop_all()

var _loads: Array[float] = [0.0, 0.0, 0.0]
var _signal_duck_db: float = 0.0

@onready var _idle_engines: Array[Node] = [
	$EngineIdle, $RivalOneIdle, $RivalTwoIdle]
@onready var _loaded_engines: Array[Node] = [
	$EngineLoad, $RivalOneLoad, $RivalTwoLoad]
@onready var _boost: AudioStreamPlayer = $Boost
@onready var _cues: Array[AudioStreamPlayer] = [$Countdown, $Go, $Wall, $Finish]


func _ready() -> void:
	for index in range(_idle_engines.size()):
		_idle_engines[index].stream = make_loop(_idle_engines[index].stream)
		_loaded_engines[index].stream = make_loop(_loaded_engines[index].stream)
	_boost.stream = make_loop(_boost.stream)


func _exit_tree() -> void:
	stop_all()


func make_loop(source: AudioStreamWAV) -> AudioStreamWAV:
	var stream := source.duplicate() as AudioStreamWAV
	# Loop positions count decoded audio frames, even when imports compress data.
	var frame_count := roundi(stream.get_length() * stream.mix_rate)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = frame_count
	return stream


func update_racers(racers: Array[Racer], engines_active: bool, delta: float) -> void:
	if not enabled:
		return
	if not engines_active:
		stop_engines()
		return
	var response := 1.0 - exp(-delta * 8.0)
	var duck_target := -6.0 if _cues[0].playing or _cues[1].playing else 0.0
	_signal_duck_db = lerpf(_signal_duck_db, duck_target, response)
	for index in range(_idle_engines.size()):
		var racer := racers[index]
		var idle := _idle_engines[index]
		var loaded := _loaded_engines[index]
		_loads[index] = lerpf(_loads[index], racer.engine_load, response)
		var speed_ratio := clampf(racer.speed / racer.tuning.top_speed, 0.0, 1.3)
		var pitch := 0.68 + speed_ratio * 0.65 + _loads[index] * 0.18
		if index > 0:
			pitch *= passby_pitch(racer, racers[0])
			idle.global_position = racer.global_position
			loaded.global_position = racer.global_position
		if not idle.playing:
			idle.pitch_scale = pitch
			loaded.pitch_scale = pitch
			idle.play()
			loaded.play()
		idle.pitch_scale = lerpf(idle.pitch_scale, pitch, response)
		loaded.pitch_scale = idle.pitch_scale
		# Equal-power blending avoids a dip halfway between idle and loaded loops.
		# Keep the player's engine directly audible, independent of the listener.
		# Reserve positional attenuation for opponents and room for race signals.
		var volume := (-4.0 if index == 0 else -16.0) + speed_ratio * 2.0 + _signal_duck_db
		var idle_reduction := -5.0 if index == 0 else -2.0
		idle.volume_db = volume + idle_reduction + linear_to_db(maxf(0.001, sqrt(1.0 - _loads[index])))
		loaded.volume_db = volume + linear_to_db(maxf(0.001, sqrt(_loads[index])))
	var player := racers[0]
	if player.boost_active and not _boost.playing:
		_boost.play()
	var boost_volume := -12.0 if player.boost_active else -60.0
	_boost.volume_db = lerpf(_boost.volume_db, boost_volume, response)
	_boost.pitch_scale = 0.9 + clampf(player.speed / player.tuning.top_speed, 0.0, 1.3) * 0.2
	if not player.boost_active and _boost.volume_db < -55.0:
		_boost.stop()


func passby_pitch(source: Racer, listener: Racer) -> float:
	var separation := source.global_position - listener.global_position
	if separation.length_squared() < 1.0:
		return 1.0
	var source_velocity := -source.basis.z * source.speed + source.basis.x * source.lateral_velocity
	var listener_velocity := -listener.basis.z * listener.speed + listener.basis.x * listener.lateral_velocity
	var radial_speed := (source_velocity - listener_velocity).dot(separation.normalized())
	# Negative radial speed means approaching. Use current velocities rather than
	# position differences so a recovery/reset cannot produce a Doppler spike.
	return clampf(343.0 / (343.0 + clampf(radial_speed, -80.0, 80.0)), 0.8, 1.25)


func countdown_tick(count: int) -> void:
	if enabled:
		$Countdown.pitch_scale = 0.85 + (3 - clampi(count, 1, 3)) * 0.15
		$Countdown.play()


func cue(name: String) -> void:
	if enabled:
		get_node(name).play()


func stop_engines() -> void:
	_signal_duck_db = 0.0
	for index in range(_idle_engines.size()):
		_idle_engines[index].stop()
		_loaded_engines[index].stop()
		_idle_engines[index].volume_db = -60.0
		_loaded_engines[index].volume_db = -60.0
		_loads[index] = 0.0
	_boost.stop()
	_boost.volume_db = -60.0


func stop_all() -> void:
	stop_engines()
	for player in _cues:
		player.stop()
