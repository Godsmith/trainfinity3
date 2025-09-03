extends CanvasLayer

class_name Gui

func show_money(money: int):
	$HBoxContainer/Money.text = "$%s" % money

func update_prices(prices: Dictionary[Global.Asset, float]):
	$HBoxContainer/TrackButton.text = "Track $%s" % floori(prices[Global.Asset.TRACK])
	$HBoxContainer/StationButton.text = "Station $%s" % floori(prices[Global.Asset.STATION])
	$HBoxContainer/TrainButton.text = "Train $%s" % floori(prices[Global.Asset.TRAIN])

func unpress_all():
	for button: Button in find_children("", "Button", true):
		button.set_pressed_no_signal(false)
