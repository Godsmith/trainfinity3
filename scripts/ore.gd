extends Node2D

class_name Ore

# TODO: move this out of class and rename to Resource
enum OreType {COAL, IRON, MAIL}

const ORE_COLOR = {
	OreType.COAL: Color(0, 0, 0, 1),
	OreType.IRON: Color(0.5, 0.5, 0.5, 1.0),
	OreType.MAIL: Color(0.95, 0.95, 0.7, 1.0)
}

@export var ore_type := OreType.COAL

func _ready():
	var color = ORE_COLOR[ore_type]
		
	var chunks := get_tree().root.find_children("Chunk*", "", true, false)
	for chunk in chunks:
		if chunk is Polygon2D:
			chunk.color = color
