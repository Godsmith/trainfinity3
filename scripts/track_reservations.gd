extends Node

class_name TrackReservations

var reservations: Dictionary[Vector2i, Train] = {}

func reserve_train_positions(new_positions: Array[Vector2i], train: Train) -> bool:
	# check first
	for pos in new_positions:
		if reservations.has(pos) and reservations[pos] != train:
			return false
	# erase old reservation
	clear_reservations(train)
	# set new reservation
	for pos in new_positions:
		reservations[pos] = train
	return true

func clear_reservations(train: Train):
	for pos in reservations.keys():
		if reservations[pos] == train:
			reservations.erase(pos)

func is_reserved_by_another_train(pos: Vector2i, train: Train):
	return pos in reservations and reservations[pos] != train
