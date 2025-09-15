# Trainfinity

## Features
- Stations built next to mines will get filled with coal
- Stations built next to the factory accepts coal
- Build a stretch of rail adjacent to a station to create a platform
- Prices increase with the number of objects built

## Controls
- To build track, select Track and either click start and then end positions, or drag from start
  position to end position
- Select Station and click an empty location (preferrably next to a station or factory) to build a station
- Select Train and click two platforms in succession to create a train and a route.
  - Train length is equal to the shortest platform length
- Select Destroy and click on track and stations to destroy them
- Modes can also be selected with the number keys (1 to build track etc)


## TODO
- if you remove the path for a train, it should take another path
  - step 2: recalculate when destroying track
    - create method track_set.get_tracks_from_route
    - when creating a train, make it subscribe to destroy signals from all tracks
      along route
    - when getting such a signal, recalculate route to destination

- change graphics for end of station, so it can't look like two stations are one
  large station
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
- build platforms instead of stations
  - done on create-platform-like-track branchs, had some issues; 
    turned out to be a bit fiddly for the user

### Issues

- How to prevent the situation when, if a mine and the factory aligns, just create one
  long station that connects them both?
    1. In map generation, make sure that related resources aren't spawning less than X
       tiles from each other, where X is the maximum platform length
       - puts restrictions on map generation
       + this might be wanted anyway; regardless of solution, not much fun if source
         and target are too close to each other. Also unrealistic to even consider
         transferring wares via train if that is the case.
- If there is a platform max length, 
  1. what to do if placing a station just outside the station max length?
    1. Create a new platform there. If so, has to make sure that we visualize the end
       of platforms.
  2. what to do if connecting two stations of length X-2 with a new rail?
    1. Extend one of them. Might lead to platforms changing length. Perhaps not a big
       problem, try it out.

### Bugs
- cities can be built on water and mountains
- creating track at end of station back diagonally along station removes
  platform from one too many tracks
- wagons sometimes unloaded in the wrong direction
  - probably because i don't distinguish between wagon rotated w/e and n/s

### In-game upgrades
- range of stations (start with 1) - though it looks ugly when they are too far from ore
- number of trains (start with 1)
- map size
- the ability to tear down/build track on mountain
- bridges
- train loading speed
- platform max length/train max length

### Between-round upgrades
- starting everything above
- amount of ore per tile

## Z-order

Front to back. Keep all below 0, so if new scenes do not have a z order assigned,
they will always be in front.

    -100 GUI (probably not needed, always in front)
    -100 Popup (probably not needed, always in front)
    -150 TrackCreationArrow
    -200 GhostStation
    -200 GhostTrack
    -200 GhostPlatform
    -200 GhostLight
    -200 DestroyMarker

    -350 Train
    -375 Station (building)
    -400 Track (rail)
    -450 Track (sleepers)
    -600 Station (platform)
    -600 Platform
    -650 Factory
    -700 Ore
    -725 City
    -750 Wall
    -800 Water
    -850 Sand
    -900 Background
