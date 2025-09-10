# Trainfinity

## Features
- Stations built next to mines will get filled with coal
- Stations built next to the factory accepts coal
- Build a stretch of rail adjacent to a station to create a platform
- Prices increase with the number of objects built

## Controls
- elect Track and click and drag to build track
- Select Station and click an empty location (preferrably next to a station or factory) to build a station
- Select Train and click two platforms in succession to create a train and a route.
  - Train length is equal to the shortest platform length
- Select Destroy and click on track and stations to destroy them
- Modes can also be selected with the number keys (1 to build track etc)


## TODO
- disallow creating rail on top of factory
- z-order ghost factory on top of factory
- put track rails and sleepers on different layers
- follow train
- show ghost platforms when building station
- show ghost platforms when building track
- disallow building out of bounds
- iron
- heavier trains should have slower acceleration
- change train paths when changing length of starting or ending station
- do something - stop train? delete train? - when removing starting or ending station
- prevent scrolling past edges of the map
  - note that duplicating the map size and zooming out max makes the game stutter, so adjustments needed. 
    At least in debug mode, need to test performance after exporting as well.
- saving the game
- train collisions
  - cannot be done until we have pathfinding that takes other trains into account/signals/manual paths

### Bugs
- wagons unloaded in the wrong direction
- train disappeared when going to station with no coal
- cargo wans can spawn with strange rotation
  - will be solved once too-long trains cannot spawn
- cargo wagons are loaded in slightly wrong order

### In-game upgrades
- range of stations (start with 1) - though it looks ugly when they are too far from ore
- number of trains (start with 1)
- map size
- the ability to tear down/build track on mountain
- bridges
- train loading speed

### Between-round upgrades
- starting everything above
- amount of ore per tile
