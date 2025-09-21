extends Game

const T = Global.TILE_SIZE

func _ready():
	super._ready()

	bank.earn(10000)

	var track_positions: Array[Vector2i] = []
	for x in range(-6 * T, 7 * T, T):
		track_positions.append(Vector2i(x, T))

	_show_ghost_track(track_positions)
	_try_create_tracks()

	_try_create_station(Vector2i(-6 * T, 2 * T))
	_try_create_station(Vector2i(6 * T, 2 * T))


	_try_create_train(platform_set._platforms[Vector2i(-5 * T, T)],
					  platform_set._platforms[Vector2i(6 * T, T)])
