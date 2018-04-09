//
//  ParkingSpot+Watch.h
//  SeattleParkingMap
//
//  Created by Marc on 3/17/18.
//  Copyright © 2018 Tap Light Software. All rights reserved.
//

#import "ParkingSpot.h"

static NSTimeInterval const SPMComplicationEntryInterval = 60;

@interface ParkingSpot (Watch)

- (nullable NSDate *)nextComplicationUpdateDate;
- (nullable NSDate *)complicationStartDate;
- (nullable NSDate *)complicationEndDate;

@end
