extends BaseTest

const STEELWORKS = preload("res://scenes/industry/steelworks.tscn")

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


func test_switching_to_train_mode_turns_stations_green():
	create_track_and_stations()
	_sender.key_down(KEY_4) # Switch to train mode
	await _sender.idle

	await wait_idle_frames(1) # Seems to need to wait for a frame to change state?

	for station: Station in _game._get_stations():
		assert_eq(station.modulate, Color(0, 1, 0, 1))


func test_create_train():
	create_track_and_stations()
	_sender.key_down(KEY_4) # Switch to train mode
	_sender.mouse_left_click_at(Vector2i(150, 200))
	_sender.mouse_left_click_at(Vector2i(450, 200))
	await _sender.idle

	assert_eq(get_tree().get_node_count_in_group("trains"), 1)


func test_created_train_starts_moving():
	create_track_and_stations()
	_sender.key_down(KEY_4) # Switch to train mode
	_sender.mouse_left_click_at(Vector2i(150, 200))
	_sender.mouse_left_click_at(Vector2i(450, 200))
	await _sender.idle

	var train: Train = get_tree().get_nodes_in_group("trains")[0]

	await wait_idle_frames(10)

	assert_gt(train.absolute_speed, 0.0)

## This previously failed since _get_point_paths_between_platforms did not work for
## circular rail. If this needs changing, consider converting this into a unit test
## for that method instead.
func test_train_starts_when_circular_rail():
	var station_dicts = [ {
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
	for station_dict in station_dicts:
		_game._try_create_station(vector2_from_string(station_dict.position))
	for track_dict in track_dicts:
		var tracks = _game.track_creator.create_ghost_track([vector2_from_string(track_dict.pos1), vector2_from_string(track_dict.pos2)])
		for track in tracks:
			_game.add_child(track)
		_game.track_creator.create_tracks()
	var stations = _game._get_stations()
	_game._try_create_train(stations[0], stations[1])

	await wait_idle_frames(10)

	var train: Train = get_tree().get_nodes_in_group("trains")[0]
	assert_gt(train.absolute_speed, 0.0)


## If a train goes between two platforms, and a change makes those platforms combine
## into one, then the train should go into State.WAITING_SINCE_DESTINATIONS_AT_SAME_PLATFORM
##    │
## S──┴──S -> S─────S
func test_destination_platforms_combining_results_in_state_waiting_destinations_same():
	var station_dicts: Array[Dictionary] = [
	{"position": "(-48.0, 0.0)"},
	{"position": "(48.0, 0.0)"}
	]
	var track_dicts: Array[Dictionary] = [
	{"pos1": "(-32, 0)", "pos2": "(-16, 0)"},
	{"pos1": "(-16, 0)", "pos2": "(0, 0)"},
	{"pos1": "(0, 0)", "pos2": "(16, 0)"},
	{"pos1": "(16, 0)", "pos2": "(32, 0)"},
	{"pos1": "(0, -16)", "pos2": "(0, 0)"},
	]
	# 3 upgrades + Base length 2 = length 5
	Upgrades.upgrades[Upgrades.UpgradeType.PLATFORM_LENGTH].current_level = 3
	create(station_dicts, track_dicts)
	var stations = _game._get_stations()
	_game._try_create_train(stations[0], stations[1])

	# Destroying the track in the middle makes the platforms combine into one large
	_game._destroy_track([Vector2i(0, -16)])
	await wait_idle_frames(2)

	var train: Train = get_tree().get_nodes_in_group("trains")[0]
	assert_eq(train.state, Train.State.WAITING_SINCE_DESTINATIONS_AT_SAME_PLATFORM)


##    ┃  Train goes between the right and the left station. On the way back, the train 
##  SS┃  will remain at the same platform. 
##  ━━┘
func test_train_gets_the_same_platform_as_both_destinations():
	Engine.set_time_scale(10.0)
	var station_dicts: Array[Dictionary] = [
	{"position": "(16, -16)"},
	{"position": "(0, -16)"},
	]
	var track_dicts: Array[Dictionary] = [
	{"pos1": "(0, 0)", "pos2": "(16, 0)"},
	{"pos1": "(16, 0)", "pos2": "(32, 0)"},
	{"pos1": "(32, 0)", "pos2": "(32, -16)"},
	{"pos1": "(32, -16)", "pos2": "(32, -32)"},
	]
	create(station_dicts, track_dicts)
	var stations = _game._get_stations()
	_game._try_create_train(stations[0], stations[1])
	var train: Train = get_tree().get_nodes_in_group("trains")[0]

	# assert that the state eventually reaches the target state
	while true:
		await wait_for_signal(train.train_state_changed, 2.0)
		if train.state == Train.State.WAITING_SINCE_DESTINATIONS_AT_SAME_PLATFORM:
			break
	assert_eq(train.state, Train.State.WAITING_SINCE_DESTINATIONS_AT_SAME_PLATFORM)


func create_two_stations():
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

func create_two_stations_and_train():
	create_two_stations()
	var stations = _game._get_stations()
	_game._try_create_train(stations[0], stations[1])

func test_go_to_waiting_for_station_when_station_removed():
	Engine.set_time_scale(10.0)
	create_two_stations_and_train()

	await wait_idle_frames(10)
	_game._destroy_stations([Vector2i(48.0, 0.0)])

	var train: Train = get_tree().get_nodes_in_group("trains")[0]
	# assert that the state eventually reaches the target state
	while true:
		await wait_for_signal(train.train_state_changed, 2.0)
		if train.state == Train.State.WAITING_FOR_MISSING_STATION:
			break
	assert_eq(train.state, Train.State.WAITING_FOR_MISSING_STATION)


func test_go_to_waiting_for_platform_when_platform_removed():
	Engine.set_time_scale(10.0)
	create_two_stations_and_train()

	await wait_idle_frames(10)
	create([], [ {"pos1": "(32, 0)", "pos2": "(32, -16)"}])

	var train: Train = get_tree().get_nodes_in_group("trains")[0]
	# assert that the state eventually reaches the target state
	while true:
		await wait_for_signal(train.train_state_changed, 2.0)
		if train.state == Train.State.WAITING_FOR_MISSING_PLATFORM:
			break
	assert_eq(train.state, Train.State.WAITING_FOR_MISSING_PLATFORM)


func create_ore(x: int, y: int):
	var ore = Ore.create(Global.ResourceType.COAL)
	ore.position = Vector2i(x, y)
	_game.terrain.add_child(ore)

func create_steelworks(x: int, y: int):
	var steelworks = STEELWORKS.instantiate()
	steelworks.position = Vector2i(x, y)
	_game.terrain.add_child(steelworks)


func test_train_loading_resource():
	Engine.set_time_scale(10.0)
	create_two_stations()
	create_ore(-64, 0)
	create_steelworks(64, 0)

	var stations = _game._get_stations()
	_game._try_create_train(stations[0], stations[1])
	var train: Train = get_tree().get_nodes_in_group("trains")[0]

	# Wait until the train leaves the station
	while true:
		await wait_for_signal(train.train_state_changed, 2.0)
		if train.state == Train.State.RUNNING:
			break
	
	assert_eq(train.wagons[0].get_total_resource_count(), 1)


## This previously caused a crash
func test_station_removed_when_loading_resource():
	Engine.set_time_scale(10.0)
	create_two_stations()
	create_ore(-64, 0)
	create_steelworks(64, 0)

	var stations = _game._get_stations()
	for i in 10:
		stations[0].add_resource(Global.ResourceType.COAL, true)
	_game._try_create_train(stations[0], stations[1])
	var train: Train = get_tree().get_nodes_in_group("trains")[0]

	# wait_seconds(0.5) here for some reason destroyed the station immediately,
	# so wait a number of frames instead
	await wait_frames(10)
	# To be sure that we have waited enough, ensure that the wagon has loaded some cargo
	assert_gt(train.wagons[0].get_total_resource_count(), 0)
	_game._destroy_stations([Vector2i(-48.0, 0.0)])
	await wait_frames(10)

	# Currently, the train will go to RUNNING because in the logic it is allowed to turn
	# around since when it comes from state LOADING. If this logic changes in the 
	# future, this assertion might fail.
	assert_eq(train.state, Train.State.RUNNING)


func test_other_station_removed_when_loading_resource():
	Engine.set_time_scale(10.0)
	create_two_stations()
	create_ore(-64, 0)
	create_steelworks(64, 0)

	var stations = _game._get_stations()
	for i in 10:
		stations[0].add_resource(Global.ResourceType.COAL, true)
	_game._try_create_train(stations[0], stations[1])
	var train: Train = get_tree().get_nodes_in_group("trains")[0]

	await wait_seconds(0.5)
	# Previously, this caused a crash
	_game._destroy_stations([Vector2i(48.0, 0.0)])
	await wait_frames(10)

	assert_eq(train.state, Train.State.WAITING_FOR_MISSING_STATION)


func test_go_between_two_stations():
	Engine.set_time_scale(10.0)
	create_two_stations()

	var stations = _game._get_stations()
	_game._try_create_train(stations[0], stations[1])
	var train: Train = get_tree().get_nodes_in_group("trains")[0]

	# Assert that the train is close to the other station
	assert_true(await wait_until(func(): return Vector2i(train.get_train_position().snapped(Global.TILE)) == Vector2i(32, 0), 10.0))

func test_go_between_two_stations_and_back():
	Engine.set_time_scale(10.0)
	create_two_stations()

	var stations = _game._get_stations()
	_game._try_create_train(stations[0], stations[1])
	var train: Train = get_tree().get_nodes_in_group("trains")[0]

	# Assert that the train is close to the other station
	assert_true(await wait_until(func(): return Vector2i(train.get_train_position().snapped(Global.TILE)) == Vector2i(32, 0), 10.0))
	assert_true(await wait_until(func(): return Vector2i(train.get_train_position().snapped(Global.TILE)) == Vector2i(-32, 0), 10.0))

func create_two_stations_length_3():
	Upgrades.upgrades[Upgrades.UpgradeType.PLATFORM_LENGTH].current_level = 3
	var station_dicts: Array[Dictionary] = [
	{"position": "(-64.0, 0.0)"},
	{"position": "(64.0, 0.0)"}
	]
	var track_dicts: Array[Dictionary] = [
	{"pos1": "(-48, 0)", "pos2": "(-32, 0)"},
	{"pos1": "(-32, 0)", "pos2": "(-16, 0)"},
	{"pos1": "(-16, 0)", "pos2": "(0, 0)"},
	{"pos1": "(0, 0)", "pos2": "(16, 0)"},
	{"pos1": "(16, 0)", "pos2": "(32, 0)"},
	{"pos1": "(32, 0)", "pos2": "(48, 0)"},
	]
	create(station_dicts, track_dicts)

func test_go_between_two_stations_of_length_3():
	Engine.set_time_scale(10.0)
	create_two_stations_length_3()

	var stations = _game._get_stations()
	_game._try_create_train(stations[0], stations[1])
	var train: Train = get_tree().get_nodes_in_group("trains")[0]

	# Assert that the train is close to the other station
	assert_true(await wait_until(func(): return Vector2i(train.get_train_position().snapped(Global.TILE)) == Vector2i(32, 0), 10.0))


func test_go_between_two_stations_of_length_3_and_back():
	Engine.set_time_scale(10.0)
	create_two_stations_length_3()

	var stations = _game._get_stations()
	_game._try_create_train(stations[0], stations[1])
	var train: Train = get_tree().get_nodes_in_group("trains")[0]

	# Assert that the train is close to the other station
	assert_true(await wait_until(func(): return Vector2i(train.get_train_position().snapped(Global.TILE)) == Vector2i(48, 0), 10.0))
	assert_true(await wait_until(func(): return Vector2i(train.get_train_position().snapped(Global.TILE)) == Vector2i(-48, 0), 10.0))


#      ╷
# S━━━─┴━━S
func test_go_from_length_3_station_to_length_2_station():
	Engine.set_time_scale(10.0)
	create_two_stations_length_3()
	create([], [ {"pos1": "(16, -16)", "pos2": "(16, 0)"}])

	var stations = _game._get_stations()
	_game._try_create_train(stations[0], stations[1])
	var train: Train = get_tree().get_nodes_in_group("trains")[0]

	# Assert that the train gets close to the other station
	assert_true(await wait_until(func(): return Vector2i(train.get_train_position().snapped(Global.TILE)) == Vector2i(48, 0), 10.0))
