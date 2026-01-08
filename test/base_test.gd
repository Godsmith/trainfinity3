extends GutTest

class_name BaseTest

var _game: Game
var _sender: GutInputSender


func before_each():
	_game = load("res://scenes/overground.tscn").instantiate()
	add_child_autofree(_game)
	_game.terrain.set_seed_and_add_chunks(0, {Vector2i(0, 0): Terrain.ChunkType.DEBUG_GRASS_ONLY} as Dictionary[Vector2i, Terrain.ChunkType])
	_sender = InputSender.new(_game)

func after_each():
	_sender.release_all()
	_sender.clear()
