extends Control
## Cache the full-course projection once; only six marker positions change.

var circuit: Circuit
var racers: Array[Racer] = []
var outline := PackedVector2Array()
var dots := PackedVector2Array()
var badges := PackedVector2Array()
var colors: Array[Color] = []
var player_index: int = -1
var track_bounds := Rect2()
var map_scale: float = 1.0
var map_origin := Vector2.ZERO


func setup(track: Circuit, field: Array[Racer]) -> void:
	circuit = track
	racers = field
	var points := circuit.route.curve.get_baked_points()
	track_bounds = Rect2(Vector2(points[0].x, points[0].z), Vector2.ZERO)
	for point: Vector3 in points:
		track_bounds = track_bounds.expand(Vector2(point.x, point.z))
	var available := size - Vector2(48, 48)
	map_scale = minf(available.x / track_bounds.size.x, available.y / track_bounds.size.y)
	map_origin = (size - track_bounds.size * map_scale) * 0.5
	outline.clear()
	for index in range(257):
		outline.append(project(circuit.frame(float(index) / 256.0 * circuit.length).origin))
	queue_redraw()


func project(point: Vector3) -> Vector2:
	return map_origin + (Vector2(point.x, point.z) - track_bounds.position) * map_scale


func update_markers(standings: Array[Racer]) -> void:
	if circuit == null:
		return
	dots.clear()
	badges.clear()
	colors.clear()
	player_index = -1
	for rank in range(standings.size()):
		var racer := standings[rank]
		# A finished pilot stays at the line while its final rank remains fixed.
		var distance := 0.0 if racer.finished_rank > 0 else racer.progress.distance
		var dot := project(circuit.frame(distance).origin)
		dots.append(dot)
		colors.append(racer.neon_color)
		if racer == racers[0]:
			player_index = rank
		var badge := place_badge(dot)
		badges.append(badge)
		var label := get_node("Rank%d" % (rank + 1)) as Label
		label.text = str(rank + 1)
		label.position = badge - Vector2(9, 10)
		label.modulate = Color.BLACK if racer.neon_color.get_luminance() > 0.4 else Color.WHITE
	queue_redraw()


func place_badge(dot: Vector2) -> Vector2:
	# Greedy rings keep clustered grid labels readable without moving track dots.
	for ring in range(5):
		for direction in range(12):
			var angle := -PI * 0.5 + direction * TAU / 12.0
			var candidate := dot + Vector2(cos(angle), sin(angle)) * (18.0 + ring * 13.0)
			candidate = candidate.clamp(Vector2(12, 12), size - Vector2(12, 12))
			var free := true
			for other: Vector2 in badges:
				if candidate.distance_to(other) < 23.0:
					free = false
					break
			if free:
				return candidate
	return Vector2(12 + badges.size() * 26, 12)


func _draw() -> void:
	if outline.size() < 2:
		return
	draw_polyline(outline, Color(0.14, 0.4, 0.55), 2.0, true)
	draw_line(outline[0] - Vector2(4, 0), outline[0] + Vector2(4, 0), Color.WHITE, 2.0)
	for index in range(dots.size()):
		draw_line(dots[index], badges[index], colors[index] * Color(1, 1, 1, 0.7), 1.0, true)
		draw_circle(dots[index], 4.0, colors[index])
		if index == player_index:
			draw_arc(dots[index], 6.0, 0, TAU, 16, Color.WHITE, 1.5, true)
		draw_circle(badges[index], 10.0, colors[index])
