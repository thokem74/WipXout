class_name RaceStandings
extends RefCounted
## Use earned, unwrapped progress; wrapping is only for map placement.

static func ordered(racers: Array[Racer]) -> Array[Racer]:
	var result: Array[Racer] = racers.duplicate()
	result.sort_custom(func(first: Racer, second: Racer) -> bool:
		if first.finished_rank > 0 or second.finished_rank > 0:
			if first.finished_rank == 0:
				return false
			if second.finished_rank == 0:
				return true
			return first.finished_rank < second.finished_rank
		if first.progress.distance != second.progress.distance:
			return first.progress.distance > second.progress.distance
		return racers.find(first) < racers.find(second))
	return result
