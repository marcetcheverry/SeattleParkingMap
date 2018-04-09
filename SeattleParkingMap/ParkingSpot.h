//
//  ParkingSpot.h
//  SeattleParkingMap
//
//  Created by Marc on 12/21/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

#import "WatchConnectivitySerialization.h"

@class ParkingTimeLimit;

@class AGSPoint;

@interface ParkingSpot : NSObject <WatchConnectivitySerialization>

- (nullable instancetype)initWithLocation:(nonnull CLLocation *)parkingSpot
                                     date:(nonnull NSDate *)date;

- (BOOL)isEqualToParkingSpot:(nonnull ParkingSpot *)parkingSpot;

- (BOOL)wasParkedToday;

/// Includes 'at' prefix for curent day times, otherwise just the output of NSDateFormatter
- (nullable NSString *)localizedDateString;

@property (nonnull, nonatomic, readonly) NSDate *date;
@property (nonnull, nonatomic, readonly) CLLocation *location;
@property (nullable, nonatomic) ParkingTimeLimit *timeLimit;
/// From CLPlacemark.thouroughFare + subThoroughfare
@property (nullable, nonatomic) NSString *address;

@end

