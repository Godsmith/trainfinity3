extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for i in 12:
		$Wagon.add_resource(Global.ResourceType.COAL)
		await get_tree().create_timer(1.0).timeout
