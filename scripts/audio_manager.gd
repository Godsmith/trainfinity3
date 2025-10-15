extends Node

var num_players = 8
var bus = "master"

var available: Array[AudioStreamPlayer2D] = [] # The available players.
var queue: Array[_PlayTask] = [] # The queue of sounds to play.

const COIN_SPLASH = preload("res://audio/coinsplash.ogg")

class _PlayTask:
	var stream: AudioStream
	var position: Vector2

	func _init(stream_: AudioStream, position_: Vector2):
		self.stream = stream_
		self.position = position_


func _ready():
	# Create the pool of AudioStreamPlayer2D nodes.
	for i in num_players:
		var player = AudioStreamPlayer2D.new()
		add_child(player)
		available.append(player)
		player.finished.connect(_on_stream_finished.bind(player))
		player.bus = bus


func _on_stream_finished(stream):
	# When finished playing a stream, make the player available again.
	available.append(stream)


func play(stream: AudioStream, position_: Vector2):
	queue.append(_PlayTask.new(stream, position_))


func _process(_delta):
	# Play a queued sound if any players are available.
	if not queue.is_empty() and not available.is_empty():
		var task = queue.pop_front()
		var player = available.pop_front()
		player.stream = task.stream
		player.global_position = task.position
		player.play()
		available.pop_front()
