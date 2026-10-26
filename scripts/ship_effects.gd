extends Node3D
## Scene-authored emitters are reused; no particle nodes are spawned in gameplay.

var burst_cooldown: float = 0.0


func set_color(color: Color) -> void:
	for node: MeshInstance3D in [$Flames/Left, $Flames/Right]:
		var material := node.material_override as StandardMaterial3D
		material.albedo_color = color
		material.emission = color
	for particles: GPUParticles3D in [$Trail, $Burst]:
		var material := particles.draw_pass_1.material as StandardMaterial3D
		material.albedo_color = color
		material.emission = color


func update_racer(racer: Racer, delta: float) -> void:
	burst_cooldown = maxf(0.0, burst_cooldown - delta)
	if racer.progress.finish_time >= 0.0:
		stop()
		return
	visible = true
	var power := clampf(racer.speed / racer.tuning.top_speed, 0.0, 1.3)
	$Flames.visible = racer.engine_load > 0.05
	$Flames.scale.z = 0.35 + racer.engine_load * 0.55 + (1.3 if racer.boost_active else 0.0)
	$Trail.emitting = power > 0.35
	$Trail.amount_ratio = 1.0 if racer.boost_active else 0.45
	if (
			(racer.wall_hit or racer.contact_hit or racer.took_off or racer.landed)
			and burst_cooldown == 0.0
	):
		$Burst.restart()
		$Burst.emitting = true
		burst_cooldown = 0.25


func stop() -> void:
	visible = false
	$Trail.emitting = false
	$Burst.emitting = false
	burst_cooldown = 0.0
