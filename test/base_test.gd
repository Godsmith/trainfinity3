extends GutTest

class_name BaseTest

var _game: Game
var _sender: GutInputSender


func before_each():
	_game = load("res://scenes/overground.tscn").instantiate()
	add_child_autofree(_game)
	_game.terrain.set_seed_and_add_chunks(0, {Vector2i(0, 0): Terrain.ChunkType.DEBUG_GRASS_ONLY} as Dictionary[Vector2i, Terrain.ChunkType])
	_sender = InputSender.new(Input)

func after_each():
	_sender.release_all()
	_sender.clear()

## From string on the form "(1.0, 2.0)"
func vector2_from_string(s: String) -> Vector2:
	var halves = s.replace("(", "").replace(")", "").split(",")
	return Vector2(float(halves[0]), float(halves[1]))
