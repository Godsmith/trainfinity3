# Event bus for distant nodes to communicate using signals.
# This is intended for cases where connecting the nodes directly creates more coupling
# or increases code complexity substantially.
extends Node

## Emitted when track reservations are updated, e.g. when track is reserved or
## unreserved by a train, but also when track is created or deleted.
## [br]If the signal is emitted by a train, the train is provided in the [by_train] 
## parameter. This is useful so that a train does not react to itself, for example.
signal track_reservations_updated(by_train: Train)


# Emitted when an industry is clicked
signal industry_clicked(industry: Industry)


# Emitted when a station is clicked
signal station_clicked(station: Station)
