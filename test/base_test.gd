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

func click(x: float, y: float):
	mouse_move(x, y)

	var click_event = InputEventMouseButton.new()
	click_event.pressed = true
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.position = Vector2(x, y)
	_game._unhandled_input(click_event)
