extends Node

class_name TrackReservations

var reservations: Dictionary[Vector2i, Train] = {}
signal reservations_updated

func reserve_train_positions(new_positions: Array[Vector2i], train: Train) -> bool:
	# check first
	for pos in new_positions:
		if reservations.has(pos) and reservations[pos] != train:
			return false
	# erase old reservation
	for pos in reservations.keys():
		if reservations[pos] == train:
			reservations.erase(pos)
	# set new reservation
	for pos in new_positions:
		reservations[pos] = train
	reservations_updated.emit()
	return true


func clear_reservations(train: Train):
	for pos in reservations.keys():
		if reservations[pos] == train:
			reservations.erase(pos)
	reservations_updated.emit()


func is_reserved(pos: Vector2i):
	return pos in reservations


func is_reserved_by_another_train(pos: Vector2i, train: Train):
	return is_reserved(pos) and reservations[pos] != train
