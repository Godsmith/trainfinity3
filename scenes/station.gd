extends Node2D

class_name Station

const MAX_CAPACITY := 24

@export var is_ghost := false

var _chunks: Array[Chunk] = []

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		Events.station_clicked.emit(self)

func add_resource(resource_type: Global.ResourceType, is_created_here: bool):
	var new_chunk := $Chunk.duplicate()
	new_chunk.is_created_here = is_created_here
	# Some magic position numbers to not place resources too much outside. Will probably be changed anyway.
	new_chunk.position = Vector2(randf_range(-Global.TILE_SIZE / 2 + 5, Global.TILE_SIZE / 2 + 1),
									randf_range(-Global.TILE_SIZE / 2 + 5, Global.TILE_SIZE / 2 + 1))
	new_chunk.visible = true
	new_chunk.resource_type = resource_type
	new_chunk.color = Global.RESOURCE_COLOR[resource_type]
	_chunks.append(new_chunk)
	add_child(new_chunk)
	Events.station_content_updated.emit(self)

func is_at_max_capacity():
	return get_total_resource_count() >= MAX_CAPACITY

func get_total_resource_count() -> int:
	return len(_chunks)

func get_resource_count(resource_type: Global.ResourceType) -> int:
	return _chunks.reduce(func(accum, chunk): return accum + 1 if chunk.resource_type == resource_type else accum, 0)

func get_resource_not_created_here_count(resource_type: Global.ResourceType) -> int:
	return _chunks.reduce(func(accum, chunk): return accum + 1 if chunk.resource_type == resource_type and not chunk.is_created_here else accum, 0)
		
## Remove a single resourcde from the station
func remove_resource(resource_type: Global.ResourceType):
	var index = _chunks.find_custom(func(x): return x.resource_type == resource_type)
	var chunk = _chunks.pop_at(index)
	chunk.queue_free()
	Events.station_content_updated.emit(self)

func set_color(is_ghostly: bool, is_allowed: bool):
	var r = 1.0
	var g = 1.0 if is_allowed else 0.5
	var b = 1.0 if is_allowed else 0.5
	var a = 0.5 if is_ghostly else 1.0
	modulate = Color(r, g, b, a)

func accepts() -> Array[Global.ResourceType]:
	var accepted_resource_types_dict: Dictionary[Global.ResourceType, int] = {}
	for industry in get_tree().get_nodes_in_group("industries"):
		if Global.is_orthogonally_adjacent(industry.get_global_position(), position):
			for resource_type in industry.consumes:
				accepted_resource_types_dict[resource_type] = 0
	return accepted_resource_types_dict.keys()
