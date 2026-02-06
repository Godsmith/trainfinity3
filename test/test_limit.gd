extends BaseTest

func test_gui_shows_initial_station_limit():
	# When starting a new game, the GUI should show "Station (2)"
	# since the initial limit is 2 stations and 0 are built
	await wait_idle_frames(1)
	
	var gui: Gui = _game.gui
	assert_string_contains(gui.station_button.text, "Station (2)")


func test_gui_shows_initial_track_limit():
	# When starting a new game, the GUI should show "Track (20)"
	# since the initial limit is 20 tracks and 0 are built
	await wait_idle_frames(1)
	
	var gui: Gui = _game.gui
	assert_string_contains(gui.track_button.text, "Track (20)")


func test_gui_shows_initial_train_limit():
	# When starting a new game, the GUI should show "Train (1)"
	# since the initial limit is 1 train and 0 are built
	await wait_idle_frames(1)
	
	var gui: Gui = _game.gui
	assert_string_contains(gui.train_button.text, "Train (1)")


func test_gui_updates_after_building_station():
	# After building one station, GUI should show "Station (1)"
	await wait_idle_frames(1)
	
	create([ {"position": "(0, 0)"}], [])
	await wait_idle_frames(2)
	
	var gui: Gui = _game.gui
	var station_count = get_tree().get_node_count_in_group("stations")
	assert_eq(station_count, 1, "Should have 1 station")
	assert_string_contains(gui.station_button.text, "Station (1)")


func test_gui_updates_after_building_tracks():
	# After building tracks, GUI should show reduced limit
	await wait_idle_frames(1)
	
	create([], [
		{"pos1": "(0, 0)", "pos2": "(16, 0)"},
		{"pos1": "(16, 0)", "pos2": "(32, 0)"},
		{"pos1": "(32, 0)", "pos2": "(48, 0)"},
		{"pos1": "(48, 0)", "pos2": "(64, 0)"}
	])
	await wait_idle_frames(1)
	
	var gui: Gui = _game.gui
	var track_count = get_tree().get_node_count_in_group("track")
	var expected_remaining = 20 - track_count
	assert_string_contains(gui.track_button.text, "Track (%d)" % expected_remaining)


func test_station_button_disabled_at_limit():
	# When at limit, the station button should be disabled
	await wait_idle_frames(1)
	
	# Build 2 stations to reach limit
	create([
		{"position": "(0, 0)"},
		{"position": "(64, 0)"}
	], [])
	await wait_idle_frames(1)
	
	var gui: Gui = _game.gui
	assert_true(gui.station_button.disabled, "Station button should be disabled at limit")
	assert_string_contains(gui.station_button.text, "Station (0)")


func test_limit_increases_after_upgrade():
	# After purchasing a limit upgrade, the GUI should reflect the new limit
	await wait_idle_frames(1)
	
	# Purchase station limit upgrade
	var station_upgrade = Upgrades.upgrades[Upgrades.UpgradeType.STATION_LIMIT]
	GlobalBank.spend_money(station_upgrade.get_next_cost(), Vector2.ZERO)
	station_upgrade.upgrade()
	
	await wait_idle_frames(1)
	
	var gui: Gui = _game.gui
	# Should now show 4 stations available (upgraded from 2 to 4)
	assert_string_contains(gui.station_button.text, "Station (4)")


func test_gui_updates_after_deleting_station():
	# Build a station, then delete it, and verify GUI updates
	await wait_idle_frames(1)
	
	# Build a station
	create([ {"position": "(0, 0)"}], [])
	await wait_idle_frames(1)
	
	# Verify it was built
	assert_eq(get_tree().get_node_count_in_group("stations"), 1)
	assert_string_contains(_game.gui.station_button.text, "Station (1)")
	
	# Delete the station
	_game._destroy_stations([Vector2i(0, 0)])
	await wait_idle_frames(1)
	
	# Verify GUI updated back to 2
	assert_eq(get_tree().get_node_count_in_group("stations"), 0)
	assert_string_contains(_game.gui.station_button.text, "Station (2)")


func test_gui_updates_after_deleting_tracks():
	# Build tracks, then delete them, and verify GUI updates
	await wait_idle_frames(1)
	
	# Build tracks
	create([], [
		{"pos1": "(0, 0)", "pos2": "(16, 0)"},
		{"pos1": "(16, 0)", "pos2": "(32, 0)"},
		{"pos1": "(32, 0)", "pos2": "(48, 0)"},
		{"pos1": "(48, 0)", "pos2": "(64, 0)"}
	])
	await wait_idle_frames(1)
	
	var initial_track_count = get_tree().get_node_count_in_group("track")
	assert_gt(initial_track_count, 0, "Should have built some tracks")
	
	# Delete some tracks
	_game._destroy_track([Vector2i(16, 0), Vector2i(32, 0)])
	await wait_idle_frames(1)
	
	# Verify tracks were deleted and GUI updated
	var final_track_count = get_tree().get_node_count_in_group("track")
	assert_lt(final_track_count, initial_track_count, "Some tracks should have been deleted")
	var expected_remaining = 20 - final_track_count
	assert_string_contains(_game.gui.track_button.text, "Track (%d)" % expected_remaining)


func test_gui_updates_after_deleting_train():
	# Build a train, then delete it, and verify GUI updates
	await wait_idle_frames(1)
	
	# Build track and stations
	create([
		{"position": "(-48, 0)"},
		{"position": "(48, 0)"}
	], [
		{"pos1": "(-32, 0)", "pos2": "(-16, 0)"},
		{"pos1": "(-16, 0)", "pos2": "(0, 0)"},
		{"pos1": "(0, 0)", "pos2": "(16, 0)"},
		{"pos1": "(16, 0)", "pos2": "(32, 0)"}
	])
	await wait_idle_frames(1)
	
	# Build a train
	var stations = _game._get_stations()
	_game._try_create_train(stations[0], stations[1])
	await wait_idle_frames(1)
	
	# Verify train was built
	assert_eq(get_tree().get_node_count_in_group("trains"), 1)
	assert_string_contains(_game.gui.train_button.text, "Train (0)")
	
	# Delete the train
	var train = get_tree().get_nodes_in_group("trains")[0]
	_game.track_reservations.clear_reservations(train)
	train.queue_free()
	train.get_parent().remove_child(train)
	GlobalBank.destroy(Global.Asset.TRAIN)
	_game.gui.update_limit_display()
	await wait_idle_frames(1)
	
	# Verify GUI updated back to 1
	assert_eq(get_tree().get_node_count_in_group("trains"), 0)
	assert_string_contains(_game.gui.train_button.text, "Train (1)")


func test_station_button_enabled_after_deleting_at_limit():
	# Build to limit, verify button disabled, delete one, verify button enabled
	await wait_idle_frames(1)
	
	# Build 2 stations to reach limit
	create([
		{"position": "(0, 0)"},
		{"position": "(64, 0)"}
	], [])
	await wait_idle_frames(1)
	
	# Verify at limit and button disabled
	assert_true(_game.gui.station_button.disabled, "Station button should be disabled at limit")
	assert_string_contains(_game.gui.station_button.text, "Station (0)")
	
	# Delete one station
	_game._destroy_stations([Vector2i(0, 0)])
	await wait_idle_frames(1)
	
	# Verify button is now enabled
	assert_false(_game.gui.station_button.disabled, "Station button should be enabled after deleting")
	assert_string_contains(_game.gui.station_button.text, "Station (1)")
