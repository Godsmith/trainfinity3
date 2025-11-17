extends Game

const T = Global.TILE_SIZE
const STEELWORKS = preload("res://scenes/industry/steelworks.tscn")
const FACTORY = preload("res://scenes/industry/factory.tscn")

func _ready():
	super._ready()

	GlobalBank.earn(10000)

	_load_game("res://debug/three_trains_blocking/three_trains_blocking.save")
