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

                                     if ([message[SPMWatchNeedsComplicationUpdate] boolValue])
                                     {
                                         NSLog(@"Device->Watch attempting fallback SPMTransferCurrentComplicationUserInfo to update complication");
                                         [self SPMTransferCurrentComplicationUserInfo:message];
                                     }
                                 }];
    }
    else
    {
        if ([message[SPMWatchNeedsComplicationUpdate] boolValue])
        {
            SPMLog(@"Device->Watch attempting fallback SPMTransferCurrentComplicationUserInfo to update complication");
            [self SPMTransferCurrentComplicationUserInfo:message];
        }
    }
}

- (void)SPMTransferCurrentComplicationUserInfo:(nonnull NSDictionary *)userInfo
{
    NSParameterAssert(userInfo);
    if (!userInfo)
    {
        return;
    }
    
    SPMLog(@"Device->Watch transferCurrentComplicationUserInfo: %@", userInfo);
    
    if (WCSession.defaultSession.isComplicationEnabled && WCSession.defaultSession.activationState == WCSessionActivationStateActivated)
    {
        NSUInteger remaining = WCSession.defaultSession.remainingComplicationUserInfoTransfers;
        
        SPMLog(@"Device->Watch remainingComplicationUserInfoTransfers %lu", (unsigned long)remaining);
        
        NSArray *outstandingTransfers = WCSession.defaultSession.outstandingUserInfoTransfers;
        if (outstandingTransfers.count > 0)
        {
            SPMLog(@"Device->Watch outstanding user info transfers: %@", outstandingTransfers);
        }
        
        if (remaining > 0)
        {
            [WCSession.defaultSession transferCurrentComplicationUserInfo:userInfo];
        }
        else
        {
            SPMLog(@"Device->Watch warning, using transferUserInfo instead!");
            [WCSession.defaultSession transferUserInfo:userInfo];
        }
    }
    else
    {
        SPMLog(@"Watch is not activated (state: %lu) or complications are not enabled (%@)", (unsigned long)WCSession.defaultSession.activationState, @(WCSession.defaultSession.isComplicationEnabled));
    }
}

- (nonnull NSString *)SPMWatchWarningMessageEnableNotifications
{
    return NSLocalizedString(@"Please enable notifications on your iPhone to be reminded when your time limit is about to expire.", nil);
}

@end
