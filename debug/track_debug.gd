extends Game

const T = Global.TILE_SIZE
const FACTORY = preload("res://scenes/factory.tscn")

@export var create_ore_and_factory: bool

func _ready():
	super._ready()

	bank.earn(10000)

	if create_ore_and_factory:
		var ore = Ore.create(Ore.OreType.COAL)
		ore.position = Vector2i(-6 * T, 3 * T)
		add_child(ore)
		var factory = FACTORY.instantiate()
		factory.position = Vector2(6 * T, 3 * T)
		add_child(factory)

	var track_positions: Array[Vector2i] = []
	for x in range(-6 * T, 7 * T, T):
		track_positions.append(Vector2i(x, T))

	_show_ghost_track(track_positions)
	_try_create_tracks()

	_try_create_station(Vector2i(-6 * T, 2 * T))
	_try_create_station(Vector2i(6 * T, 2 * T))


	_try_create_train(platform_set._platforms[Vector2i(-5 * T, T)],
					  platform_set._platforms[Vector2i(6 * T, T)])
