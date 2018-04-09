//
//  ParkingTimeLimit+Watch.h
//  SeattleParkingMap
//
//  Created by Marc on 1/1/16.
//  Copyright © 2016 Tap Light Software. All rights reserved.
//

#import "ParkingTimeLimit.h"

@interface ParkingTimeLimit (Watch)

- (NSTimeInterval)remainingTimeIntervalAtDate:(nonnull NSDate *)date;
- (nullable UIColor *)textColorForThreshold:(SPMParkingTimeLimitThreshold)threshold;
- (nonnull UIColor *)textColorAtDate:(nonnull NSDate *)date;
- (nonnull UIColor *)textColor;

@end
