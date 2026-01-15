extends Node

class_name UpgradeManager

enum UpgradeType {PLATFORM_LENGTH, TRAIN_MAX_SPEED, TRAIN_ACCELERATION, STATION_CAPACITY}

class Upgrade:
	var name: String
	var values: Array
	var costs: Array[int]
	var current_level: int = 0
	var type: UpgradeType

	func _init(
		name_: String,
		values_: Array,
		costs_: Array[int]) -> void:
		name = name_
		values = values_
		costs = costs_

	func get_current_value():
		return values[current_level]

	func get_next_value():
		return values[current_level + 1]

	func get_next_cost():
		return costs[current_level + 1]

	func is_maxed_out():
		return current_level == len(values) - 1

	func upgrade():
		current_level += 1
		Events.upgrade_bought.emit(self.type)


var upgrades: Dictionary[UpgradeType, Upgrade] = {
	UpgradeType.PLATFORM_LENGTH: Upgrade.new("Platform length", [2, 3, 4, 5], [0, 100, 500, 1000]),
	UpgradeType.TRAIN_MAX_SPEED: Upgrade.new("Train max speed", [20, 25, 30, 35], [0, 100, 500, 1000]),
	UpgradeType.TRAIN_ACCELERATION: Upgrade.new("Train acceleration", [5, 6, 7, 8], [0, 100, 500, 1000]),
	UpgradeType.STATION_CAPACITY: Upgrade.new("Station capacity per resource", [12, 24, 36, 48], [0, 100, 500, 1000]),
 }


func get_value(type: UpgradeType):
	return upgrades[type].get_current_value()


func save() -> Dictionary[String, int]:
	var save_data: Dictionary[String, int] = {}
	for upgrade in upgrades.values():
		save_data[upgrade.name] = upgrade.current_level
	return save_data


func load(save_data: Dictionary[String, int]) -> void:
	for upgrade in upgrades.values():
		upgrade.current_level = save_data[upgrade.name]

func reset():
	for upgrade in upgrades.values():
		upgrade.current_level = 0
