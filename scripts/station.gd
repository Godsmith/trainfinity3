extends Node2D

class_name Station

signal station_clicked(station: Station)

@export var is_ghost := false
@export var ore = 0

var adjacent_ores = []
var _chunks = []


func _ready():
	for ore_: Ore in get_tree().get_nodes_in_group("ores"):
		if Global.is_orthogonally_adjacent(Vector2i(global_position), Vector2i(ore_.global_position)):
			adjacent_ores.append(ore_)
	

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		station_clicked.emit(self)

func extract_ore():
	for adjacent_ore: Ore in adjacent_ores:
		ore += 1
		var new_chunk := $Chunk.duplicate()
		# Some magic position numbers to not place ores too much outside. Will probably be changed anyway.
		new_chunk.position = Vector2(randf_range(-Global.TILE_SIZE / 2 + 5, Global.TILE_SIZE / 2 + 1),
									 randf_range(-Global.TILE_SIZE / 2 + 5, Global.TILE_SIZE / 2 + 1))
		new_chunk.visible = true
		new_chunk.color = adjacent_ore.ORE_COLOR[adjacent_ore.ore_type]
		_chunks.append(new_chunk)
		add_child(new_chunk)
		
func remove_ore():
	_chunks.pop_back().queue_free()
	ore -= 1

func set_color(is_ghostly: bool, is_allowed: bool):
	var r = 1.0
	var g = 1.0 if is_allowed else 0.5
	var b = 1.0 if is_allowed else 0.5
	var a = 0.5 if is_ghostly else 1.0
	modulate = Color(r, g, b, a)
