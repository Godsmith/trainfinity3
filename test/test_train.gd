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
