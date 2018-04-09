//
//  SPMExtensionDelegate.m
//  SeattleParkingMapWatch Extension
//
//  Created by Marc on 11/15/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

#import "SPMExtensionDelegate.h"

@interface SPMExtensionDelegate() <WCSessionDelegate>

@property (nonatomic) BOOL applicationHasResignedActive;
@property (nonatomic) BOOL isLoading;

@end

@implementation SPMExtensionDelegate

- (void)applicationDidFinishLaunching
{
    // Perform any final initialization of your application.
    [self establishSession];
}

- (void)applicationDidBecomeActive
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.

    // Avoid the first time, as our root interface will take care of it
    if (self.applicationHasResignedActive)
    {
        [self fetchParkingSpot];
    }
}

- (void)fetchParkingSpot
{
    if (!self.isLoading)
    {
        self.isLoading = YES;
        [[WCSession defaultSession] sendMessage:@{SPMWatchAction: SPMWatchActionGetParkingPoint}
                                   replyHandler:^(NSDictionary<NSString *,id> * _Nonnull replyMessage) {
                                       self.isLoading = NO;

                                       if (![self.lastParkingSpot isEqual:replyMessage])
                                       {
                                           //                             NSLog(@"New parking information received.\nNew: %@\nOld: %@", replyMessage, self.lastParkingSpot);
                                           self.lastParkingSpot = replyMessage;

                                           NSDictionary *message = replyMessage;

                                           // If it is an empty get parking point, convert to a remove action!
                                           if (!message[SPMWatchObjectParkingPoint] &&
                                               [message[SPMWatchResponseStatus] isEqualToString:SPMWatchResponseSuccess])
                                           {
                                               message = [replyMessage mutableCopy];
                                               ((NSMutableDictionary *)message)[SPMWatchAction] = SPMWatchActionRemoveParkingSpot;
                                           }

                                           [[NSNotificationCenter defaultCenter] postNotificationName:SPMWatchSessionNotficationReceivedMessage
                                                                                               object:nil
                                                                                             userInfo:message];
                                       }
                                   }
                                   errorHandler:^(NSError * _Nonnull error) {
                                       self.isLoading = NO;
                                       NSLog(@"Attempt to get new parking information in %@ failed with error %@", NSStringFromSelector(_cmd), error);
                                   }];
    }
}

- (void)applicationWillResignActive
{
    self.applicationHasResignedActive = YES;

    // Sent when the applicatio n is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, etc.
}

- (void)establishSession
{
    WCSession *session = [WCSession defaultSession];
    session.delegate = self;
    [session activateSession];
}

#pragma mark - WCSessionDelegate

- (void)sessionReachabilityDidChange:(WCSession *)session
{
    if (session.isReachable)
    {
        [self fetchParkingSpot];
    }
    else
    {
        NSLog(@"Watch session has become unreachable %@", session);
    }
}

- (void)session:(WCSession *)session didReceiveMessage:(NSDictionary<NSString *, id> *)message
{
    if ([message[SPMWatchAction] isEqualToString:SPMWatchActionRemoveParkingSpot])
    {
        self.lastParkingSpot = nil;
    }
    else if ([message[SPMWatchAction] isEqualToString:SPMWatchActionGetParkingPoint])
    {
        self.lastParkingSpot = message;
    }
    else if ([message[SPMWatchAction] isEqualToString:SPMWatchActionSetParkingSpot])
    {
        self.lastParkingSpot = message;
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:SPMWatchSessionNotficationReceivedMessage
                                                        object:nil
                                                      userInfo:message];
}

@end
