# In-game upgrades
- range of stations (start with 1) - though it looks ugly when they are too far from ore
- number of trains (start with 1)
- map size
- the ability to tear down/build track on mountain
- bridges
- train loading speed

# Between-round upgrade
- starting everything above
- amount of ore per tile

# TODO
- larger stations
  - x after building station, create new platform on adjacent n/s or w/e stretches
  - x rotate buildings correctly
  - x after building rail, create new platform on adjacent n/s or w/e stretches
  - x do not create platforms if they are adjacent to another platform but in wrong direction
  - x refactor to add TrackSet
  - x change train creation from between stations to between platform tiles. single platform tiles for now.
  - x when train stops at platform, take ore from all stations adjacent to platform
  - x mark all platforms green when going into TRAIN1
  - x prevent train from going from platform to same platform
  - x Paths should go all the way to the furthest point of the target station's platform.
  - x When following the path, should start some way into the path; at the end of the station closest to the
      target station.
  - x Since one station can have multiple platforms, should click platforms instead of stations.
  - Reevaluate platforms (also update platforms variable)
    - x when deleting rail
    - x when deleting station
    - x when creating tracks going off at the wrong angle from existing platforms
    - bug where two stations can be connected by a track at the wrong angle
  - ensure platforms are only built if length is at least 2
  - show ghost platforms of the above when building station
  - show ghost platforms of the above when building track
- make trains wait at stations
- put track rails and sleepers on different layers
- disallow creating stations on water and mountains
- disallow creating stations on top of stations
- popup when earning money
- follow train
- disallow creating stuff out of bounds
- iron
- change train paths when changing length of starting or ending station
- do something - stop train? delete train? - when removing starting or ending station
- prevent scrolling past edges of the map
  - note that duplicating the map size and zooming out max makes the game stutter, so adjustments needed. 
    At least in debug mode, need to test performance after exporting as well.
- saving the game
- train collisions
  - cannot be done until we have pathfinding that takes other trains into account/signals/manual paths
