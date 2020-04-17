//
//  WCSession+SPM.h
//  SeattleParkingMap
//
//  Created by Marc on 3/17/18.
//  Copyright © 2018 Tap Light Software. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

// Helpful wrappers for WCSession that do status checking and error logging
@interface WCSession (SPM)

@property (nonatomic, readonly) NSString *SPMWatchWarningMessageEnableNotifications;

- (void)SPMSendMessage:(NSDictionary *)message;
- (void)SPMSendMessage:(NSDictionary<NSString *, id> *)message
          replyHandler:(nullable void (^)(NSDictionary<NSString *, id> *replyMessage))replyHandler
          errorHandler:(nullable void (^)(NSError *error))errorHandler;

@end

NS_ASSUME_NONNULL_END
