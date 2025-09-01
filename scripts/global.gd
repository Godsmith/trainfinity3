extends Node

const TILE_SIZE := 16

static func is_orthogonally_adjacent(position1: Vector2i, position2: Vector2i) -> bool:
	for delta in [Vector2i(TILE_SIZE, 0),Vector2i(-TILE_SIZE, 0), 
				  Vector2i(0, TILE_SIZE), Vector2i(0, -TILE_SIZE)]:
		if position1 + delta == position2:
			return true
	return false
