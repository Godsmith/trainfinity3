extends BaseTest

func create_track_and_stations():
	_sender.key_down(KEY_1) # Switch to track mode
	_sender.mouse_left_click_at(Vector2i(200, 200))
	_sender.mouse_motion(Vector2i(400, 200))
	_sender.mouse_left_click_at(Vector2i(400, 200))
	_sender.mouse_motion(Vector2i(400, 200))
	_sender.mouse_left_click_at(Vector2i(400, 200))
	_sender.key_down(KEY_3) # Switch to station mode
	_sender.mouse_left_click_at(Vector2i(150, 200))
	_sender.mouse_left_click_at(Vector2i(450, 200))


func test_switching_to_train_mode_turns_platforms_green():
	create_track_and_stations()
	_sender.key_down(KEY_4) # Switch to train mode
	await _sender.idle

	await wait_idle_frames(1) # Seems to need to wait for a frame to change state?

	for platform: PlatformTile in get_tree().get_nodes_in_group("platforms"):
		assert_eq(platform.modulate, Color(0, 1, 0, 1))


func test_create_train():
	create_track_and_stations()
	_sender.key_down(KEY_4) # Switch to train mode
	_sender.mouse_left_click_at(Vector2i(200, 200))
	_sender.mouse_left_click_at(Vector2i(400, 200))
	await _sender.idle

	assert_eq(get_tree().get_node_count_in_group("trains"), 1)


func test_created_train_starts_moving():
	create_track_and_stations()
	_sender.key_down(KEY_4) # Switch to train mode
	_sender.mouse_left_click_at(Vector2i(200, 200))
	_sender.mouse_left_click_at(Vector2i(400, 200))
	await _sender.idle

	var train: Train = get_tree().get_nodes_in_group("trains")[0]

	await wait_idle_frames(10)

	assert_gt(train.absolute_speed, 0.0)

## This previously failed since _get_point_paths_between_platforms did not work for
## circular rail. If this needs changing, consider converting this into a unit test
## for that method instead.
func test_train_starts_when_circular_rail():
	var stations = [ {
	  "position": "(-32.0, 16.0)"
	},
	{
	  "position": "(-16.0, 80.0)"
	}
	]
	var track_dicts = [
	{
	  "pos1": "(0, 32)",
	  "pos2": "(16, 32)"
	},
	{
	  "pos1": "(-16, 32)",
	  "pos2": "(0, 32)"
	},
	{
	  "pos1": "(-32, 32)",
	  "pos2": "(-16, 32)"
	},
	{
	  "pos1": "(-48, 32)",
	  "pos2": "(-32, 32)"
	},
	{
	  "pos1": "(-64, 32)",
	  "pos2": "(-48, 32)"
	},
	{
	  "pos1": "(-64, 32)",
	  "pos2": "(-64, 48)"
	},
	{
	  "pos1": "(-64, 48)",
	  "pos2": "(-64, 64)"
	},
	{
	  "pos1": "(-64, 64)",
	  "pos2": "(-48, 64)"
	},
	{
	  "pos1": "(-48, 64)",
	  "pos2": "(-32, 64)"
	},
	{
	  "pos1": "(-32, 64)",
	  "pos2": "(-16, 64)"
	},
	{
	  "pos1": "(-16, 64)",
	  "pos2": "(0, 64)"
	},
	{
	  "pos1": "(0, 64)",
	  "pos2": "(16, 64)"
	},
	{
	  "pos1": "(16, 48)",
	  "pos2": "(16, 64)"
	},
	{
	  "pos1": "(16, 32)",
	  "pos2": "(16, 48)"
	}
	]
	var trains = [
	{
	  "destinations": [
		"(-32, 32)",
        "(-16, 64)"
	  ]
	}
	]
	for station_dict in stations:
		_game._try_create_station(vector2_from_string(station_dict.position))
	for track_dict in track_dicts:
		var tracks = _game.track_creator.create_ghost_track([vector2_from_string(track_dict.pos1), vector2_from_string(track_dict.pos2)])
		for track in tracks:
			add_child(track)
		_game.track_creator.create_tracks()
	for train_dict in trains:
		_game._try_create_train(vector2_from_string(train_dict.destinations[0]), vector2_from_string(train_dict.destinations[1]))

	await wait_idle_frames(10)

	var train: Train = get_tree().get_nodes_in_group("trains")[0]
	assert_gt(train.absolute_speed, 0.0)
