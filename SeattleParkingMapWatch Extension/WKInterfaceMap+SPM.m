//
//  WKInterfaceMap+SPM.m
//  SeattleParkingMap
//
//  Created by Marc on 12/14/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

#import "WKInterfaceMap+SPM.h"

#import "ParkingSpot.h"

@implementation WKInterfaceMap (SPM)

- (void)SPMSetCurrentParkingSpot:(nonnull ParkingSpot *)parkingSpot
{
    NSParameterAssert(parkingSpot);

    [self removeAllAnnotations];

    if (!parkingSpot)
    {
        return;
    }

    CLLocationCoordinate2D const coordinate = parkingSpot.location.coordinate;

    [self addAnnotation:coordinate
           withPinColor:WKInterfaceMapPinColorRed];
    [self setRegion:MKCoordinateRegionMakeWithDistance(coordinate, 500, 500)];
}

@end
