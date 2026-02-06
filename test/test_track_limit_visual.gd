extends BaseTest

func test_ghost_tracks_turn_red_when_exceeding_limit():
	# Set track limit to a low number for testing
	await wait_idle_frames(1)
	
	# Set limit to base level (20 tracks)
	var track_upgrade = Upgrades.upgrades[Upgrades.UpgradeType.TRACK_LIMIT]
	track_upgrade.current_level = 0
	
	# Build some tracks to reduce available limit to 2
	create([], [
		{"pos1": "(-80, 0)", "pos2": "(-64, 0)"},
		{"pos1": "(-64, 0)", "pos2": "(-48, 0)"},
		{"pos1": "(-48, 0)", "pos2": "(-32, 0)"},
		{"pos1": "(-32, 0)", "pos2": "(-16, 0)"},
		{"pos1": "(-16, 0)", "pos2": "(0, 0)"},
		{"pos1": "(0, 0)", "pos2": "(16, 0)"},
		{"pos1": "(16, 0)", "pos2": "(32, 0)"},
		{"pos1": "(32, 0)", "pos2": "(48, 0)"},
		{"pos1": "(48, 0)", "pos2": "(64, 0)"},
		{"pos1": "(64, 0)", "pos2": "(80, 0)"},
		{"pos1": "(-80, 16)", "pos2": "(-64, 16)"},
		{"pos1": "(-64, 16)", "pos2": "(-48, 16)"},
		{"pos1": "(-48, 16)", "pos2": "(-32, 16)"},
		{"pos1": "(-32, 16)", "pos2": "(-16, 16)"},
		{"pos1": "(-16, 16)", "pos2": "(0, 16)"},
		{"pos1": "(0, 16)", "pos2": "(16, 16)"},
		{"pos1": "(16, 16)", "pos2": "(32, 16)"},
		{"pos1": "(32, 16)", "pos2": "(48, 16)"}
	])
	await wait_idle_frames(1)
	
	# Now we have 18 tracks built, 2 remaining in limit
	var remaining = Upgrades.get_remaining_assets(Global.Asset.TRACK)
	assert_eq(remaining, 2, "Should have 2 tracks remaining")
	
	# Create ghost tracks that exceed limit
	var ghost_track_positions: Array[Vector2i] = []
	ghost_track_positions.append(Vector2i(48, 16))
	ghost_track_positions.append(Vector2i(64, 16))
	ghost_track_positions.append(Vector2i(80, 16))
	ghost_track_positions.append(Vector2i(80, 32))
	ghost_track_positions.append(Vector2i(80, 48)) # 4 ghost tracks total, but only 2 can be built
	
	var ghost_tracks = _game.track_creator.create_ghost_track(ghost_track_positions, _game.track_set)
	
	# Verify we created 4 ghost tracks
	assert_eq(len(ghost_tracks), 4, "Should have created 4 ghost tracks")
	
	# First 2 tracks should be allowed (green/white)
	assert_true(ghost_tracks[0].is_allowed, "First ghost track should be allowed")
	assert_true(ghost_tracks[1].is_allowed, "Second ghost track should be allowed")
	
	# Last 2 tracks should not be allowed (red)
	assert_false(ghost_tracks[2].is_allowed, "Third ghost track should not be allowed (exceeds limit)")
	assert_false(ghost_tracks[3].is_allowed, "Fourth ghost track should not be allowed (exceeds limit)")
	
	# Clean up ghost tracks
	for track in ghost_tracks:
		track.queue_free()


func test_ghost_tracks_all_green_when_within_limit():
	# Test that all ghost tracks are green when within limit
	await wait_idle_frames(1)
	
	# Build just a few tracks
	create([], [
		{"pos1": "(0, 0)", "pos2": "(16, 0)"},
		{"pos1": "(16, 0)", "pos2": "(32, 0)"}
	])
	await wait_idle_frames(1)
	
	# Should have 18 tracks remaining (20 - 2)
	var remaining = Upgrades.get_remaining_assets(Global.Asset.TRACK)
	assert_eq(remaining, 18, "Should have 18 tracks remaining")
	
	# Create ghost tracks well within limit
	var ghost_track_positions: Array[Vector2i] = []
	ghost_track_positions.append(Vector2i(32, 0))
	ghost_track_positions.append(Vector2i(48, 0))
	ghost_track_positions.append(Vector2i(64, 0))
	ghost_track_positions.append(Vector2i(80, 0))
	
	var ghost_tracks = _game.track_creator.create_ghost_track(ghost_track_positions, _game.track_set)
	
	# All tracks should be allowed
	for track in ghost_tracks:
		assert_true(track.is_allowed, "Ghost track should be allowed when within limit")
	
	# Clean up ghost tracks
	for track in ghost_tracks:
		track.queue_free()


func test_ghost_tracks_red_when_at_limit():
	# Test that ghost tracks are red when already at limit
	await wait_idle_frames(1)
	
	# Build tracks to reach limit (20 tracks)
	create([], [
		{"pos1": "(-80, 0)", "pos2": "(-64, 0)"},
		{"pos1": "(-64, 0)", "pos2": "(-48, 0)"},
		{"pos1": "(-48, 0)", "pos2": "(-32, 0)"},
		{"pos1": "(-32, 0)", "pos2": "(-16, 0)"},
		{"pos1": "(-16, 0)", "pos2": "(0, 0)"},
		{"pos1": "(0, 0)", "pos2": "(16, 0)"},
		{"pos1": "(16, 0)", "pos2": "(32, 0)"},
		{"pos1": "(32, 0)", "pos2": "(48, 0)"},
		{"pos1": "(48, 0)", "pos2": "(64, 0)"},
		{"pos1": "(64, 0)", "pos2": "(80, 0)"},
		{"pos1": "(-80, 16)", "pos2": "(-64, 16)"},
		{"pos1": "(-64, 16)", "pos2": "(-48, 16)"},
		{"pos1": "(-48, 16)", "pos2": "(-32, 16)"},
		{"pos1": "(-32, 16)", "pos2": "(-16, 16)"},
		{"pos1": "(-16, 16)", "pos2": "(0, 16)"},
		{"pos1": "(0, 16)", "pos2": "(16, 16)"},
		{"pos1": "(16, 16)", "pos2": "(32, 16)"},
		{"pos1": "(32, 16)", "pos2": "(48, 16)"},
		{"pos1": "(48, 16)", "pos2": "(64, 16)"},
		{"pos1": "(64, 16)", "pos2": "(80, 16)"}
	])
	await wait_idle_frames(1)
	
	# Should have 0 tracks remaining
	var remaining = Upgrades.get_remaining_assets(Global.Asset.TRACK)
	assert_eq(remaining, 0, "Should have 0 tracks remaining")
	
	# Try to create ghost tracks
	var ghost_track_positions: Array[Vector2i] = []
	ghost_track_positions.append(Vector2i(80, 16))
	ghost_track_positions.append(Vector2i(80, 32))
	ghost_track_positions.append(Vector2i(80, 48))
	
	var ghost_tracks = _game.track_creator.create_ghost_track(ghost_track_positions, _game.track_set)
	
	# All tracks should not be allowed (red)
	for track in ghost_tracks:
		assert_false(track.is_allowed, "Ghost track should not be allowed when at limit")
	
	# Clean up ghost tracks
	for track in ghost_tracks:
		track.queue_free()
