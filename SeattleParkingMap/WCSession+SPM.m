//
//  WCSession+SPM.m
//  SeattleParkingMap
//
//  Created by Marc on 3/17/18.
//  Copyright © 2018 Tap Light Software. All rights reserved.
//

#import "WCSession+SPM.h"

@implementation WCSession (SPM)

- (void)SPMSendMessage:(nonnull NSDictionary *)message
{
    [self SPMSendMessage:message
            replyHandler:nil
            errorHandler:nil];
}

- (void)SPMSendMessage:(NSDictionary<NSString *, id> *)message
          replyHandler:(nullable void (^)(NSDictionary<NSString *, id> *replyMessage))replyHandler
          errorHandler:(nullable void (^)(NSError *error))errorHandler
{
    
    NSParameterAssert(message);
    if (!message)
    {
        return;
    }
    
    if (![WCSession isSupported])
    {
        return;
    }

    SPMLog(@"Device->Watch Message (reachable %@, activationState %lu): %@", @(WCSession.defaultSession.isReachable), (unsigned long)WCSession.defaultSession.activationState, message);

    if (WCSession.defaultSession.isReachable && WCSession.defaultSession.activationState == WCSessionActivationStateActivated)
    {
        [WCSession.defaultSession sendMessage:message
                                 replyHandler:^(NSDictionary<NSString *,id> * _Nonnull replyMessage) {
                                     if (replyHandler)
                                     {
                                         replyHandler(replyMessage);
                                     }
                                 }
                                 errorHandler:^(NSError * _Nonnull sessionError) {
                                     NSLog(@"Could not send message to watch: %@. Message: %@", sessionError, message);
                                     if (errorHandler)
                                     {
                                         errorHandler(sessionError);
                                     }
                                 }];
    }
}

- (nonnull NSString *)SPMWatchWarningMessageEnableNotifications
{
    return NSLocalizedString(@"Please enable notifications on your iPhone to be reminded when your time limit is about to expire.", nil);
}

@end
