//
//  RootViewController.h
//  Seattle Parking Map
//
//  Created by Marc on 6/5/14.
//  Copyright (c) 2014 Tap Light Software. All rights reserved.
//

@class ParkingTimeLimit;

/// Where are we setting the parking spot from?
typedef NS_ENUM(NSUInteger, SPMParkingSpotActionSource)
{
    SPMParkingSpotActionSourceApplication,
    SPMParkingSpotActionSourceWatch,
    SPMParkingSpotActionSourceNotification,
    SPMParkingSpotActionSourceQuickAction
};

@interface RootViewController : UIViewController

- (void)synchronizeParkingSpotDisplayFromDataStore;

- (void)removeParkingSpotFromSource:(SPMParkingSpotActionSource)source;
- (BOOL)setParkingSpotInCurrentLocationFromSource:(SPMParkingSpotActionSource)source
                                        timeLimit:(nullable ParkingTimeLimit *)timeLimit
                                            error:(NSError * _Nullable * _Nullable)error;
- (BOOL)setParkingSpotInCurrentLocationFromSource:(SPMParkingSpotActionSource)source
                                            error:(NSError * _Nullable * _Nullable)error;

@end
