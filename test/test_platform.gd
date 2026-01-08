extends BaseTest


func before_each():
	_game = load("res://scenes/overground.tscn").instantiate()
	add_child_autofree(_game)
	_game.terrain.set_seed_and_add_chunks(0, {Vector2i(0, 0): Terrain.ChunkType.DEBUG_GRASS_ONLY} as Dictionary[Vector2i, Terrain.ChunkType])


func test_hovering_in_station_mode_creates_ghost_platform_tiles():
	press(KEY_1) # Switch to track mode
	click(200, 200)
	click(400, 200)
	click(400, 200)
	press(KEY_3) # Switch to station mode
	mouse_move(150, 200)

	assert_eq(get_tree().get_node_count_in_group("platforms"), 2)
