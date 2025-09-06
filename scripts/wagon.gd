extends PathFollow2D

@onready var _chunks := find_children("Chunk*")
@onready var max_capacity := len(_chunks)
@onready var rigid_body: RigidBody2D = $RigidBody2D
@onready var collision_shape: CollisionShape2D = $RigidBody2D/CollisionShape2D

var ore := 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for chunk in _chunks:
		chunk.visible = false

func add_ore(type: Ore.ORE_TYPE):
	_chunks[ore].color = Ore.ORE_COLOR[type]
	_chunks[ore].visible = true
	ore += 1

func remove_ore():
	ore -= 1
	_chunks[ore].visible = false
