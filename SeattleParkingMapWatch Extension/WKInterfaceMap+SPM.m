//
//  WKInterfaceMap+SPM.m
//  SeattleParkingMap
//
//  Created by Marc on 12/14/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

#import "WKInterfaceMap+SPM.h"

@implementation WKInterfaceMap (SPM)

- (void)SPMSetCurrentParkingSpot:(nonnull NSDictionary *)parkingSpot
{
    NSParameterAssert(parkingSpot[SPMWatchObjectParkingPoint] != nil);

    if (parkingSpot[SPMWatchObjectParkingPoint] == nil)
    {
        return;
    }

    [self removeAllAnnotations];

    CLLocationCoordinate2D const coordinate = CLLocationCoordinate2DMake([parkingSpot[SPMWatchObjectParkingPoint][SPMWatchObjectParkingPointLatitude] doubleValue],
                                                                         [parkingSpot[SPMWatchObjectParkingPoint][SPMWatchObjectParkingPointLongitude] doubleValue]);

    [self addAnnotation:coordinate
           withPinColor:WKInterfaceMapPinColorRed];
    [self setRegion:MKCoordinateRegionMakeWithDistance(coordinate, 500, 500)];
}

@end
