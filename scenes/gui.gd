extends CanvasLayer

class_name Gui

enum State {NONE, TRACK, STATION, TRAIN1, TRAIN2, LIGHT, DESTROY}

func show_money(money: int):
	$HBoxContainer/Money.text = "$%s" % money

func update_prices(prices: Dictionary[Global.Asset, float]):
	$HBoxContainer/TrackButton.text = "Track $%s" % floori(prices[Global.Asset.TRACK])
	$HBoxContainer/StationButton.text = "Station $%s" % floori(prices[Global.Asset.STATION])
	$HBoxContainer/TrainButton.text = "Train $%s" % floori(prices[Global.Asset.TRAIN])

func _unpress_all():
	for button: Button in find_children("", "Button", true):
		button.set_pressed_no_signal(false)

func set_pressed_no_signal(gui_state: State):
	_unpress_all()
	match gui_state:
		State.TRACK:
			$HBoxContainer/TrackButton.set_pressed_no_signal(true)
		State.STATION:
			$HBoxContainer/StationButton.set_pressed_no_signal(true)
		State.TRAIN1, State.TRAIN2:
			$HBoxContainer/TrainButton.set_pressed_no_signal(true)
		State.DESTROY:
			$HBoxContainer/DestroyButton.set_pressed_no_signal(true)
