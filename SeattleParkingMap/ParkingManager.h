//
//  ParkingManager.h
//  SeattleParkingMap
//
//  Created by Marc on 12/21/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

@class ParkingSpot;

@interface ParkingManager : NSObject

+ (nonnull instancetype)sharedManager;

- (void)scheduleTimeLimitNotifications;

- (nullable CLLocation *)locationFromAGSPoint:(nonnull AGSPoint *)parkingPoint;
- (nullable AGSPoint *)pointFromLocation:(nonnull CLLocation *)location;

@property (nullable, nonatomic) ParkingSpot *currentSpot;
@property (nullable, nonatomic) NSNumber *userDefinedParkingTimeLimit;

@end
