//
//  ExtensionDelegate.h
//  SeattleParkingMapWatch Extension
//
//  Created by Marc on 11/15/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

@class ParkingSpot;

static NSString * _Nonnull const SPMWatchSessionNotificationReceivedMessage = @"SPMWatchSessionNotificationReceivedMessage";

@import WatchConnectivity;

@interface ExtensionDelegate : NSObject <WKExtensionDelegate>

/// For Glance
- (void)establishSession;

@property (nonatomic, readonly, getter=isCurrentSpotLoaded) BOOL currentSpotLoaded;
@property (nullable, nonatomic) ParkingSpot *currentSpot;
@property (nullable, nonatomic) NSNumber *userDefinedParkingTimeLimit;

@end
