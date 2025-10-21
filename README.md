# Trainfinity

## Features
- Stations built next to producers will be filled over time depending on the resource:
	- Mines produce coal or iron
	- Forests produce wood
	- Cities produce mail
- Stations built next to consumers will accept resources:
	- Factories accept wood and steel
	- Steelworks accept coal and iron and produce steel
	- Cities accept mail
- Prices increase with the number of objects built
- Trains can turn around when stopped at platforms but not elsewhere
- Trains avoid oncoming trains by choosing sidetracks when available

## Controls
- To build track, select Track and either click start and then end positions, or drag from start
  position to end position
- Select Station and click an empty location (preferrably next to a resource) to build a station
- Platforms are automatically built on track next to stations
- Select Train and click two platforms in succession to create a train and a route.
  - Train length is equal to the shortest platform length
- Select Destroy and either click on a location or drag to select an area to destroy
- Modes can also be selected with the number keys (1 to build track etc)

## Credits

### Music

- [Next to you - Joth](https://opengameart.org/content/next-to-you)

### Audio

- [Coin Splash - LordTomorrow](https://opengameart.org/content/coin-splash)

## TODO

- make bank nonglobal again and use signals to communicate to gui instead
- if a new track is built next to a train that is blocked, it should evaluate that new track as well
- steelworks only produce when they get coal and iron
- pop up the change in money when buying something
- more sound effects and music
- disallow building out of bounds
- expand building area
- different prices and production rate for different goods
- cities consume only OTHER cities' mail
- refactoring: fix so that Game does not use so many internal methods and properties on 
  train and wagon
- help menu showing the controls
- train should mark the tile it wants to go to when it cannot find path
  - either when you select the train, or it can create a red line to the taget
- change graphics for end of platform, so it can't look like two stations are one
  large platform
- producers/consumers of the same resource not less apart than the longest station length (5 tiles?)
- expand map, adding new resources
- show ghost platforms when building station
- show ghost platforms when building track
- heavier trains should have slower acceleration
- change train paths when changing length of starting or ending station
- prevent scrolling past edges of the map
  - note that duplicating the map size and zooming out max makes the game stutter, so adjustments needed. 
	At least in debug mode, need to test performance after exporting as well.
- saving the game
  - will be useful for debugging as well, since can load into a certain state
- run in the browser

### Thinking about it

- one-way rail
- train collisions
- signals

### Discarded ideas

- build platforms instead of stations
  - done on create-platform-like-track branchs, had some issues; 
	turned out to be a bit fiddly for the user

### Issues

- Creating a train on top of another train that is entering a station crashes the game
- Circular tracks with multiple train do not work since they will block each other,
  and if you artificially split it up into segments trains will probably get deadlocked.
  - Need one-way signs to avoid this.
- Wagons fill from the wrong way around again
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
- When creating and removing rail, sometimes existing stations will be unexpectedly 
  rejigged.

### In-game upgrades
- range of stations (start with 1) - though it looks ugly when they are too far from ore
- number of trains (start with 1)
- map size
- the ability to tear down/build track on mountain
- bridges
- train loading speed
- platform max length/train max length
- expand map
- station max capacity

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
