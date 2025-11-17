extends Node

class_name TrackReservations

var reservations: Dictionary[Vector2i, Train] = {}

## Returns the first blocked position if the reservation was unsuccessful
func reserve_train_positions(new_positions: Array[Vector2i], train: Train) -> Global.Vector2iOrNone:
	# check first
	for pos in new_positions:
		if reservations.has(pos) and reservations[pos] != train:
			return Global.Vector2iOrNone.new(true, pos)
	# erase old reservation
	for pos in reservations.keys():
		if reservations[pos] == train:
			reservations.erase(pos)
	# set new reservation
	for pos in new_positions:
		reservations[pos] = train
	# TODO: when this signal is emitted stuff gets a bit complicated,
	# since potentially multiple trains will resume execution.
	# Consider implementing a state machine to increase observability.
	Events.track_reservations_updated.emit(train)
	return Global.Vector2iOrNone.new(false)


func clear_reservations(train: Train):
	for pos in reservations.keys():
		if reservations[pos] == train:
			reservations.erase(pos)
	Events.track_reservations_updated.emit(train)


func is_reserved(pos: Vector2i):
	return pos in reservations


func is_reserved_by_another_train(pos: Vector2i, train: Train):
	return is_reserved(pos) and reservations[pos] != train
