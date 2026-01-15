extends GutTest

class_name BaseTest

var _game: Game
var _sender: GutInputSender


func before_each():
	Engine.set_time_scale(1.0)
	_game = load("res://scenes/overground.tscn").instantiate()
	add_child_autofree(_game)
	_game.terrain.set_seed_and_add_chunks(0, {Vector2i(0, 0): Terrain.ChunkType.DEBUG_GRASS_ONLY} as Dictionary[Vector2i, Terrain.ChunkType])
	# Disable needless sound effects by default
	GlobalBank.is_effects_enabled = false
	# Give infinite money by default, so that track building etc is not hindered
	GlobalBank.set_money(Global.MAX_INT)
	Upgrades.reset()
	_sender = InputSender.new(Input)

func after_each():
	_sender.release_all()
	_sender.clear()

## From string on the form "(1.0, 2.0)"
func vector2_from_string(s: String) -> Vector2:
	var halves = s.replace("(", "").replace(")", "").split(",")
	return Vector2(float(halves[0]), float(halves[1]))

func create(station_dicts: Array[Dictionary], track_dicts: Array[Dictionary]):
	for station_dict in station_dicts:
		_game._try_create_station(vector2_from_string(station_dict.position))
	for track_dict in track_dicts:
		var tracks = _game.track_creator.create_ghost_track([vector2_from_string(track_dict.pos1), vector2_from_string(track_dict.pos2)])
		for track in tracks:
			_game.add_child(track)
		_game.track_creator.create_tracks()
