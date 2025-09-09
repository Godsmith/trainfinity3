extends Node

class_name Global

const TILE_SIZE := 16
const TILE := Vector2(TILE_SIZE, TILE_SIZE)

enum Asset {TRACK, STATION, TRAIN}

static func is_orthogonally_adjacent(position1: Vector2i, position2: Vector2i) -> bool:
	return position2 in orthogonally_adjacent(position1)

static func orthogonally_adjacent(pos: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for delta in [Vector2i(TILE_SIZE, 0), Vector2i(-TILE_SIZE, 0),
				  Vector2i(0, TILE_SIZE), Vector2i(0, -TILE_SIZE)]:
		out.append(pos + delta)
	return out
