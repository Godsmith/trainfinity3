extends RefCounted

class_name TerrainVerifier

## Verifies so that coal mines and steelworks are connected, etc.
## [br][Industries] is all Industry objects on the map.
## [br][astar] must have all impassable terrain tiles as solid. It does not matter if
## industry tiles are solid, this method will set them as not solid.
static func verify_starting_terrain(industries: Array[Industry], astar: AStarGrid2D) -> bool:
	var industries_from_produced_resource: Dictionary[Global.ResourceType, Array] = {}
	var industries_from_consumed_resource: Dictionary[Global.ResourceType, Array] = {}
	for industry in industries:
		for resource_type: Global.ResourceType in industry.produces:
			if not resource_type in industries_from_produced_resource:
				industries_from_produced_resource[resource_type] = []
			industries_from_produced_resource[resource_type].append(industry)
		for resource_type: Global.ResourceType in industry.consumes:
			if not resource_type in industries_from_consumed_resource:
				industries_from_consumed_resource[resource_type] = []
			industries_from_consumed_resource[resource_type].append(industry)

	if not len(industries_from_produced_resource) == len(industries_from_consumed_resource):
		print("Mismatch! Resources produced: %s. Resources consumed: %s. Regenerating terrain." \
			  % [len(industries_from_produced_resource), len(industries_from_consumed_resource)])
		return false

	var path_exists_for_resource: Dictionary[Global.ResourceType, bool] = {}
	# Make industries non-solid to be able to get path from one industry tile to another
	for industry in industries:
		astar.set_point_solid(Vector2i(industry.position) / Global.TILE_SIZE, false)
	for resource_type in industries_from_consumed_resource:
		path_exists_for_resource[resource_type] = _path_exists_for_resource(resource_type, industries_from_produced_resource,
															 industries_from_consumed_resource, astar)
	if not path_exists_for_resource.values().all(func(x): return x):
		print("Producer and consumer not connected for all resources:")
		for resource_type in path_exists_for_resource:
			print("%s: %s" % [Global.get_resource_name(resource_type), path_exists_for_resource[resource_type]])
		return false

	print("Starting terrain verified.")
	return true


static func _path_exists_for_resource(resource_type: Global.ResourceType,
		industries_from_produced_resource: Dictionary[Global.ResourceType, Array],
		industries_from_consumed_resource: Dictionary[Global.ResourceType, Array],
		astar: AStarGrid2D):
	for consumer in industries_from_consumed_resource[resource_type]:
		for producer in industries_from_produced_resource[resource_type]:
			if astar.get_point_path(Vector2i(consumer.position) / Global.TILE_SIZE, Vector2i(producer.position) / Global.TILE_SIZE):
				return true
	return false
