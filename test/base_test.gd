extends GutTest

class_name BaseTest

var _game: Game


func press(keycode):
	var press_event = InputEventKey.new()
	press_event.keycode = keycode
	press_event.pressed = true
	_game._unhandled_input(press_event)

func mouse_move(x: float, y: float):
	var move_event = InputEventMouseMotion.new()
	move_event.position = Vector2(x, y)
	_game._unhandled_input(move_event)

func mouse_down(x: float, y: float):
	var mouse_down_event = InputEventMouseButton.new()
	mouse_down_event.pressed = true
	mouse_down_event.button_index = MOUSE_BUTTON_LEFT
	mouse_down_event.position = Vector2(x, y)
	_game._unhandled_input(mouse_down_event)

func mouse_up(x: float, y: float):
	var mouse_up_event = InputEventMouseButton.new()
	mouse_up_event.pressed = false
	mouse_up_event.button_index = MOUSE_BUTTON_LEFT
	mouse_up_event.position = Vector2(x, y)
	_game._unhandled_input(mouse_up_event)

func click(x: float, y: float):
	mouse_move(x, y)
	mouse_down(x, y)
	mouse_up(x, y)
