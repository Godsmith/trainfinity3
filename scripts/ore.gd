extends Node2D

class_name Ore

# TODO: move this out of class and rename to Resource
enum OreType {COAL, IRON, MAIL, WOOD}

const ORE := preload("res://scenes/ore.tscn")

const ORE_COLOR = {
	OreType.COAL: Color(0, 0, 0, 1),
	OreType.IRON: Color(0.8, 0.8, 0.8, 1.0),
	OreType.MAIL: Color(0.95, 0.95, 0.7, 1.0),
	OreType.WOOD: Color(0.49, 0.245, 0.223, 1.0)
}

var ore_type

static func create(ore_type_: OreType) -> Ore:
	var ore = ORE.instantiate()
	ore.ore_type = ore_type_
	return ore
		
func _ready() -> void:
	var chunks = find_children("Chunk*", "", true, false)
	for chunk in chunks:
		if chunk is Polygon2D:
			#print(ORE_COLOR[ore_type])
			chunk.color = ORE_COLOR[ore_type]
