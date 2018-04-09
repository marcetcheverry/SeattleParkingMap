//
//  ParkingTimeLimit+Watch.m
//  SeattleParkingMap
//
//  Created by Marc on 1/1/16.
//  Copyright © 2016 Tap Light Software. All rights reserved.
//

#import "ParkingTimeLimit+Watch.h"

@implementation ParkingTimeLimit (Watch)

- (NSTimeInterval)remainingTimeIntervalAtDate:(nonnull NSDate *)date
{
    NSParameterAssert(date);
    return [self.endDate timeIntervalSinceDate:date];
}

- (nullable UIColor *)textColorForThreshold:(SPMParkingTimeLimitThreshold)threshold
{
    if (threshold == SPMParkingTimeLimitThresholdExpired)
    {
        // Yellow
        return [UIColor colorWithRed:0.998 green:0.881 blue:0.001 alpha:1];
    }
    else if (threshold == SPMParkingTimeLimitThresholdUrgent)
    {
        // Red
        return [UIColor colorWithRed:1 green:0.132 blue:0 alpha:1];
    }
    else if (threshold == SPMParkingTimeLimitThresholdWarning)
    {
        // Orange
        //        return [UIColor colorWithRed:1 green:0.601 blue:0.083 alpha:1];
        // Yellow
        return [UIColor colorWithRed:0.998 green:0.881 blue:0.001 alpha:1];
    }

    return nil;
}

- (nonnull UIColor *)textColor
{
    return [self textColorAtDate:[NSDate date]];
}

- (nonnull UIColor *)textColorAtDate:(nonnull NSDate *)date
{
    NSParameterAssert(date);

    if (!date)
    {
        return nil;
    }

    NSTimeInterval timeInterval = [self remainingTimeIntervalAtDate:date];

    // Expired
    if (timeInterval <= [self timeIntervalForThreshold:SPMParkingTimeLimitThresholdExpired])
    {
        return [self textColorForThreshold:SPMParkingTimeLimitThresholdExpired];
    }
    else if (timeInterval <= [self timeIntervalForThreshold:SPMParkingTimeLimitThresholdUrgent])
    {
        return [self textColorForThreshold:SPMParkingTimeLimitThresholdUrgent];
    }
    else if (timeInterval <= [self timeIntervalForThreshold:SPMParkingTimeLimitThresholdWarning])
    {
        return [self textColorForThreshold:SPMParkingTimeLimitThresholdWarning];
    }

    // Yellow
    //    return [UIColor colorWithRed:0.998 green:0.881 blue:0.001 alpha:1];
    return [UIColor whiteColor];
}

@end
