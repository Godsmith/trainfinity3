extends Node2D

class_name Station

const TILE_SIZE = 16

signal station_clicked(station: Station)

@export var is_ghost := false
@export var ore = 0

var adjacent_ores = []


func _ready():
	for ore: Ore in get_tree().get_nodes_in_group("ores"):
		if _is_orthogonally_adjacent(Vector2i(global_position), Vector2i(ore.global_position)):
			adjacent_ores.append(ore)
	
func _is_orthogonally_adjacent(position1: Vector2i, position2: Vector2i) -> bool:
	for delta in [Vector2i(TILE_SIZE, 0),Vector2i(-TILE_SIZE, 0), Vector2i(0, TILE_SIZE), Vector2i(0, -TILE_SIZE)]:
		if position1 + delta == position2:
			return true
	return false
	

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		station_clicked.emit(self)

func extract_ore():
	for adjacent_ore: Ore in adjacent_ores:
		ore += 1
		var new_chunk := $Chunk.duplicate()
		# Some magic position numbers to not place ores too much outside. Will probably be changed anyway.
		new_chunk.position = Vector2(randf_range(-TILE_SIZE/2 + 5,TILE_SIZE/2 + 1), 
									 randf_range(-TILE_SIZE/2 + 5,TILE_SIZE/2 + 1))
		new_chunk.visible = true
		new_chunk.color = adjacent_ore.ORE_COLOR[adjacent_ore.ore_type]
		add_child(new_chunk)
	
