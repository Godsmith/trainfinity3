extends Node2D

class_name Terrain

const CHUNK_WIDTH := 11

enum ChunkType {FACTORY, STEELWORKS, FOREST, CITY, EMPTY}

const FACTORY = preload("res://scenes/factory.tscn")
const STEELWORKS = preload("res://scenes/steelworks.tscn")
const GRASS = preload("res://scenes/grass.tscn")
const WATER = preload("res://scenes/water.tscn")
const SAND = preload("res://scenes/sand.tscn")
const WALL = preload("res://scenes/wall.tscn")
const FOREST = preload("res://scenes/forest.tscn")
const CITY = preload("res://scenes/city.tscn")

@export_range(-1.0, 1.0) var water_level: float = -0.2
@export_range(-1.0, 1.0) var sand_level: float = -0.1
@export_range(-1.0, 1.0) var mountain_level: float = 0.3
@export_range(0.0, 1.0) var ore_chance: float = 0.1
@export_range(0.0, 1.0) var iron_chance: float = 0.25
@export_range(0.0, 1.0) var coal_chance: float = 1.0 - iron_chance
@export_range(0, 100) var city_count: int = 5
@export_range(0, 100) var forest_count: int = 5

# When creating terrain, walls and water positions are recorded here,
# so that when building things later we can check this set to see
# where we cannot build. Using a Dictionary as a set, since there is
# no set in Godot.
# Untyped, since the keys are multiple types of classes and Godot does not
# have union types.
var obstacle_position_set: Dictionary = {}

# Forests spawn on grass
var _grass_positions: Array[Vector2i] = []

var _grid_positions: Array[Vector2i] = []
var _noise_from_position: Dictionary[Vector2i, float] = {}

@onready var noise := FastNoiseLite.new()
	
# Store every type of node under a separate node, since the Godot editor
# is very slow when it has to show all nodes at ones in the tree view
@onready var grass_node = Node.new()
@onready var water_node = Node.new()
@onready var sand_node = Node.new()
@onready var wall_node = Node.new()
@onready var forest_node = Node.new()
@onready var city_node = Node.new()

var boundaries = Rect2i()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# TODO: Consider checking so that factories etc are accessible 
	# - either no mountains or water around them, or not too much, or unbroken path
	#   from them to a corresponding consumer/producer
	print("Starting terrain generation")
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.seed = randi() # random terrain each run
	noise.frequency = 0.05

	add_child(grass_node)
	add_child(water_node)
	add_child(sand_node)
	add_child(wall_node)
	add_child(forest_node)
	add_child(city_node)

	add_chunk(-1, -1, ChunkType.CITY)
	add_chunk(0, -1, ChunkType.FOREST)
	add_chunk(1, -1, ChunkType.EMPTY)
	add_chunk(-1, 0, ChunkType.EMPTY)

	add_chunk(0, 0, ChunkType.STEELWORKS)

	add_chunk(1, 0, ChunkType.FACTORY)
	add_chunk(-1, 1, ChunkType.EMPTY)
	add_chunk(0, 1, ChunkType.FOREST)
	add_chunk(1, 1, ChunkType.CITY)


func add_chunk(chunk_x: int, chunk_y: int, chunk_type: ChunkType):
	_create_terrain(chunk_x, chunk_y)

	# TODO: New things are generated everywhere, not just in the new chunk
	match chunk_type:
		ChunkType.EMPTY:
			pass
		ChunkType.FACTORY:
			var factory = FACTORY.instantiate()
			factory.position = _grass_positions.pick_random()
			add_child(factory)
		ChunkType.STEELWORKS:
			var steelworks = STEELWORKS.instantiate()
			steelworks.position = _grass_positions.pick_random()
			add_child(steelworks)
		ChunkType.FOREST:
			var forest = FOREST.instantiate()
			forest.position = _grass_positions.pick_random()
			forest_node.add_child(forest)
		ChunkType.CITY:
			var possible_city_positions: Array[Vector2i] = []
			for pos in _grid_positions:
				if pos not in obstacle_position_set:
					possible_city_positions.append(pos)
			var city_position = possible_city_positions.pick_random()
			possible_city_positions.erase(city_position)
			var city = CITY.instantiate()
			city.position = city_position
			city_node.add_child(city)
			
			print("Starting city extension")
			var target_size = randi_range(3, 10)
			var current_size = 1
			var handled_city_positions := [city_position]
			var possible_new_city_positions = Global.orthogonally_adjacent(city_position)
			while current_size < target_size and possible_new_city_positions:
				var new_city_position = possible_new_city_positions.pick_random()
				possible_new_city_positions.erase(new_city_position)
				if new_city_position not in obstacle_position_set and new_city_position not in handled_city_positions and new_city_position in _grid_positions:
					current_size += 1
					handled_city_positions.append(new_city_position)
					possible_new_city_positions.append_array(Global.orthogonally_adjacent(new_city_position))
					var new_city = CITY.instantiate()
					new_city.position = new_city_position
					add_child(new_city)
			print("City extension done")


func _create_terrain(chunk_x: int, chunk_y: int):
	for x in range(chunk_x * CHUNK_WIDTH - (CHUNK_WIDTH - 1) / 2, chunk_x * CHUNK_WIDTH + (CHUNK_WIDTH - 1) / 2 + 1):
		for y in range(chunk_y * CHUNK_WIDTH - (CHUNK_WIDTH - 1) / 2, chunk_y * CHUNK_WIDTH + (CHUNK_WIDTH - 1) / 2 + 1):
			var grid_position = Vector2i(x, y) * Global.TILE_SIZE
			_grid_positions.append(grid_position)
			_noise_from_position[grid_position] = noise.get_noise_2d(x, y)
	var min_x = 0
	var max_x = 0
	var min_y = 0
	var max_y = 0
	for pos in _grid_positions:
		min_x = min(min_x, pos.x)
		max_x = max(max_x, pos.x)
		min_y = min(min_y, pos.y)
		max_y = max(max_y, pos.y)
	boundaries = Rect2i(min_x, min_y, max_x - min_x, max_y - min_y)
	for pos in _grid_positions:
		var noise_level = _noise_from_position[pos]
		if noise_level < water_level:
			var water = WATER.instantiate()
			var water_position = pos
			water.position = water_position
			obstacle_position_set[water_position] = water
			water_node.add_child(water)
		elif noise_level < sand_level:
			var sand = SAND.instantiate()
			sand.position = pos
			sand_node.add_child(sand)
		elif noise_level > mountain_level:
			# Show grass under mountain
			_grass_positions.append(pos)
			var grass = GRASS.instantiate()
			grass.position = pos
			grass_node.add_child(grass)

			var wall = WALL.instantiate()
			var wall_position = pos
			wall.position = wall_position
			obstacle_position_set[wall_position] = wall
			wall_node.add_child(wall)

			# maybe add ore inside this wall
			if randf() < ore_chance:
				var ore_type: Ore.OreType
				if randf() < iron_chance:
					ore_type = Ore.OreType.IRON
				else:
					ore_type = Ore.OreType.COAL
				var ore = Ore.create(ore_type)
				ore.position = Vector2.ZERO # relative to wall
				wall.add_child(ore)
		else:
			_grass_positions.append(pos)
			var grass = GRASS.instantiate()
			grass.position = pos
			grass_node.add_child(grass)

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
