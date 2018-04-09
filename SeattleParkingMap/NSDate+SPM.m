//
//  NSDate+SPM.m
//  SeattleParkingMap
//
//  Created by Marc on 1/5/16.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

#import "NSDate+SPM.h"

@implementation NSDate (SPM)

- (BOOL)SPMIsBeforeDate:(nonnull NSDate *)date
{
    NSParameterAssert(date);

    NSComparisonResult result = [self compare:date];
    if (result == NSOrderedAscending)
    {
        return YES;
    }

    return NO;
}

- (BOOL)SPMIsAfterDate:(nonnull NSDate *)date
{
    NSParameterAssert(date);

    NSComparisonResult result = [self compare:date];
    if (result == NSOrderedDescending)
    {
        return YES;
    }

    return NO;
}

- (BOOL)SPMIsEqualOrBeforeDate:(nonnull NSDate *)date
{
    NSParameterAssert(date);

    NSComparisonResult result = [self compare:date];
    if (result == NSOrderedAscending || result == NSOrderedSame)
    {
        return YES;
    }

    return NO;
}

- (BOOL)SPMIsEqualOrAfterDate:(nonnull NSDate *)date
{
    NSParameterAssert(date);

    NSComparisonResult result = [self compare:date];
    if (result == NSOrderedDescending || result == NSOrderedSame)
    {
        return YES;
    }
    
    return NO;
}

@end
