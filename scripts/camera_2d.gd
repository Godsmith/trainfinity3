extends Camera2D

const MAX_ZOOM = 6.0
const MIN_ZOOM = 0.5

# Smooth movement settings
const FOLLOW_SPEED = 8.0 # How fast camera follows trains
const PAN_SMOOTHING = 24.0 # How smooth manual panning feels
const ZOOM_SMOOTHING = 10.0 # How smooth zooming feels

var target_position: Vector2
var target_zoom: Vector2
var is_following_target = false
var pan_velocity = Vector2.ZERO

func _ready():
	target_position = position
	target_zoom = zoom

func _process(delta: float):
	# Smooth position interpolation
	if is_following_target:
		position = position.lerp(target_position, FOLLOW_SPEED * delta)
	else:
		# Apply pan velocity with damping for smooth manual panning
		position += pan_velocity * delta
		pan_velocity = pan_velocity.lerp(Vector2.ZERO, PAN_SMOOTHING * delta)
	
	# Smooth zoom interpolation
	zoom = zoom.lerp(target_zoom, ZOOM_SMOOTHING * delta)

func set_follow_target(target_pos: Vector2):
	target_position = target_pos
	is_following_target = true

func stop_following():
	is_following_target = false
	target_position = position

func add_pan_velocity(velocity: Vector2):
	is_following_target = false
	pan_velocity += velocity * PAN_SMOOTHING

func apply_boundary_correction(correction: Vector2):
	# Apply boundary corrections smoothly by adjusting target position
	if is_following_target:
		target_position += correction
	else:
		# For manual panning, apply correction directly but smoothly
		position += correction * 0.3 # Gentle correction
		# Also add some opposing velocity to create smooth bounce-back
		pan_velocity -= correction * 0.1

func zoom_camera(factor: float) -> void:
	var new_zoom = target_zoom * factor
	if new_zoom.x > MIN_ZOOM and new_zoom.x < MAX_ZOOM:
		target_zoom = new_zoom
		var previous_mouse_position := get_local_mouse_position()
		var diff = previous_mouse_position - get_local_mouse_position()
		offset += diff
