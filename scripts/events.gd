# Event bus for distant nodes to communicate using signals.
# This is intended for cases where connecting the nodes directly creates more coupling
# or increases code complexity substantially.
extends Node


# Emitted when an industry is clicked
signal industry_clicked(industry: Industry)


# Emitted when a station is clicked
signal station_clicked(station: Station)


# Emitted when station content is updated
signal station_content_updated(station: Station)


# Emitted when mouse enters track
signal mouse_enters_track(track: Track)


# Emitted when mouse exits track
signal mouse_exits_track(track: Track)
