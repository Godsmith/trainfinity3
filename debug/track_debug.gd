extends Game

const T = Global.TILE_SIZE
const STEELWORKS = preload("res://scenes/steelworks.tscn")
const FACTORY = preload("res://scenes/factory.tscn")

@export var create_ore_and_factory: bool
@export var diagonal_track: bool
@export var extra_track_after_first_station: bool = true

func _ready():
	super._ready()

	GlobalBank.earn(10000)

	if create_ore_and_factory:
		var ore = Ore.create(Ore.OreType.COAL)
		ore.position = Vector2i(-6 * T, 3 * T)
		add_child(ore)
		var steelworks = STEELWORKS.instantiate()
		steelworks.position = Vector2(6 * T, 3 * T)
		add_child(steelworks)
		var factory = FACTORY.instantiate()
		factory.position = Vector2(-7 * T, 2 * T)
		add_child(factory)

	var track_positions: Array[Vector2i] = []
	if diagonal_track:
		track_positions.append(Vector2i(-6 * T, T))
		track_positions.append(Vector2i(-5 * T, T))
		track_positions.append(Vector2i(-4 * T, T))
		track_positions.append(Vector2i(-3 * T, T))
		track_positions.append(Vector2i(-2 * T, T))
		track_positions.append(Vector2i(-1 * T, 2 * T))
		track_positions.append(Vector2i(0 * T, 2 * T))
		track_positions.append(Vector2i(1 * T, 2 * T))
		track_positions.append(Vector2i(2 * T, T))
		track_positions.append(Vector2i(3 * T, T))
		track_positions.append(Vector2i(4 * T, T))
		track_positions.append(Vector2i(5 * T, T))
		track_positions.append(Vector2i(6 * T, T))

	else:
		for x in range(-6 * T, 7 * T, T):
			track_positions.append(Vector2i(x, T))

	_show_ghost_track(track_positions)
	_try_create_tracks()

	if extra_track_after_first_station:
		_show_ghost_track([Vector2i(-4 * T, T), Vector2i(-4 * T, 0)])
		_try_create_tracks()

	_try_create_station(Vector2i(-6 * T, 2 * T))
	_try_create_station(Vector2i(6 * T, 2 * T))

	_try_create_train(platform_tile_set._platform_tiles[Vector2i(-5 * T, T)],
					  platform_tile_set._platform_tiles[Vector2i(6 * T, T)])
