extends Node2D

const HALF_GRID_SIZE := 32
const CITY_COUNT := 5

const FACTORY = preload("res://scenes/factory.tscn")
const WATER = preload("res://scenes/water.tscn")
const SAND = preload("res://scenes/sand.tscn")
const WALL = preload("res://scenes/wall.tscn")
const ORE = preload("res://scenes/ore.tscn")
const CITY = preload("res://scenes/city.tscn")

@export_range(-1.0, 1.0) var water_level: float = -0.2
@export_range(-1.0, 1.0) var sand_level: float = -0.1
@export_range(-1.0, 1.0) var mountain_level: float = 0.3
@export_range(0.0, 1.0) var ore_chance: float = 0.1

# When creating terrain, walls and water positions are recorded here,
# so that when building things later we can check this set to see
# where we cannot build. Using a Dictionary as a set, since there is
# no set in Godot.
# Untyped, since the keys are multiple types of classes and Godot does not
# have union types.
var obstacle_position_set: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("Starting terrain generation")
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.seed = randi() # random terrain each run
	noise.frequency = 0.05

	var factory = FACTORY.instantiate()
	factory.position = Vector2(0, 0)
	add_child(factory)

	var grid_positions: Array[Vector2i] = []
	var noise_from_position: Dictionary[Vector2i, float] = {}
	
	for x in range(-HALF_GRID_SIZE, HALF_GRID_SIZE):
		for y in range(-HALF_GRID_SIZE, HALF_GRID_SIZE):
			if x >= -1 and x <= 1 and y >= -1 and y <= 1:
				# Do not place around starting factory
				continue
			var grid_position = Vector2i(x, y) * Global.TILE_SIZE
			grid_positions.append(grid_position)
			noise_from_position[grid_position] = noise.get_noise_2d(x, y)
	for pos in grid_positions:
		var noise_level = noise_from_position[pos]
		if noise_level < water_level:
			var water = WATER.instantiate()
			var water_position = pos
			water.position = water_position
			obstacle_position_set[water_position] = water
			add_child(water)
		elif noise_level < sand_level:
			var sand = SAND.instantiate()
			sand.position = pos
			add_child(sand)
		elif noise_level > mountain_level:
			var wall = WALL.instantiate()
			var wall_position = pos
			wall.position = wall_position
			obstacle_position_set[wall_position] = wall
			add_child(wall)

			# maybe add ore inside this wall
			if randf() < ore_chance:
				var ore = ORE.instantiate()
				ore.position = Vector2.ZERO # relative to wall
				wall.add_child(ore)

	# Make walls look nicer
	for pos in obstacle_position_set.keys():
		var wall = obstacle_position_set[pos]
		if not wall is Wall:
			continue
		
		var west_of = pos + Vector2i(-Global.TILE_SIZE, 0)
		var east_of = pos + Vector2i(Global.TILE_SIZE, 0)
		var north_of = pos + Vector2i(0, -Global.TILE_SIZE)
		var south_of = pos + Vector2i(0, Global.TILE_SIZE)


		if not west_of in obstacle_position_set or obstacle_position_set[west_of] is not Wall:
			wall.get_node("West").visible = false
		if not east_of in obstacle_position_set or obstacle_position_set[east_of] is not Wall:
			wall.get_node("East").visible = false
		if not south_of in obstacle_position_set or obstacle_position_set[south_of] is not Wall:
			wall.get_node("South").visible = false
		if not north_of in obstacle_position_set or obstacle_position_set[north_of] is not Wall:
			wall.get_node("North").visible = false
	
	# Add cities
	var possible_city_positions: Array[Vector2i] = []
	for pos in grid_positions:
		if pos not in obstacle_position_set:
			possible_city_positions.append(pos)
	var city_positions = []
	for i in CITY_COUNT:
		var city_position = possible_city_positions.pick_random()
		possible_city_positions.erase(city_position)
		var city = CITY.instantiate()
		city_positions.append(city_position)
		city.position = city_position
		add_child(city)
	
	print("Starting city extension")
	for original_city_position in city_positions:
		var target_size = randi_range(1, 10)
		var current_size = 1
		var handled_city_positions := [original_city_position]
		var possible_new_city_positions = Global.orthogonally_adjacent(original_city_position)
		while current_size < target_size and possible_new_city_positions:
			var new_city_position = possible_new_city_positions.pick_random()
			if new_city_position not in obstacle_position_set and new_city_position not in handled_city_positions and new_city_position in grid_positions:
				current_size += 1
				handled_city_positions.append(new_city_position)
				possible_new_city_positions.append_array(Global.orthogonally_adjacent(new_city_position))
				var city = CITY.instantiate()
				city.position = new_city_position
				add_child(city)
	print("City extension done")
