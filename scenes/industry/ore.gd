extends Industry

class_name Ore

var resource_type

const ORE := preload("res://scenes/industry/ore.tscn")

static func create(resource_type_: Global.ResourceType) -> Ore:
	var ore = ORE.instantiate()
	ore.resource_type = resource_type_
	ore.produces.append(resource_type_)
	return ore

func _ready() -> void:
	var chunks = find_children("Chunk*", "", true, false)
	for chunk in chunks:
		if chunk is Polygon2D:
			chunk.color = Global.RESOURCE_COLOR[resource_type]
