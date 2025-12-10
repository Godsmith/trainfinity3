extends MarginContainer

@onready var grid := $MarginContainer/VBoxContainer/ScrollContainer/GridContainer

signal close_button_clicked

var _button_from_upgrade: Dictionary[Upgrades.Upgrade, Button]

func _ready() -> void:
	update_grid()
	GlobalBank.money_changed.connect(_on_money_changed)

func update_grid() -> void:
	for child in grid.get_children():
		child.queue_free()
	for upgrade in Upgrades.upgrades.values():
		var name_label = Label.new()
		name_label.text = upgrade.name
		grid.add_child(name_label)
	
		var value_label = Label.new()
		if upgrade.is_maxed_out():
			value_label.text = "%d" % [
				upgrade.get_current_value(),
			]
		else:
			value_label.text = "%d → %d" % [
				upgrade.get_current_value(),
				upgrade.get_next_value()
			]
		grid.add_child(value_label)

		var button = Button.new()
		if upgrade.is_maxed_out():
			button.text = "MAX"
		else:
			button.text = "Upgrade ($%d)" % upgrade.get_next_cost()
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_upgrade_pressed.bind(upgrade, button))
		_button_from_upgrade[upgrade] = button
		grid.add_child(button)

		set_buttons_enabled()


func set_buttons_enabled():
	for upgrade in _button_from_upgrade:
		_button_from_upgrade[upgrade].disabled = (
			upgrade.is_maxed_out() or
			upgrade.get_next_cost() > GlobalBank.money
			)


func _on_upgrade_pressed(upgrade: Upgrades.Upgrade, button: Button):
	GlobalBank.spend_money(upgrade.get_next_cost(), button.global_position)
	upgrade.upgrade()
	update_grid()


func _on_close_button_pressed() -> void:
	close_button_clicked.emit()


func _on_money_changed():
	set_buttons_enabled()
