extends RefCounted

class_name TrackReservations

var reservations: Dictionary[Vector2i, Train] = {}
var reservation_number := 0

## Returns the first blocked position if the reservation was unsuccessful
func try_reserve_train_positions(new_positions: Array[Vector2i], train: Train) -> Global.Vector2iOrNone:
	# TODO: remove the Train class here. Circular dependency, and also makes it impossible
	# to unreserve after a train is freed. Use train name + randomly generated string?
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
	# This triggers trains that are waiting for reservations
	reservation_number += 1
	return Global.Vector2iOrNone.new(false)


func clear_reservations(train: Train):
	for pos in reservations.keys():
		if reservations[pos] == train:
			reservations.erase(pos)
	# This triggers trains that are waiting for reservations
	reservation_number += 1


func is_reserved(pos: Vector2i):
	return pos in reservations


func is_reserved_by_another_train(pos: Vector2i, train: Train):
	return is_reserved(pos) and reservations[pos] != train
