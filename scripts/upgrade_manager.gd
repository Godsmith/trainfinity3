extends Node

class_name UpgradeManager

enum UpgradeType {
	# Asset limit upgrades
	TRACK_LIMIT,
	STATION_LIMIT,
	TRAIN_LIMIT,
	# Other upgrades
	PLATFORM_LENGTH,
	TRAIN_MAX_SPEED,
	TRAIN_ACCELERATION,
	STATION_CAPACITY
}

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
	# Asset limit upgrades
	UpgradeType.TRACK_LIMIT: Upgrade.new("Track Limit", [20, 40, 60, 80, 100], [0, 100, 400, 1600, 6400]),
	UpgradeType.STATION_LIMIT: Upgrade.new("Station Limit", [2, 4, 6, 8, 10], [0, 200, 800, 3200, 12800]),
	UpgradeType.TRAIN_LIMIT: Upgrade.new("Train Limit", [1, 2, 3, 4, 5], [0, 400, 1600, 6400, 25600]),
	# Other upgrades
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


## Get current asset limit for an asset type
func get_asset_limit(asset_type: Global.Asset) -> int:
	match asset_type:
		Global.Asset.TRACK:
			return get_value(UpgradeType.TRACK_LIMIT)
		Global.Asset.STATION:
			return get_value(UpgradeType.STATION_LIMIT)
		Global.Asset.TRAIN:
			return get_value(UpgradeType.TRAIN_LIMIT)
	return 0


## Get remaining assets of a type
func get_remaining_assets(asset_type: Global.Asset) -> int:
	var current_count = _get_current_asset_count(asset_type)
	var limit = get_asset_limit(asset_type)
	return max(0, limit - current_count)


## Check if asset can be built
func can_build_asset(asset_type: Global.Asset, amount := 1) -> bool:
	return get_remaining_assets(asset_type) >= amount


## Private method to get current asset counts using node groups
func _get_current_asset_count(asset_type: Global.Asset) -> int:
	match asset_type:
		Global.Asset.TRACK:
			# A track gets put in built-track when it gets built
			# Cannot use group "track" here, since ghost tracks are also part of that
			# group
			return get_tree().get_node_count_in_group("built-track")
		Global.Asset.STATION:
			return get_tree().get_node_count_in_group("stations")
		Global.Asset.TRAIN:
			return get_tree().get_node_count_in_group("trains")
	return 0
