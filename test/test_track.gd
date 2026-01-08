extends BaseTest


func test_create_track():
	_sender.key_down(KEY_1) # Switch to track mode
	_sender.mouse_left_click_at(Vector2i(200, 200))
	_sender.mouse_motion(Vector2i(400, 200))
	_sender.mouse_left_click_at(Vector2i(400, 200))
	_sender.mouse_motion(Vector2i(400, 200))
	_sender.mouse_left_click_at(Vector2i(400, 200))
	await _sender.idle

	assert_eq(len(_game.track_set.get_all_tracks()), 4)


func test_show_ghost_track_before_building():
	_sender.key_down(KEY_1) # Switch to track mode
	_sender.mouse_left_click_at(Vector2(200, 200))
	_sender.mouse_motion(Vector2(400, 200))
	await _sender.idle

	assert_eq(get_tree().get_node_count_in_group("track"), 4)
	for track in get_tree().get_nodes_in_group("track"):
		assert_true(track.is_ghostly)


func test_hovered_over_ghost_track_is_red():
	_sender.key_down(KEY_1) # Switch to track mode
	_sender.mouse_left_click_at(Vector2(200, 200))
	_sender.mouse_motion(Vector2(400, 200))
	_sender.mouse_left_click_at(Vector2(400, 200)) # Construct a length of ghost track
	_sender.mouse_motion(Vector2(300, 200))
	await _sender.idle
	await wait_idle_frames(1) # Wait for queue_free()

	var allow_count := 0
	for track in get_tree().get_nodes_in_group("track"):
		if track.is_allowed:
			allow_count += 1
	assert_eq(allow_count, 2)


func test_undo_ghost_track_removes_red_rail_immediately():
	_sender.key_down(KEY_1) # Switch to track mode
	_sender.mouse_left_click_at(Vector2(200, 200))
	_sender.mouse_motion(Vector2(400, 200))
	_sender.mouse_left_click_at(Vector2(400, 200)) # Construct a length of ghost track
	_sender.mouse_motion(Vector2(300, 200))
	_sender.mouse_left_click_at(Vector2(300, 200)) # Click halfway back, to remove half of the ghost track
	await _sender.idle

	assert_eq(get_tree().get_node_count_in_group("track"), 2)
