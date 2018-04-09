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
- (nonnull NSString *)localizedDateString;

/**
 *  Return the full absolute localized date. Useful for sharing to contexts outside of the app.
 *
 *  @return A `NSString` without any prefixes.
 */
- (nonnull NSString *)localizedAbsoluteDateString;

@property (nonnull, nonatomic, readonly) NSDate *date;
@property (nonnull, nonatomic, readonly) CLLocation *location;
@property (nullable, nonatomic) ParkingTimeLimit *timeLimit;
/// From CLPlacemark.thouroughFare + subThoroughfare
@property (nullable, nonatomic) NSString *address;

@end

