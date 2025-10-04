extends Node

class_name TrackReservations

var _reservations: Dictionary[Vector2i, Train] = {}

func reserve_train_positions(new_positions: Array[Vector2i], train: Train) -> bool:
	# check first
	for pos in new_positions:
		if _reservations.has(pos) and _reservations[pos] != train:
			return false
	# erase old reservation
	clear_reservations(train)
	# set new reservation
	for pos in new_positions:
		_reservations[pos] = train
	return true

func clear_reservations(train: Train):
	for pos in _reservations.keys():
		if _reservations[pos] == train:
			_reservations.erase(pos)

func is_reserved_by_another_train(pos: Vector2i, train: Train):
	return pos in _reservations and _reservations[pos] != train
