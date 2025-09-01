extends Node2D

class_name Ore

enum ORE_TYPE {COAL}

const ORE_COLOR = {
	ORE_TYPE.COAL: Color(0,0,0,255.0)
}

@export var ore_type := ORE_TYPE.COAL

func _ready():
	var color = ORE_COLOR[ore_type]
		
	var chunks := get_tree().root.find_children("Chunk*", "", true, false)
	for chunk in chunks:
		if chunk is Polygon2D:
			chunk.color = color
