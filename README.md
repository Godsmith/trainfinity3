# Trainfinity

## Features
- Stations built next to producers will be filled over time depending on the resource:
	- Mines produce coal or iron
	- Forests produce wood
	- Cities produce mail
	- Steelworks produce steel if supplied with coal and iron
- Stations built next to consumers will accept resources:
	- Factories accept wood and steel
	- Cities accept mail
	- Steelworks accept coal and iron
- Industries pay for resources depending on
  - how far the closest producer is
  - the resource tier
- Prices increase with the number of objects built
- Trains can turn around when stopped at platforms but not elsewhere
- Trains avoid oncoming trains by choosing sidetracks when available

## Controls
- To build track, select Track and click start and then waypoint positions.
	- Click on the same position twice to build,
	- click a previous position to revert,
	- or click the starting position to abort.
- Select Station and click an empty location (preferrably next to a resource) to build a station
- Platforms are automatically built on track next to stations
- Select Train and click two platforms in succession to create a train and a route.
  - Train length is equal to the shortest platform length
- Select Destroy and either click on a location or drag to select an area to destroy
- Modes can also be selected with the number keys, or Escape for Select mode

## Credits

### Music

- [Next to you - Joth](https://opengameart.org/content/next-to-you)

### Audio

- [Coin Splash - LordTomorrow](https://opengameart.org/content/coin-splash)

## TODO

- cities do not consume goods, left at station
- make camera movement less jerky
- Prevent focusing on expand buttons
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

- train might get stuck in WAITING_FOR_TRACK_RESERVATION_CHANGE when starting from
  station
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
