# Features
* Search
* Current parking spot widget
* Neighborhood list
* Parking prices on tap
* Sharing location
* Break-in events
* Navigation mode (AGSLocationDisplayAutoPanModeCompassNavigation) (compass icon)

## Watch
* 10 minute time intervals circular timer does not look OK
* Move App side Watch Connectivity to ParkingManager
* Use NSUserDefaults app group for communication?
* Custom Transit.app inspired loading indicator
* See if we can use haptic feedback when the time limit reaches critical points
* Custom notification sounds (when they are supported)
* Use WKAlerts instead of groups for loading per Apple's recommendation?

## Code Style
* Use KVO on ParkingSpot rather than notifications on Watch
* Use single fetch parking spot mechanism with KVO (on ExtensionDelegate/ParkInterfaceController)
* Enable Bitcode when ArcGIS supports it
* Restrict App Transport Security based on ArcGIS OSM/Bing instructions

## Minor
* Flurry Watch Analytics
* See if we can cache street parking layer
* Fix issue with native labels in SDOT