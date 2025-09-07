# In-game upgrades
- range of stations (start with 1) - though it looks ugly when they are too far from ore
- number of trains (start with 1)
- map size
- the ability to tear down/build track on mountain
- bridges

# Between-round upgrade
- starting everything above
- amount of ore per tile

# TODO
- larger stations
  - x after building station, create new platform on all n/s or w/e stretches
  - rotate buildings correctly
  - ensure platforms are only built if length is at least 2
  - after building rail, create new platform on all n/s or w/e stretches
    orthogonally adjacent to one or more stations.
  - show ghost platforms of the above when building station
  - show ghost platforms of the above when building track
  - after deleting rail or station, reevaluate all existing platform spaces. if not adjacent to station or adjacent
    to adjacent to station etc, remove platform.
  - disallow creating tracks going off at the wrong angle from existing platforms
  - change pathfinding nodes to be not on the station tile but either of the platform tiles. 
    - Paths should go all the way to the furthest point of the target station's platform.
    - When following the path, should start some way into the path; at the end of the station closest to the
      target station.
    - Since one station can have multiple platforms, should click platforms instead of stations.
  - support building station after rail. show ghost platform on orthogonally adjacent stretch of rail.
    - problem 1: if very long adjacent stretch of rail, not clear where to put platform. 
      - just make a platform on all of it
    - problem 2: if adjacent to two stretches of rail, which one to choose? 
      - support both. Yes, probably.
- popup when earning money
- iron
- prevent scrolling past edges of the map
  - note that duplicating the map size and zooming out max makes the game stutter, so adjustments needed. 
    At least in debug mode, need to test performance after exporting as well.
- saving the game
- train collisions
  - cannot be done until we have pathfinding that takes other trains into account/signals/manual paths
