# Features by Priority
1. Search for streets
2. Garages and Parking prices on tap
3. Custom rendering based on raw GIS data
4. Anti-alias street parking layer

## Watch
* Move App side Watch Connectivity to ParkingManager
* Use NSUserDefaults app group for communication?
* Custom Transit.app inspired loading indicator
* See if we can use haptic feedback when the time limit reaches critical points
* Custom notification sounds (when they are supported)
* Use WKAlerts instead of groups for loading per Apple's recommendation?

## Code Style
* Use KVO on ParkingSpot rather than notifications on Watch
* Use single fetch parking spot mechanism with KVO (on ExtensionDelegate/ParkInterfaceController)

## Minor
* Scroll to neighborhood that is selected on appearance
* Custom loading screen while map loads
* Change basemap and don't reload entire map when changing map sources. The legend must not be reset either
* Current parking spot widget
* Sharing location
* Break-in events
