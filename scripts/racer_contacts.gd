class_name RacerContacts
extends RefCounted
## Scene-authored hulls block spline movement analytically. Area overlap signals
## alone would detect contact after movement and can miss fast boost crossings.

const CLEARANCE: float = 0.02
const SOLVER_PASSES: int = 12


static func resolve(racers: Array[Racer]) -> void:
	# Revisit pairs so a rear-end queue or three-way side contact can settle.
	for pass_index in range(SOLVER_PASSES):
		var changed := false
		for first_index in range(racers.size()):
			for second_index in range(first_index + 1, racers.size()):
				if resolve_pair(racers[first_index], racers[second_index]):
					changed = true
		if not changed:
			break


static func resolve_pair(first: Racer, second: Racer) -> bool:
	# Finished ships stop at the line; they must not become permanent roadblocks.
	if first.progress.finish_time >= 0.0 or second.progress.finish_time >= 0.0:
		return false
	var first_box := first.collision_shape.shape as BoxShape3D
	var second_box := second.collision_shape.shape as BoxShape3D
	var separation := Vector2((first_box.size.x + second_box.size.x) * 0.5,
		(first_box.size.z + second_box.size.z) * 0.5)
	var start := Vector2(second.previous_lateral_offset - first.previous_lateral_offset,
		wrapf(second.previous_track_distance - first.previous_track_distance,
			-first.circuit.length * 0.5, first.circuit.length * 0.5))
	# Local +Z points backward, so a negative hull offset is ahead of the ship origin.
	start.y += first.collision_shape.position.z - second.collision_shape.position.z
	var movement := Vector2(
		(second.lateral_offset - second.previous_lateral_offset)
			- (first.lateral_offset - first.previous_lateral_offset),
		(second.track_distance - second.previous_track_distance)
			- (first.track_distance - first.previous_track_distance))
	var axis := swept_axis(start, movement, separation)
	if axis < 0:
		return false
	first.register_contact()
	second.register_contact()
	if axis == 1:
		var rear := first if start.y >= 0.0 else second
		var front := second if start.y >= 0.0 else first
		var gap := separation.y + CLEARANCE
		var front_distance := rear.track_distance + wrapf(front.track_distance - rear.track_distance,
			-first.circuit.length * 0.5, first.circuit.length * 0.5)
		front_distance += rear.collision_shape.position.z - front.collision_shape.position.z
		var blocked_distance := front_distance - gap
		if blocked_distance >= rear.previous_track_distance:
			# Only remove proposed movement: never reverse checkpoint progress or push
			# the leading ship forward without earning that distance through driving.
			var previous_proposal := rear.track_distance
			rear.track_distance = minf(rear.track_distance, blocked_distance)
			rear.speed = minf(rear.speed, front.speed)
			return rear.track_distance < previous_proposal
	# A pre-existing overlap cannot be fixed by rewinding a racer. Separate sideways.
	return separate_laterally(first, second, start.x, separation.x + CLEARANCE)


static func swept_axis(start: Vector2, movement: Vector2, size: Vector2) -> int:
	if absf(start.x) < size.x and absf(start.y) < size.y:
		return 0 if size.x - absf(start.x) < size.y - absf(start.y) else 1
	var entry := -INF
	var exit := INF
	var hit_axis := -1
	for axis in range(2):
		if absf(movement[axis]) < 0.000001:
			if absf(start[axis]) >= size[axis]:
				return -1
			continue
		var near_time := (-size[axis] - start[axis]) / movement[axis]
		var far_time := (size[axis] - start[axis]) / movement[axis]
		if near_time > far_time:
			var swap := near_time
			near_time = far_time
			far_time = swap
		if near_time > entry:
			entry = near_time
			hit_axis = axis
		exit = minf(exit, far_time)
	if entry < 0.0 or entry > 1.0 or entry > exit or exit < 0.0:
		return -1
	return hit_axis


static func separate_laterally(first: Racer, second: Racer, initial_gap: float, width: float) -> bool:
	var direction := 1.0 if initial_gap >= 0.0 else -1.0
	var overlap := width - direction * (second.lateral_offset - first.lateral_offset)
	if overlap <= 0.0:
		return false
	var first_limit := first.lateral_limit()
	var second_limit := second.lateral_limit()
	var first_before := first.lateral_offset
	first.lateral_offset = clampf(first_before - direction * overlap * 0.5, -first_limit, first_limit)
	var first_shift := absf(first.lateral_offset - first_before)
	var second_before := second.lateral_offset
	second.lateral_offset = clampf(second_before + direction * (overlap - first_shift),
		-second_limit, second_limit)
	var second_shift := absf(second.lateral_offset - second_before)
	# If one ship meets the rail, give the remaining separation to the other ship.
	first.lateral_offset = clampf(first.lateral_offset
		- direction * maxf(0.0, overlap - first_shift - second_shift), -first_limit, first_limit)
	if first.lateral_velocity * direction > 0.0:
		first.lateral_velocity *= -0.2
	if second.lateral_velocity * direction < 0.0:
		second.lateral_velocity *= -0.2
	return true
