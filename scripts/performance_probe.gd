extends Node
## Debug-only, on-device measurements. Never substitutes desktop timing for phone FPS.

var measured_state: int = -1
var measured_quality: bool = false
var duration: float = 0.0
var frames: int = 0
var worst_delta: float = 0.0
var warmup: float = 3.0


func _ready() -> void:
	set_process(OS.is_debug_build())


func _process(delta: float) -> void:
	var game := get_parent()
	if game.state != measured_state or game.data.high_quality != measured_quality:
		measured_state = game.state
		measured_quality = game.data.high_quality
		duration = 0.0
		frames = 0
		worst_delta = 0.0
		warmup = 3.0
	if game.state != game.State.RACING:
		return
	if warmup > 0.0:
		warmup -= delta
		return
	duration += delta
	frames += 1
	worst_delta = maxf(worst_delta, delta)
	if duration >= 10.0:
		print("NVR_METRICS quality=%s fps=%.1f worst_frame_ms=%.1f draw_calls=%d triangles=%d" % [
			"high" if measured_quality else "low", frames / duration, worst_delta * 1000.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
		duration = 0.0
		frames = 0
		worst_delta = 0.0
