//
//  ExtensionDelegate.h
//  SeattleParkingMapWatch Extension
//
//  Created by Marc on 11/15/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

@class ParkingSpot;

static NSString * _Nonnull const SPMWatchSessionNotificationReceivedMessage = @"SPMWatchSessionNotificationReceivedMessage";

@import WatchConnectivity;

@interface ExtensionDelegate : NSObject <WKExtensionDelegate>

- (void)sendMessageToPhone:(NSDictionary<NSString *, id> *)message
              replyHandler:(nullable void (^)(NSDictionary<NSString *, id> *replyMessage))replyHandler
              errorHandler:(nullable void (^)(NSError *error))errorHandler;

@property (nullable, nonatomic) ParkingSpot *currentSpot;
@property (nullable, nonatomic) NSNumber *userDefinedParkingTimeLimit;

@end

NS_ASSUME_NONNULL_END
