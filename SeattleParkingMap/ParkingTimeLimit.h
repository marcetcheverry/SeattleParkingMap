//
//  ParkingTimeLimit.h
//  SeattleParkingMap
//
//  Created by Marc on 12/21/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

#import "WatchConnectivitySerialization.h"

typedef NS_ENUM(NSUInteger, SPMParkingTimeLimitThreshold)
{
    SPMParkingTimeLimitThresholdExpired,
    SPMParkingTimeLimitThresholdWarning,
    SPMParkingTimeLimitThresholdUrgent,
    SPMParkingTimeLimitThresholdSafe,
};

typedef NS_ENUM(NSUInteger, SPMParkingTimeLimitSetActionPath)
{
    SPMParkingTimeLimitSetActionPathWarn,
    SPMParkingTimeLimitSetActionPathAsk,
    SPMParkingTimeLimitSetActionPathSet
};

@interface ParkingTimeLimit : NSObject <WatchConnectivitySerialization>

/// Will use the default reminderThreshold if null
- (nullable instancetype)initWithStartDate:(nonnull NSDate *)startDate
                                    length:(nonnull NSNumber *)length
                         reminderThreshold:(nullable NSNumber *)reminderThreshold;

@property (nonnull, nonatomic, readonly) NSDate *startDate;
@property (nonnull, nonatomic, readonly) NSDate *endDate;
@property (nonnull, nonatomic, readonly) NSNumber *length;
@property (nonnull, nonatomic, readonly) NSNumber *reminderThreshold;

- (BOOL)isEqualToParkingTimeLimit:(nonnull ParkingTimeLimit *)timeLimit;

- (NSTimeInterval)remainingTimeInterval;
- (BOOL)isExpired;
- (BOOL)isExpiring;
- (nonnull NSDate *)dateForThreshold:(SPMParkingTimeLimitThreshold)threshold;
- (NSTimeInterval)timeIntervalForThreshold:(SPMParkingTimeLimitThreshold)threshold;

/// Includes 'at' prefix for curent day times, otherwise just the output of NSDateFormatter
- (nullable NSString *)localizedEndDateString;

- (nullable NSString *)localizedLengthString;
- (nullable NSString *)localizedExpiredAgoString;

// Shared with the watch, perhaps could be moved to the ParkingManager
+ (nonnull NSMutableOrderedSet *)defaultLengthTimeIntervals;
+ (void)creationActionPathForParkDate:(nonnull NSDate *)parkDate
                          timeLimitLength:(nonnull NSNumber *)length
                                  handler:(void (^ __nonnull)(SPMParkingTimeLimitSetActionPath actionPath,
                                                              NSString * __nullable alertTitle,
                                                              NSString * __nullable alertMessage))handler;
@end

@interface NSDate (SPMParkingTimeLimit)

/// Includes 'at' prefix for curent day times, otherwise just the output of NSDateFormatter
- (nullable NSString *)SPMLocalizedRelativeString;

@end
