extends Node2D

class_name Terrain

const CHUNK_WIDTH := 11

enum ChunkType {COAL, IRON, FACTORY, STEELWORKS, FOREST, CITY, EMPTY}

const FACTORY = preload("res://scenes/industry/factory.tscn")
const STEELWORKS = preload("res://scenes/industry/steelworks.tscn")
const GRASS = preload("res://scenes/terrain/grass.tscn")
const WATER = preload("res://scenes/terrain/water.tscn")
const SAND = preload("res://scenes/terrain/sand.tscn")
const WALL = preload("res://scenes/terrain/wall.tscn")
const FOREST = preload("res://scenes/industry/forest.tscn")
const CITY = preload("res://scenes/industry/city.tscn")

@export_range(-1.0, 1.0) var water_level: float = -0.2
@export_range(-1.0, 1.0) var sand_level: float = -0.1
@export_range(-1.0, 1.0) var mountain_level: float = 0.3

# When creating terrain, walls and water positions are recorded here,
# so that when building things later we can check this set to see
# where we cannot build. Using a Dictionary as a set, since there is
# no set in Godot.
# Untyped, since the keys are multiple types of classes and Godot does not
# have union types.
var obstacle_position_set: Dictionary = {}

var _chunk_positions: Array[Vector2i] = []
var _button_from_chunk_position: Dictionary[Vector2i, ExpandButton] = {}

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

class TerrainChunk:
	var buildable_positions: Array[Vector2i] = []
	var exterior_wall_positions: Array[Vector2i] = []

class ExpandButton:
	extends Button

	var cost: int

	func _init(cost_: int):
		cost = cost_
		text = "Expand ($%s)" % cost
		disabled = GlobalBank.money < cost


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

	_add_starting_chunks()

	GlobalBank.money_changed.connect(_on_money_changed)
	# Disable buttons
	_on_money_changed()

func _add_starting_chunks():
	# CITY  FOREST      COAL
	# COAL  STEELWORKS  FACTORY
	# IRON  FOREST
	add_chunk(-1, -1, ChunkType.CITY)
	add_chunk(0, -1, ChunkType.FOREST)
	add_chunk(1, -1, ChunkType.COAL)
	add_chunk(-1, 0, ChunkType.COAL)

	add_chunk(0, 0, ChunkType.STEELWORKS)

	add_chunk(1, 0, ChunkType.FACTORY)
	add_chunk(-1, 1, ChunkType.IRON)
	add_chunk(0, 1, ChunkType.FOREST)
	add_chunk(1, 1, ChunkType.CITY)


func add_chunk(chunk_x: int, chunk_y: int, chunk_type: ChunkType):
	update_buttons(chunk_x, chunk_y)
	var grid_positions: Array[Vector2i] = []
	var noise_from_position: Dictionary[Vector2i, float] = {}
	for x in range(chunk_x * CHUNK_WIDTH - (CHUNK_WIDTH - 1) / 2, chunk_x * CHUNK_WIDTH + (CHUNK_WIDTH - 1) / 2 + 1):
		for y in range(chunk_y * CHUNK_WIDTH - (CHUNK_WIDTH - 1) / 2, chunk_y * CHUNK_WIDTH + (CHUNK_WIDTH - 1) / 2 + 1):
			var grid_position = Vector2i(x, y) * Global.TILE_SIZE
			grid_positions.append(grid_position)
			noise_from_position[grid_position] = noise.get_noise_2d(x, y)
	var terrain_chunk = _create_terrain(grid_positions, noise_from_position)

	match chunk_type:
		ChunkType.EMPTY:
			pass
		ChunkType.COAL:
			if terrain_chunk.exterior_wall_positions:
				var ore = Ore.create(Global.ResourceType.COAL)
				ore.position = terrain_chunk.exterior_wall_positions.pick_random()
				add_child(ore)
		ChunkType.IRON:
			if terrain_chunk.exterior_wall_positions:
				var ore = Ore.create(Global.ResourceType.IRON)
				ore.position = terrain_chunk.exterior_wall_positions.pick_random()
				add_child(ore)
		ChunkType.FACTORY:
			var factory = FACTORY.instantiate()
			factory.position = terrain_chunk.buildable_positions.pick_random()
			add_child(factory)
		ChunkType.STEELWORKS:
			var steelworks = STEELWORKS.instantiate()
			steelworks.position = terrain_chunk.buildable_positions.pick_random()
			add_child(steelworks)
		ChunkType.FOREST:
			var forest = FOREST.instantiate()
			forest.position = terrain_chunk.buildable_positions.pick_random()
			forest_node.add_child(forest)
		ChunkType.CITY:
			var possible_city_positions: Array[Vector2i] = []
			for pos in grid_positions:
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
				if new_city_position not in obstacle_position_set and new_city_position not in handled_city_positions and new_city_position in grid_positions:
					current_size += 1
					handled_city_positions.append(new_city_position)
					possible_new_city_positions.append_array(Global.orthogonally_adjacent(new_city_position))
					var new_city = CITY.instantiate()
					new_city.position = new_city_position
					add_child(new_city)
			print("City extension done")


func update_buttons(chunk_x: int, chunk_y: int):
	var button_chunk_position = Vector2i(chunk_x, chunk_y)
	if button_chunk_position in _button_from_chunk_position:
		_button_from_chunk_position[button_chunk_position].queue_free()
		_button_from_chunk_position.erase(button_chunk_position)
	_chunk_positions.append(button_chunk_position)
	for new_button_chunk_position in [Vector2i(chunk_x - 1, chunk_y),
								  Vector2i(chunk_x + 1, chunk_y),
								  Vector2i(chunk_x, chunk_y - 1),
								  Vector2i(chunk_x, chunk_y + 1)]:
		if new_button_chunk_position in _chunk_positions:
			continue
		if new_button_chunk_position in _button_from_chunk_position:
			continue

		var button_position = Vector2(new_button_chunk_position.x * CHUNK_WIDTH * Global.TILE_SIZE,
							   new_button_chunk_position.y * CHUNK_WIDTH * Global.TILE_SIZE)

		var button = ExpandButton.new(2 ** (abs(chunk_x) + abs(chunk_y)) * 100)
		button.scale = Vector2(0.4, 0.4)
		button.position = button_position
		var chunk_type = ChunkType.values().pick_random()
		button.pressed.connect(_expand_button_clicked.bind(button, new_button_chunk_position.x, new_button_chunk_position.y, chunk_type))
		_button_from_chunk_position[new_button_chunk_position] = button
		add_child(button)

func _expand_button_clicked(button: ExpandButton, chunk_x: int, chunk_y: int, chunk_type: ChunkType):
	GlobalBank.spend_money(button.cost, button.global_position)
	add_chunk(chunk_x, chunk_y, chunk_type)


func _create_terrain(grid_positions: Array[Vector2i], noise_from_position: Dictionary[Vector2i, float]) -> TerrainChunk:
	# TODO: split into generating the terrain and actually creating the objects
	# to be able to load terrain from save game
	# TODO: consider just using obstacle_position_set instead of buildable_positions
	var terrain_chunk = TerrainChunk.new()
	var wall_positions: Array[Vector2i] = []
	for pos in grid_positions:
		var new_position = Vector2i(min(boundaries.position.x, pos.x),
									min(boundaries.position.y, pos.y))
		var new_end = Vector2i(max(boundaries.end.x, pos.x),
							   max(boundaries.end.y, pos.y))
		boundaries.position = new_position
		boundaries.end = new_end

		var noise_level = noise_from_position[pos]
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
			var grass = GRASS.instantiate()
			grass.position = pos
			grass_node.add_child(grass)

			var wall = WALL.instantiate()
			var wall_position = pos
			wall.position = wall_position
			obstacle_position_set[wall_position] = wall
			wall_node.add_child(wall)
			wall_positions.append(pos)
		else:
			terrain_chunk.buildable_positions.append(pos)
			var grass = GRASS.instantiate()
			grass.position = pos
			grass_node.add_child(grass)

	# Make walls look nicer 
	for pos in wall_positions:
		var wall = obstacle_position_set[pos]
		
		var is_no_wall_to_the_west = not _west_of(pos) in obstacle_position_set or obstacle_position_set[_west_of(pos)] is not Wall
		var is_no_wall_to_the_east = not _east_of(pos) in obstacle_position_set or obstacle_position_set[_east_of(pos)] is not Wall
		var is_no_wall_to_the_north = not _north_of(pos) in obstacle_position_set or obstacle_position_set[_north_of(pos)] is not Wall
		var is_no_wall_to_the_south = not _south_of(pos) in obstacle_position_set or obstacle_position_set[_south_of(pos)] is not Wall

		if is_no_wall_to_the_west:
			wall.get_node("West").visible = false
		if is_no_wall_to_the_east:
			wall.get_node("East").visible = false
		if is_no_wall_to_the_north:
			wall.get_node("North").visible = false
		if is_no_wall_to_the_south:
			wall.get_node("South").visible = false

		if (_west_of(pos) in terrain_chunk.buildable_positions or
			_east_of(pos) in terrain_chunk.buildable_positions or
			_north_of(pos) in terrain_chunk.buildable_positions or
			_south_of(pos) in terrain_chunk.buildable_positions):
			terrain_chunk.exterior_wall_positions.append(pos)

	return terrain_chunk


func _on_money_changed():
	for button in _button_from_chunk_position.values():
		button.disabled = (button.cost > GlobalBank.money)

func _west_of(pos: Vector2i) -> Vector2i:
	return pos + Vector2i(-Global.TILE_SIZE, 0)

func _east_of(pos: Vector2i) -> Vector2i:
	return pos + Vector2i(Global.TILE_SIZE, 0)

func _north_of(pos: Vector2i) -> Vector2i:
	return pos + Vector2i(0, -Global.TILE_SIZE)

func _south_of(pos: Vector2i) -> Vector2i:
	return pos + Vector2i(0, Global.TILE_SIZE)
