extends Game

const T = Global.TILE_SIZE
const STEELWORKS = preload("res://scenes/industry/steelworks.tscn")
const FACTORY = preload("res://scenes/industry/factory.tscn")

@export var create_ore_and_factory: bool
@export var diagonal_track: bool
@export var extra_track_after_first_station: bool = true

func _ready():
	super._ready()

	_load_game_from_path("res://savegames/2025-12-04_21-40-33.save")
