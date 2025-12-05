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

- Complete save and load functionality
  - Disable continue button if no saved game
  - Remove load button
  - Visual feedback after clicking save game button
- Main menu
- HTML5 version crashes when playing audio
- Support two-finger panning and zooming
- New way of laying track
  - remove drag and drop
  - click each node
  - pathfind between
  - click previous node to revert
  - click latest node again to confirm and build? or just build immediately?
- Missions
  	- Deliver first of each cargo
  	- Something that requires actually working production lines:
  	  	- Deliver 100 of each cargo
  		- Deliver X of each cargo in Y minutes 
  	- Missions should give a large chunk of money, or an upgrade point
- Train does not complain about no platform at destination if target is removed
  when it is not the active destination
- Show N/A instead of MAX_INT as price of a resource when no industry is producing it
- Automatically extend platforms when upgrading maximum platform length
- Make factory produce goods and cities accept goods
- more sound effects and music
- different prices and production rate for different goods
- cities consume only OTHER cities' mail, and mail is priced accordingly
- help menu showing the controls
- train should mark the tile it wants to go to when it cannot find path
  - either when you select the train, or it can create a red line to the taget
- change graphics for end of platform, so it can't look like two stations are one
  large platform
- show ghost platforms when building station
- show ghost platforms when building track
- heavier trains should have slower acceleration
- change train paths when changing length of starting or ending station

### Issues

- Newly created trains without wagons will be invisible until they start moving
- Delivering coal to a steelworks when it cannot consume it fills the steelworks
  station with coal, which looks funny and means it cannot produce steel once it gets
  iron. Acceptance criteria:
  1. Some coal must be accepted before iron is allowed
	 - probably infinitely much coal, in case it takes time to get iron. Ok if
	   price decreases though. Perhaps up to half (or less?) if station full?
  2. At least some coal should be able to be kept for some time until iron is delivered
  Solution proposals:
  1. Have a limited per-resource capacity
  - Feels unrealistic
  2. Keep accepted resources in industry instead
  - Resources in two places feels messy
  + More realistic, stations are not really warehouses for industries
  - would be more reason to increase station capacity
  2.1. infinite industry capacity
  - feels unrealistic
  2.2 finite industry capacity
  - feels like something you should be able to upgrade, but can't be
  -- would still lead to the same issue if you didn't have per-resource capacity
  3. Do not look at station max capacity when producing stuff
  - would make it possible to create a station and just leave it there
  4. Resource creation speed depends on the number of resources of that type in the 
	station
  - feels a little bit unrealistic
  + but not too bad, makes sense that an industry should not produced stuff that 
	can't be moved away
  - would make the optimal choice to create multiple stations (but could be mitigated
	by looking at all the adjacent stations)
  - does not solve the problem of stations getting a large number of things shipped in
  5. Allow that a train delivers more than the maximum capacity, but destroy the excess.
  In summary, if we don't have a resource limitation per station then we can just ship 
  in an infinite number of resources. So there needs to be a limit. But if we have a
  total limit, you could block one type of resource with another type of resource.
- Looks like there might still be a problem with trains picking up mail that they
  just left at a station
- Changing a platform length to 1 puts wagon on top of train engine
  - Test also reducing platform length to less than train length to confirm that this
	has the same effect
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
	-750 Wall
	-800 Water
	-850 Sand
	-900 Background
