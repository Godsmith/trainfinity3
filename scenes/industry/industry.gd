extends Node2D

class_name Industry

@export var produces: Array[Global.ResourceType]
@export var consumes: Array[Global.ResourceType]

@export var requires_resources_to_produce: bool = false

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		Events.industry_clicked.emit(self)

func get_price(resource_type: Global.ResourceType):
	var shortest_distance := Global.MAX_INT
	for other in get_tree().get_nodes_in_group("industries"):
		if other is Industry and other != self:
			if resource_type in other.produces:
				shortest_distance = min(_tile_distance(other), shortest_distance)
	return shortest_distance * Global.RESOURCE_PRICE_MULTIPLIER[resource_type]

func _tile_distance(other: Industry):
	var pos = Vector2i(position)
	var other_pos = Vector2i(other.position)
	return max(absi(pos.x - other_pos.x), absi(pos.y - other_pos.y)) / Global.TILE_SIZE
