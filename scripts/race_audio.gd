extends Node

@export var enabled: bool = true


func _ready() -> void:
	var engine_stream: AudioStreamWAV = $Engine.stream.duplicate()
	engine_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	engine_stream.loop_begin = 0
	engine_stream.loop_end = engine_stream.data.size() / 2
	$Engine.stream = engine_stream


func update_engine(player: Racer, racing: bool) -> void:
	if not enabled:
		return
	if racing and not $Engine.playing:
		$Engine.play()
	elif not racing and $Engine.playing:
		$Engine.stop()
	$Engine.pitch_scale = 0.65 + player.speed / 95.0 * 1.4
	$Engine.volume_db = -25.0 + player.speed / 116.0 * 8.0
	if player.boost_active and racing:
		if not $Boost.playing:
			$Boost.play()
	else:
		$Boost.stop()


func cue(name: String) -> void:
	if enabled:
		get_node(name).play()
