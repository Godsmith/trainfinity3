extends CanvasLayer

class_name Gui

func show_money(money: int):
	$HBoxContainer/Money.text = "$%s" % money
