extends Node

class_name UpgradeManager

enum UpgradeType {PLATFORM_LENGTH, TRAIN_MAX_SPEED, TRAIN_ACCELERATION}

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


var upgrades: Dictionary[UpgradeType, Upgrade] = {
	UpgradeType.PLATFORM_LENGTH: Upgrade.new("Platform length", [2, 3, 4, 5], [0, 100, 500, 1000]),
	UpgradeType.TRAIN_MAX_SPEED: Upgrade.new("Train max speed", [20, 25, 30, 35], [0, 100, 500, 1000]),
	UpgradeType.TRAIN_ACCELERATION: Upgrade.new("Train acceleration", [5, 6, 7, 8], [0, 100, 500, 1000]),
 }

func get_value(type: UpgradeType):
	return upgrades[type].get_current_value()
