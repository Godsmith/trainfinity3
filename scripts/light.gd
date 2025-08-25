extends Node2D

class_name Light

signal light_clicked(station: Light)

@export var is_ghost := false
@export var jitter_offset := 1.25
@export var jitter_speed := 12.0
@export var flicker_offset := 0.05

@onready var light := $PointLight2D

@onready var initial_energy = light.energy
var progress := 0.0


func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		light_clicked.emit(self)

func _process(delta: float) -> void:
	progress += delta * jitter_speed
	if progress >= 1.0:
		progress -= 1.0
		jitter()

func jitter() -> void:
	var p := Vector2(
			randf_range(-jitter_offset, jitter_offset),
			randf_range(-jitter_offset, jitter_offset)
	)
	light.position = p
	light.energy = initial_energy + randf_range(-flicker_offset, flicker_offset)
