extends BaseTest


func test_hovering_in_station_mode_creates_ghost_platform_tiles():
	_sender.key_down(KEY_1) # Switch to track mode
	_sender.mouse_left_click_at(Vector2i(200, 200))
	_sender.mouse_motion(Vector2i(400, 200))
	_sender.mouse_left_click_at(Vector2i(400, 200))
	_sender.mouse_motion(Vector2i(400, 200))
	_sender.mouse_left_click_at(Vector2i(400, 200))
	_sender.key_down(KEY_3) # Switch to station mode
	_sender.mouse_motion(Vector2i(150, 200))
	await _sender.idle

	assert_eq(get_tree().get_node_count_in_group("platforms"), 2)
