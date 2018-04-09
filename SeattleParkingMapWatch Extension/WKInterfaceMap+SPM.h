//
//  WKInterfaceMap+SPM.h
//  SeattleParkingMap
//
//  Created by Marc on 12/14/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

@class ParkingSpot;

@interface WKInterfaceMap (SPM)

- (void)SPMSetCurrentParkingSpot:(nonnull ParkingSpot *)parkingSpot;

@end
