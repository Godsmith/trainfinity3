extends Node2D

enum ORE_TYPE {COAL}

@export var ore_type := ORE_TYPE.COAL

func _ready():
	var color = Color(0,0,0,255.0)
	match ore_type:
		ORE_TYPE.COAL:
			color = Color(0,0,0,255.0)
		
	var chunks := get_tree().root.find_children("Chunk*", "", true, false)
	for chunk in chunks:
		if chunk is Polygon2D:
			chunk.color = color
