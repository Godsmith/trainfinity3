extends BaseTest

func test_build_one_way_over_platform_when_train_halfway_in():
	Engine.set_time_scale(10.0)
	var station_dicts: Array[Dictionary] = [
	{"position": "(-48.0, 0.0)"},
	{"position": "(48.0, 0.0)"}
	]
	var track_dicts: Array[Dictionary] = [
	{"pos1": "(-32, 0)", "pos2": "(-16, 0)"},
	{"pos1": "(-16, 0)", "pos2": "(0, 0)"},
	{"pos1": "(0, 0)", "pos2": "(16, 0)"},
	{"pos1": "(16, 0)", "pos2": "(32, 0)"},
	]
	create(station_dicts, track_dicts)

	var stations = _game._get_stations()
	_game._try_create_train(stations[0], stations[1])
	var train: Train = get_tree().get_nodes_in_group("trains")[0]

	# Create a one-way halfway into the station when the train has already entered
	# the station
	await wait_until(func(): return Vector2i(train.get_train_position().snapped(Global.TILE)) == Vector2i(16, 0), 10.0)
	var track = _game.track_set.tracks_at_position(Vector2i(32, 0))[0]
	_game._rotate_one_way_direction(track)
	_game._rotate_one_way_direction(track)

	# Assert that the reaches this state
	assert_true(await wait_until(func(): return train.state == Train.State.WAITING_FOR_TRACK_RESERVATION_CHANGE, 10.0))
