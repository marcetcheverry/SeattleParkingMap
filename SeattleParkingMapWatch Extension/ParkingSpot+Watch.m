//
//  ParkingSpot+Watch.m
//  SeattleParkingMap
//
//  Created by Marc on 3/17/18.
//  Copyright © 2018 Tap Light Software. All rights reserved.
//

#import "ParkingSpot+Watch.h"

#import "ParkingTimeLimit+Watch.h"

@implementation ParkingSpot (Watch)

- (nullable NSDate *)nextComplicationUpdateDate
{
    if (!self.timeLimit)
    {
        return nil;
    }

    NSTimeInterval timeInterval = [self.timeLimit remainingTimeIntervalAtDate:[NSDate date]];

    NSTimeInterval warningInterval = [self.timeLimit timeIntervalForThreshold:SPMParkingTimeLimitThresholdWarning];
    NSTimeInterval urgentInterval = [self.timeLimit timeIntervalForThreshold:SPMParkingTimeLimitThresholdWarning];

    if (timeInterval < warningInterval)
    {
        return [self.timeLimit.endDate dateByAddingTimeInterval:-urgentInterval];
    }
    else if (timeInterval < urgentInterval)
    {
        return [self.timeLimit.endDate dateByAddingTimeInterval:1];
    }

    return [self.timeLimit.endDate dateByAddingTimeInterval:-warningInterval];
}

- (nullable NSDate *)complicationStartDate
{
    if (self.timeLimit)
    {
        return [self.date dateByAddingTimeInterval:-(SPMComplicationEntryInterval * 2)];
    }

    return nil;
}

- (nullable NSDate *)complicationEndDate
{
    return [self.timeLimit.endDate dateByAddingTimeInterval:SPMComplicationEntryInterval + 1];
}

@end
