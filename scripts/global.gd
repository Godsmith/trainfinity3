extends Node

class_name Global

const MAX_INT = 9223372036854775807

const TILE_SIZE := 16
const TILE := Vector2(TILE_SIZE, TILE_SIZE)
const POPUP = preload("res://scenes/popup.tscn")

enum Asset {TRACK, STATION, TRAIN}

enum ResourceType {COAL, IRON, MAIL, WOOD, STEEL}

const RESOURCE_COLOR = {
	ResourceType.COAL: Color(0, 0, 0, 1),
	ResourceType.IRON: Color(0.612, 0.416, 0.416, 1.0),
	ResourceType.MAIL: Color(0.95, 0.95, 0.7, 1.0),
	ResourceType.WOOD: Color(0.49, 0.245, 0.223, 1.0),
	ResourceType.STEEL: Color(0.8, 0.8, 0.8, 1.0),
}

const RESOURCE_PRICE_MULTIPLIER = {
	ResourceType.COAL: 1,
	ResourceType.IRON: 1,
	ResourceType.MAIL: 1,
	ResourceType.WOOD: 1,
	ResourceType.STEEL: 2,
}

static func get_resource_name(resource_type_: ResourceType) -> String:
	return ResourceType.keys()[resource_type_]
		

class Vector2iOrNone:
	var value: Vector2i
	var has_value: bool

	func _init(has_value_: bool, value_: Vector2i = Vector2i.ZERO):
		self.has_value = has_value_
		self.value = value_

static func is_orthogonally_adjacent(position1: Vector2i, position2: Vector2i) -> bool:
	return position2 in orthogonally_adjacent(position1)

static func orthogonally_adjacent(pos: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for delta in [Vector2i(TILE_SIZE, 0), Vector2i(-TILE_SIZE, 0),
				  Vector2i(0, TILE_SIZE), Vector2i(0, -TILE_SIZE)]:
		out.append(pos + delta)
	return out


static func show_popup(text: String, pos: Vector2, parent: Node, modulate: Color = Color(1.0, 1.0, 1.0, 1.0)):
	var popup = POPUP.instantiate()
	popup.modulate = modulate
	popup.position = pos
	parent.add_child(popup)
	popup.show_popup(text)
