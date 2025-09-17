extends PathFollow2D

@onready var _chunks := find_children("Chunk*")
@onready var max_capacity := len(_chunks)
@onready var rigid_body: RigidBody2D = $RigidBody2D
@onready var collision_shape: CollisionShape2D = $RigidBody2D/CollisionShape2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for chunk in _chunks:
		chunk.visible = false

func add_ore(type: Ore.OreType):
	for chunk in _chunks:
		if not chunk.visible:
			chunk.ore_type = type
			chunk.color = Ore.ORE_COLOR[type]
			chunk.visible = true
			return
	assert(false, "Trying to add chunk to full wagon")

func get_total_ore_count() -> int:
	var count := 0
	for chunk in _chunks:
		if chunk.visible:
			count += 1
	return count

func get_ore_count(ore_type: Ore.OreType) -> int:
	var count := 0
	for chunk in _chunks:
		if chunk.visible and chunk.ore_type == ore_type:
			count += 1
	return count

func remove_ore(ore_type):
	for chunk in _chunks:
		if chunk.visible and chunk.ore_type == ore_type:
			chunk.visible = false
			return
	assert(false, "Trying to remove ore type that did not exist")
