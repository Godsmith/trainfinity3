extends BaseTest

# Unit tests for TrackCreator class, focusing on the track limit functionality
# and proper handling of existing tracks when creating ghost tracks

var _original_track_limit_upgrade: UpgradeManager.Upgrade

func before_each():
	super.before_each()
	# Save original upgrade objects
	_original_track_limit_upgrade = Upgrades.upgrades[Upgrades.UpgradeType.TRACK_LIMIT]

func after_each():
	# Restore original upgrade objects
	Upgrades.upgrades[Upgrades.UpgradeType.TRACK_LIMIT] = _original_track_limit_upgrade

func test_create_ghost_track_excludes_existing_tracks_from_limit():
	# Test that existing tracks don't count against the limit when creating ghost tracks
	await wait_idle_frames(1)
	
	# Set track limit to 5
	Upgrades.upgrades[Upgrades.UpgradeType.TRACK_LIMIT] = Upgrades.Upgrade.new("Track Limit", [5, 10, 15], [0, 100, 200])
	
	# Build 3 existing tracks
	create([], [
		{"pos1": "(0, 0)", "pos2": "(16, 0)"},
		{"pos1": "(16, 0)", "pos2": "(32, 0)"},
		{"pos1": "(32, 0)", "pos2": "(48, 0)"}
	])
	await wait_idle_frames(1)
	
	# Should have 2 tracks remaining (5 - 3)
	var remaining = Upgrades.get_remaining_assets(Global.Asset.TRACK)
	assert_eq(remaining, 2, "Should have 2 tracks remaining")
	
	# Create ghost tracks that overlap with existing tracks
	var ghost_track_positions: Array[Vector2i] = []
	ghost_track_positions.append(Vector2i(0, 0))
	ghost_track_positions.append(Vector2i(16, 0)) # Existing track
	ghost_track_positions.append(Vector2i(32, 0)) # Existing track
	ghost_track_positions.append(Vector2i(48, 0)) # Existing track
	ghost_track_positions.append(Vector2i(64, 0)) # New track 1
	ghost_track_positions.append(Vector2i(80, 0)) # New track 2
	
	var ghost_tracks = _game.track_creator.create_ghost_track(ghost_track_positions, _game.track_set)
	
	# Should create 5 ghost tracks total (3 existing + 2 new)
	assert_eq(len(ghost_tracks), 5, "Should have created 5 ghost tracks")
	
	# All tracks should be allowed (green) because only 2 new tracks are being added
	for track in ghost_tracks:
		assert_true(track.is_allowed, "All ghost tracks should be allowed since only 2 new tracks")
	
	# Clean up
	for track in ghost_tracks:
		track.queue_free()


func test_create_ghost_track_marks_excess_new_tracks_red():
	# Test that new tracks beyond the limit are marked as not allowed (red)
	await wait_idle_frames(1)
	
	# Set track limit to 5
	Upgrades.upgrades[Upgrades.UpgradeType.TRACK_LIMIT] = Upgrades.Upgrade.new("Track Limit", [5, 10, 15], [0, 100, 200])
	
	# Build 3 existing tracks
	create([], [
		{"pos1": "(0, 0)", "pos2": "(16, 0)"},
		{"pos1": "(16, 0)", "pos2": "(32, 0)"},
		{"pos1": "(32, 0)", "pos2": "(48, 0)"}
	])
	await wait_idle_frames(1)
	
	# Should have 2 tracks remaining
	var remaining = Upgrades.get_remaining_assets(Global.Asset.TRACK)
	assert_eq(remaining, 2, "Should have 2 tracks remaining")
	
	# Create ghost tracks: 3 existing + 4 new (but only 2 new allowed)
	var ghost_track_positions: Array[Vector2i] = []
	ghost_track_positions.append(Vector2i(0, 0))
	ghost_track_positions.append(Vector2i(16, 0)) # Existing
	ghost_track_positions.append(Vector2i(32, 0)) # Existing
	ghost_track_positions.append(Vector2i(48, 0)) # Existing
	ghost_track_positions.append(Vector2i(64, 0)) # New 1 - allowed
	ghost_track_positions.append(Vector2i(80, 0)) # New 2 - allowed
	ghost_track_positions.append(Vector2i(96, 0)) # New 3 - NOT allowed
	ghost_track_positions.append(Vector2i(112, 0)) # New 4 - NOT allowed
	
	var ghost_tracks = _game.track_creator.create_ghost_track(ghost_track_positions, _game.track_set)
	
	assert_eq(len(ghost_tracks), 7, "Should have created 7 ghost tracks")
	
	# First 5 tracks should be allowed (3 existing + 2 new within limit)
	for i in range(5):
		assert_true(ghost_tracks[i].is_allowed, "Track %d should be allowed" % i)
	
	# Last 2 tracks should NOT be allowed (exceed limit)
	assert_false(ghost_tracks[5].is_allowed, "Track 5 should not be allowed (exceeds limit)")
	assert_false(ghost_tracks[6].is_allowed, "Track 6 should not be allowed (exceeds limit)")
	
	# Clean up
	for track in ghost_tracks:
		track.queue_free()


func test_create_ghost_track_with_no_existing_tracks():
	# Test creating ghost tracks when no tracks exist yet
	await wait_idle_frames(1)
	
	# Set track limit to 3
	Upgrades.upgrades[Upgrades.UpgradeType.TRACK_LIMIT] = Upgrades.Upgrade.new("Track Limit", [3, 6, 9], [0, 100, 200])
	
	# Create ghost tracks with no existing tracks
	var ghost_track_positions: Array[Vector2i] = []
	ghost_track_positions.append(Vector2i(0, 0))
	ghost_track_positions.append(Vector2i(16, 0))
	ghost_track_positions.append(Vector2i(32, 0))
	ghost_track_positions.append(Vector2i(48, 0))
	ghost_track_positions.append(Vector2i(64, 0)) # 4 tracks total, limit is 3
	
	var ghost_tracks = _game.track_creator.create_ghost_track(ghost_track_positions, _game.track_set)
	
	assert_eq(len(ghost_tracks), 4, "Should have created 4 ghost tracks")
	
	# First 3 should be allowed
	for i in range(3):
		assert_true(ghost_tracks[i].is_allowed, "Track %d should be allowed" % i)
	
	# Last one should not be allowed
	assert_false(ghost_tracks[3].is_allowed, "Track 3 should not be allowed (exceeds limit)")
	
	# Clean up
	for track in ghost_tracks:
		track.queue_free()


func test_create_ghost_track_all_existing_tracks():
	# Test creating ghost tracks when all tracks already exist
	await wait_idle_frames(1)
	
	# Set track limit to 5
	Upgrades.upgrades[Upgrades.UpgradeType.TRACK_LIMIT] = Upgrades.Upgrade.new("Track Limit", [5, 10, 15], [0, 100, 200])
	
	# Build 5 tracks (at limit)
	create([], [
		{"pos1": "(0, 0)", "pos2": "(16, 0)"},
		{"pos1": "(16, 0)", "pos2": "(32, 0)"},
		{"pos1": "(32, 0)", "pos2": "(48, 0)"},
		{"pos1": "(48, 0)", "pos2": "(64, 0)"},
		{"pos1": "(64, 0)", "pos2": "(80, 0)"}
	])
	await wait_idle_frames(1)
	
	# Should have 0 tracks remaining
	var remaining = Upgrades.get_remaining_assets(Global.Asset.TRACK)
	assert_eq(remaining, 0, "Should have 0 tracks remaining")
	
	# Create ghost tracks that are all existing
	var ghost_track_positions: Array[Vector2i] = []
	ghost_track_positions.append(Vector2i(0, 0))
	ghost_track_positions.append(Vector2i(16, 0))
	ghost_track_positions.append(Vector2i(32, 0))
	ghost_track_positions.append(Vector2i(48, 0))
	
	var ghost_tracks = _game.track_creator.create_ghost_track(ghost_track_positions, _game.track_set)
	
	assert_eq(len(ghost_tracks), 3, "Should have created 3 ghost tracks")
	
	# All should be allowed because they already exist
	for track in ghost_tracks:
		assert_true(track.is_allowed, "Existing tracks should be allowed even at limit")
	
	# Clean up
	for track in ghost_tracks:
		track.queue_free()


func test_create_ghost_track_with_empty_track_set():
	# Test creating ghost tracks with an empty track_set (no existing tracks)
	await wait_idle_frames(1)
	
	# Set track limit to 2
	Upgrades.upgrades[Upgrades.UpgradeType.TRACK_LIMIT] = Upgrades.Upgrade.new("Track Limit", [2, 4, 6], [0, 100, 200])
	
	# Create an empty track set
	var empty_track_set = TrackSet.new()
	
	# Create ghost tracks with empty track_set (all will be treated as new)
	var ghost_track_positions: Array[Vector2i] = []
	ghost_track_positions.append(Vector2i(0, 0))
	ghost_track_positions.append(Vector2i(16, 0)) # New 1
	ghost_track_positions.append(Vector2i(32, 0)) # New 2
	ghost_track_positions.append(Vector2i(48, 0)) # New 3 - exceeds limit
	
	var ghost_tracks = _game.track_creator.create_ghost_track(ghost_track_positions, empty_track_set)
	
	assert_eq(len(ghost_tracks), 3, "Should have created 3 ghost tracks")
	
	# First 2 should be allowed
	assert_true(ghost_tracks[0].is_allowed, "First track should be allowed")
	assert_true(ghost_tracks[1].is_allowed, "Second track should be allowed")
	
	# Last one should not be allowed (exceeds limit)
	assert_false(ghost_tracks[2].is_allowed, "Third track should not be allowed (exceeds limit)")
	
	# Clean up
	for track in ghost_tracks:
		track.queue_free()


func test_click_checks_new_track_count_before_building():
	# Test that click() properly counts only new tracks when checking limit
	await wait_idle_frames(1)
	
	# Set track limit to 5
	Upgrades.upgrades[Upgrades.UpgradeType.TRACK_LIMIT] = Upgrades.Upgrade.new("Track Limit", [5, 10, 15], [0, 100, 200])
	
	# Build 4 existing tracks
	create([], [
		{"pos1": "(0, 0)", "pos2": "(16, 0)"},
		{"pos1": "(16, 0)", "pos2": "(32, 0)"},
		{"pos1": "(32, 0)", "pos2": "(48, 0)"},
		{"pos1": "(48, 0)", "pos2": "(64, 0)"}
	])
	await wait_idle_frames(1)
	
	# Should have 1 track remaining
	var remaining = Upgrades.get_remaining_assets(Global.Asset.TRACK)
	assert_eq(remaining, 1, "Should have 1 track remaining")
	
	# Start track building mode
	var astar_terrain = _game._create_astar_terrain()
	_game.track_creator.click(Vector2i(0, 0), _game.track_set)
	
	# Move to create ghost tracks (3 existing + 1 new)
	var ghost_tracks = _game.track_creator.mouse_move(Vector2i(64, 0), astar_terrain, _game.track_set)
	
	# Click to confirm - should succeed because only 1 new track
	var result = _game.track_creator.click(Vector2i(64, 0), _game.track_set)
	
	# Should return the confirm position (not Vector2i.MAX)
	assert_ne(result, Vector2i.MAX, "Should return confirm position when within limit")
	
	# Clean up
	for track in ghost_tracks:
		if is_instance_valid(track):
			track.queue_free()


func test_click_prevents_building_when_exceeding_limit():
	# Test that click() prevents building when new tracks exceed limit
	await wait_idle_frames(1)
	
	# Set track limit to 3
	Upgrades.upgrades[Upgrades.UpgradeType.TRACK_LIMIT] = Upgrades.Upgrade.new("Track Limit", [3, 6, 9], [0, 100, 200])
	
	# Build 2 existing tracks
	create([], [
		{"pos1": "(0, 0)", "pos2": "(16, 0)"},
		{"pos1": "(16, 0)", "pos2": "(32, 0)"}
	])
	await wait_idle_frames(1)
	
	# Should have 1 track remaining
	var remaining = Upgrades.get_remaining_assets(Global.Asset.TRACK)
	assert_eq(remaining, 1, "Should have 1 track remaining")
	
	# Start track building mode
	var astar_terrain = _game._create_astar_terrain()
	_game.track_creator.click(Vector2i(32, 0), _game.track_set)
	
	# Move to create ghost tracks that would add 2 new tracks (exceeds limit)
	var ghost_tracks = _game.track_creator.mouse_move(Vector2i(64, 0), astar_terrain, _game.track_set)
	
	# Try to click to confirm - should fail because 2 new tracks exceed limit of 1
	var initial_track_count = _game.track_set.get_all_tracks().size()
	_game.track_creator.click(Vector2i(64, 0), _game.track_set)
	
	# Track count should not have increased (building was prevented)
	var final_track_count = _game.track_set.get_all_tracks().size()
	assert_eq(initial_track_count, final_track_count, "Track count should not increase when exceeding limit")
	
	# Clean up
	for track in ghost_tracks:
		if is_instance_valid(track):
			track.queue_free()
