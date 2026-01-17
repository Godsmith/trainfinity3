extends Node2D

class_name Terrain

const CHUNK_WIDTH := 11

enum ChunkType {COAL, IRON, FACTORY, STEELWORKS, FOREST, CITY, EMPTY, DEBUG_GRASS_ONLY}

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

# When creating terrain, grass and sand positions are recorded here,
# so that when building things later we can check this set to see
# where we can build. Using a Dictionary as a set, since there is
# no set in Godot.
var buildable_positions: Dictionary[Vector2i, Node] = {}

var _chunk_positions: Array[Vector2i] = []
var _button_from_chunk_position: Dictionary[Vector2i, ExpandButton] = {}

@onready var _noise := FastNoiseLite.new()
	
# Store every type of node under a separate node, since the Godot editor
# is very slow when it has to show all nodes at ones in the tree view
@onready var grass_node = Node.new()
@onready var water_node = Node.new()
@onready var sand_node = Node.new()
@onready var wall_node = Node.new()
@onready var forest_node = Node.new()
@onready var city_node = Node.new()

## Current minimum and maximum edges, used for restricting the camera
## and for pathfinding when building track
var boundaries = Rect2i()

# Used when saving the game
var chunks: Dictionary[Vector2i, ChunkType] = {}

# Storage: { ShapeHash: { "mesh": ArrayMesh, "transforms": Array, "colors": Array } }
var library = {}
var multimesh_nodes = {}

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
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 0.05

	add_child(grass_node)
	add_child(water_node)
	add_child(sand_node)
	add_child(wall_node)
	add_child(forest_node)
	add_child(city_node)

	GlobalBank.money_changed.connect(_on_money_changed)
	# Disable buttons
	_on_money_changed()


func bake_polygons() -> void:
	var nodes = find_children("*", "Polygon2D", true, false)
	
	for poly in nodes:
		if not poly is Polygon2D: continue

		if poly.visible:
			print(poly.name)
	
			# 1. Create a unique ID based on the vertex points (Deduplication Key)
			var shape_hash = hash(poly.polygon)
			
			if not library.has(shape_hash):
				library[shape_hash] = {
					"mesh": _create_mesh_from_polygon(poly.polygon),
					"transforms": [],
					"colors": []
				}

			# 2. Store the instance data
			# We use the global transform so it stays exactly where it was in the world
			var xform = get_global_transform().affine_inverse() * poly.get_global_transform()
			library[shape_hash]["transforms"].append(xform)
			library[shape_hash]["colors"].append(poly.color)
	
		poly.queue_free()
	print("removed %s polygons" % len(nodes))

	# 3. Build/Update MultiMesh nodes
	_apply_to_multimeshes()

func _create_mesh_from_polygon(points: PackedVector2Array) -> ArrayMesh:
	var mesh = ArrayMesh.new()
	var triangles = Geometry2D.triangulate_polygon(points)
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_INDEX] = triangles
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _apply_to_multimeshes():
	for shape_hash in library:
		var data = library[shape_hash]
		var instance_count = data["transforms"].size()
	
		var mm: MultiMesh
		# Create node if it doesn't exist
		if not multimesh_nodes.has(shape_hash):
			var mm_node = MultiMeshInstance2D.new()
			mm = MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_2D
			mm.use_colors = true
			mm.mesh = data["mesh"]
	
			mm_node.multimesh = mm
			add_child(mm_node)
			multimesh_nodes[shape_hash] = mm_node

		# Update the MultiMesh data
		mm = multimesh_nodes[shape_hash].multimesh
		mm.instance_count = instance_count
	
		for i in range(instance_count):
			mm.set_instance_transform_2d(i, data["transforms"][i])
			mm.set_instance_color(i, data["colors"][i])


func set_seed_and_add_chunks(randomizer_seed: int, chunks_: Dictionary[Vector2i, ChunkType]):
	_noise.seed = randomizer_seed
	for pos in chunks_:
		_add_chunk(pos.x, pos.y, chunks_[pos])
	
	bake_polygons()


func set_seed_and_add_starting_chunks(randomizer_seed: int):
	_noise.seed = randomizer_seed
	# CITY  FOREST      COAL
	# COAL  STEELWORKS  FACTORY
	# IRON  FOREST		CITY
	_add_chunk(-1, -1, ChunkType.CITY)
	_add_chunk(0, -1, ChunkType.FOREST)
	_add_chunk(1, -1, ChunkType.COAL)
	_add_chunk(-1, 0, ChunkType.COAL)

	_add_chunk(0, 0, ChunkType.STEELWORKS)

	_add_chunk(1, 0, ChunkType.FACTORY)
	_add_chunk(-1, 1, ChunkType.IRON)
	_add_chunk(0, 1, ChunkType.FOREST)
	_add_chunk(1, 1, ChunkType.CITY)
	
	bake_polygons()


func add_random_chunk(chunk_x: int, chunk_y: int):
	_add_chunk(chunk_x, chunk_y, ChunkType.values().pick_random())
	bake_polygons()


func _add_chunk(chunk_x: int, chunk_y: int, chunk_type: ChunkType):
	update_buttons(chunk_x, chunk_y)
	var grid_positions: Array[Vector2i] = []
	var noise_from_position: Dictionary[Vector2i, float] = {}
	for x in range(chunk_x * CHUNK_WIDTH - (CHUNK_WIDTH - 1) / 2, chunk_x * CHUNK_WIDTH + (CHUNK_WIDTH - 1) / 2 + 1):
		for y in range(chunk_y * CHUNK_WIDTH - (CHUNK_WIDTH - 1) / 2, chunk_y * CHUNK_WIDTH + (CHUNK_WIDTH - 1) / 2 + 1):
			var grid_position = Vector2i(x, y) * Global.TILE_SIZE
			grid_positions.append(grid_position)
			var noise = 0.0 if chunk_type == ChunkType.DEBUG_GRASS_ONLY else _noise.get_noise_2d(x, y)
			noise_from_position[grid_position] = noise
	var terrain_chunk = _create_terrain(grid_positions, noise_from_position)
	chunks[Vector2i(chunk_x, chunk_y)] = chunk_type

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
				if pos in buildable_positions:
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
				if new_city_position in buildable_positions and new_city_position not in handled_city_positions and new_city_position in grid_positions:
					current_size += 1
					handled_city_positions.append(new_city_position)
					possible_new_city_positions.append_array(Global.orthogonally_adjacent(new_city_position))
					var new_city = CITY.instantiate()
					new_city.position = new_city_position
					add_child(new_city)
			print("City extension done")
		ChunkType.DEBUG_GRASS_ONLY:
			pass


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
		button.pressed.connect(_expand_button_clicked.bind(button, new_button_chunk_position.x, new_button_chunk_position.y))
		_button_from_chunk_position[new_button_chunk_position] = button
		add_child(button)


func _expand_button_clicked(button: ExpandButton, chunk_x: int, chunk_y: int):
	GlobalBank.spend_money(button.cost, button.global_position)
	add_random_chunk(chunk_x, chunk_y)
	Events.expand_button_clicked.emit()


func _create_terrain(grid_positions: Array[Vector2i], noise_from_position: Dictionary[Vector2i, float]) -> TerrainChunk:
	# TODO: split into generating the terrain and actually creating the objects
	# to be able to load terrain from save game
	var terrain_chunk = TerrainChunk.new()
	var wall_from_position: Dictionary[Vector2i, Wall] = {}
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
			water.position = pos
			water_node.add_child(water)
		elif noise_level < sand_level:
			var sand = SAND.instantiate()
			sand.position = pos
			buildable_positions[pos] = sand
			sand_node.add_child(sand)
		elif noise_level > mountain_level:
			# Show grass under mountain
			var grass = GRASS.instantiate()
			grass.position = pos
			grass_node.add_child(grass)

			var wall = WALL.instantiate()
			wall.position = pos
			wall_node.add_child(wall)
			wall_from_position[pos] = wall
		else:
			var grass = GRASS.instantiate()
			grass.position = pos
			grass_node.add_child(grass)
			terrain_chunk.buildable_positions.append(pos)
			buildable_positions[pos] = grass

	# Make walls look nicer 
	for pos in wall_from_position:
		var wall = wall_from_position[pos]

		if not _west_of(pos) in wall_from_position:
			wall.get_node("West").visible = false
		if not _east_of(pos) in wall_from_position:
			wall.get_node("East").visible = false
		if not _north_of(pos) in wall_from_position:
			wall.get_node("North").visible = false
		if not _south_of(pos) in wall_from_position:
			wall.get_node("South").visible = false

		if [_west_of(pos), _east_of(pos), _north_of(pos), _south_of(pos)].any(func(pos1): return pos1 in buildable_positions):
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
