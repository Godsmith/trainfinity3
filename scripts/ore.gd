extends Node2D

class_name Ore

enum OreType {COAL}

const ORE_COLOR = {
	OreType.COAL: Color(0, 0, 0, 255.0)
}

@export var ore_type := OreType.COAL

func _ready():
	var color = ORE_COLOR[ore_type]
		
	var chunks := get_tree().root.find_children("Chunk*", "", true, false)
	for chunk in chunks:
		if chunk is Polygon2D:
			chunk.color = color
