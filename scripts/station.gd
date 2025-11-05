extends Node2D

class_name Station

const MAX_CAPACITY := 24

signal station_clicked(station: Station)

@export var is_ghost := false

var _chunks: Array[Chunk] = []

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		station_clicked.emit(self)

func add_ore(ore_type: Ore.OreType):
	var new_chunk := $Chunk.duplicate()
	# Some magic position numbers to not place ores too much outside. Will probably be changed anyway.
	new_chunk.position = Vector2(randf_range(-Global.TILE_SIZE / 2 + 5, Global.TILE_SIZE / 2 + 1),
									randf_range(-Global.TILE_SIZE / 2 + 5, Global.TILE_SIZE / 2 + 1))
	new_chunk.visible = true
	new_chunk.ore_type = ore_type
	new_chunk.color = Ore.ORE_COLOR[ore_type]
	_chunks.append(new_chunk)
	add_child(new_chunk)

func is_at_max_capacity():
	return get_total_ore_count() >= MAX_CAPACITY

func get_total_ore_count() -> int:
	return len(_chunks)

func get_ore_count(ore_type: Ore.OreType) -> int:
	return _chunks.reduce(func(accum, chunk): return accum + 1 if chunk.ore_type == ore_type else accum, 0)
		
func remove_ore(ore_type: Ore.OreType):
	var index = _chunks.find_custom(func(x): return x.ore_type == ore_type)
	var chunk = _chunks.pop_at(index)
	chunk.queue_free()

func set_color(is_ghostly: bool, is_allowed: bool):
	var r = 1.0
	var g = 1.0 if is_allowed else 0.5
	var b = 1.0 if is_allowed else 0.5
	var a = 0.5 if is_ghostly else 1.0
	modulate = Color(r, g, b, a)

func accepts() -> Array[Ore.OreType]:
	var accepted_ore_types_dict: Dictionary[Ore.OreType, int] = {}
	for consumer in get_tree().get_nodes_in_group("resource_consumers"):
		if Global.is_orthogonally_adjacent(consumer.get_global_position(), position):
			for ore_type in consumer.consumes:
				accepted_ore_types_dict[ore_type] = 0
	return accepted_ore_types_dict.keys()
