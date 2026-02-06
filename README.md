# Trainfinity

A 2D train management and logistics game built with Godot 4.5. Build railway networks to transport resources across a procedurally generated terrain.

## Overview

### Resource Production
- **Mines**: Produce coal or iron
- **Forests**: Produce wood
- **Cities**: Produce mail
- **Steelworks**: Produce steel (requires coal and iron)

### Resource Consumption
- **Factories**: Accept wood and steel
- **Cities**: Accept mail
- **Steelworks**: Accept coal and iron

### Economy
- Industries pay for resources based on distance from producer and resource tier
- Money pays for increased track, station and train limits, as well as other upgrades

### Train Operations
- Trains transport cargo between stations via platforms
- Can turn around at platforms but not elsewhere
- Automatic collision avoidance using sidetracks
- Train length matches shortest platform in route

## Controls

### Building
- **Track**: Click start position, then waypoints. Click again at last waypoint to build, click previous position to undo, or click the start position to abort
- **Station**: Click empty location (preferably next to industry)
- **Platforms**: Automatically built on track adjacent to stations
- **Train**: Click two platforms in succession to create train and route
- **Destroy**: Click location or drag to destroy all in area

### Shortcuts
- Number keys to select build modes
- Escape for Select mode

## Technical Details

### Engine & Framework
- **Godot 4.5** with Forward Plus rendering
- **GDScript** for game logic
- **GUT (Godot Unit Test)** framework for testing

### Systems
- A* pathfinding for track building and train routing
- Chunk-based procedural terrain generation
- Track reservation system for collision avoidance
- Dynamic platform generation
- Save/load functionality

### Testing
Run tests from command line:
```bash
godot -s addons/gut/gut_cmdln.gd -gexit
```

## Credits

### Music
- [Next to you - Joth](https://opengameart.org/content/next-to-you)

### Audio
- [Coin Splash - LordTomorrow](https://opengameart.org/content/coin-splash)

## TODO

- cities do not consume goods, left at station
- Music and sound effect volume/toggle
- Terrain tiles are sometimes blank when created
- Missions
  	- Deliver first of each cargo
  	- Something that requires actually working production lines:
  	  	- Deliver 100 of each cargo
  		- Deliver X of each cargo in Y minutes 
  	- Missions should give a large chunk of money, or an upgrade point
- Bridges
- Prevent resources and consumers to be closer than max possible station length to
  another, so that it does not become trivial
- Show N/A instead of MAX_INT as price of a resource when no industry is producing it
- more sound effects and music
- different production rate for different goods
- temporary subsidies
- different production rates for different individual industries
- cities consume only OTHER cities' mail, and mail is priced accordingly (today always
  $1)
- change graphics for end of platform, so it can't look like two stations are one
  large platform
- heavier trains should have slower acceleration

#### Mobile version

- Support two-finger panning and zooming
- Menus are too small
- Improve building rail
  - No indication of starting to build rail
- Confirm placing station?

#### HTML version


### Issues

- Track pricing is unpredictable and not refunded.
- If there are multiple stations accepting the same thing adjacent to a platform, the
  train will be paid twice
- Music does not loop seamlessly
- When an industry is selected and a new chunk is bought, any changed prices will
  not be reflected in the description label until industry is reselected
- Newly created trains without wagons will be invisible until they start moving
- chunks can generate with resources inside mountain ranges, but with grass adjacent


### Thinking about it

- signals
- New production chain Forest -> (WOOD) -> Paper Mill -> (PAPER) -> Printing Works -> (GOODS) -> City
- New production chain Farm -> (GRAIN) -> Windmill -> (FLOUR) -> Bakery -> (FOOD) -> City
- New production chain Farm -> (LIVESTOCK) -> Butcher -> (MEAT) or (FOOD) -> City?
- New production chain Forest -> (LOGS) -> Sawmill -> (TIMBER/PLANKS)
- (STEEL) + (COAL) -> Smithy -> (NAILS)
- (NAILS) + (PLANKS) -> ?
- Move from upgrades costing money to upgrades costing upgrade points gained from achievements?
  	- The issues with having them cost money is that you could just let everything run to earn
  	  an infinite amount of money.
	- Upgrades should probably cost one point for the first one, two for the second etc, since that
	  is an established pattern.
- Production rates for individual industries could vary a bit, to encourage exploration
- Production rates for individual industries could vary over time, either based on usage
  or randomly
- Temporary surges in production (X produces at a +100% rate for 30(?) minutes!)

### Discarded ideas

- build platforms instead of stations
  - done on create-platform-like-track branchs, had some issues; 
	turned out to be a bit fiddly for the user
- non-global bank using signals
  - Multiple nodes need to query how much money is available, so signals were not 
	practical.


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
	-800 Terrain
	-900 Background
