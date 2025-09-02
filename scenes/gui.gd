extends CanvasLayer

class_name Gui

func show_money(money: int):
	$HBoxContainer/Money.text = "$%s" % money

func unpress_all():
	for button: Button in find_children("", "Button", true):
		button.set_pressed_no_signal(false)
