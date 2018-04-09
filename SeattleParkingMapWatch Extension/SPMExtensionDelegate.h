//
//  SPMExtensionDelegate.h
//  SeattleParkingMapWatch Extension
//
//  Created by Marc on 11/15/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

static NSString * const SPMWatchSessionNotficationReceivedMessage = @"SPMWatchSessionNotficationReceivedMessage";

@import WatchConnectivity;

@interface SPMExtensionDelegate : NSObject <WKExtensionDelegate>

/// For Glance
- (void)establishSession;

@property (nonatomic) NSDictionary *lastParkingSpot;

@end
