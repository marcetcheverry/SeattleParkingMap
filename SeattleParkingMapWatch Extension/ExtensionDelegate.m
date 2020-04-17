//
//  ExtensionDelegate.m
//  SeattleParkingMapWatch Extension
//
//  Created by Marc on 11/15/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

#import "ExtensionDelegate.h"

#import "ParkingSpot.h"
#import "ParkingTimeLimit.h"

#import "ParkInterfaceController.h"

@import ClockKit;
@import UserNotifications;

static void *ExtensionDelegateContext = &ExtensionDelegateContext;

extern NSString * _Nonnull const SPMWatchObjectParkingAddress;

@interface ExtensionDelegate() <WCSessionDelegate, UNUserNotificationCenterDelegate>

@property (nonatomic) BOOL needsToFetchParkingSpot;
@property (atomic) BOOL initialActivationCompleted;
@property (atomic, strong) NSMutableArray <NSDictionary *> *pendingMessages;
@property (nonatomic, readwrite, getter=isCurrentSpotLoaded) BOOL currentSpotLoaded;
@property (nonatomic) BOOL isLoading;

@end

@implementation ExtensionDelegate

#pragma mark - Application Lifecycle

- (void)applicationDidFinishLaunching
{
    UNUserNotificationCenter.currentNotificationCenter.delegate = self;

    // Perform any final initialization of your application.
    [self establishSession];

    [self addObserver:self
           forKeyPath:@"currentSpotLoaded"
              options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld)
              context:ExtensionDelegateContext];
}

- (void)applicationDidBecomeActive
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    
    // Avoid the first time, as our root interface will take care of it
    if (self.needsToFetchParkingSpot)
    {
        self.needsToFetchParkingSpot = NO;
        [self fetchParkingSpot];
    }
}

- (void)applicationWillResignActive
{
    self.needsToFetchParkingSpot = YES;
    
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, etc.
}

#pragma mark - Session

- (void)establishSession
{
    WCSession *session = [WCSession defaultSession];
    session.delegate = self;
    [session activateSession];
    SPMLog(@"Activating Watch Session");
}

#pragma mark - Messaging

- (void)sendMessageToPhone:(NSDictionary<NSString *, id> *)message
              replyHandler:(nullable void (^)(NSDictionary<NSString *, id> *replyMessage))replyHandler
              errorHandler:(nullable void (^)(NSError *error))errorHandler
{
    NSParameterAssert(message);
    if (!message)
    {
        return;
    }
    
    SPMLog(@"Watch->Device Message (reachable %lu, activationState %lu): %@", (unsigned long)WCSession.defaultSession.isReachable, (unsigned long)WCSession.defaultSession.activationState, message);
    
    if (!self.initialActivationCompleted)
    {
        if (!self.pendingMessages)
        {
            self.pendingMessages = [[NSMutableArray alloc] initWithCapacity:1];
        }
        
        SPMLog(@"Watch->Device Message Added to Pending Activation Queue");
        
        [self.pendingMessages addObject:@{@"message": message, @"replyHandler": [replyHandler copy], @"errorHandler": [errorHandler copy]}];
        return;
    }
    
    if (WCSession.defaultSession.isReachable && WCSession.defaultSession.activationState == WCSessionActivationStateActivated)
    {
        [WCSession.defaultSession sendMessage:message
                                 replyHandler:replyHandler
                                 errorHandler:^(NSError * _Nonnull sessionError) {
                                     NSLog(@"Could not send message to device: %@. Message: %@", sessionError, message);
                                     if (errorHandler)
                                     {
                                         errorHandler(sessionError);
                                     }
                                 }];
    }
    else
    {
        NSLog(@"Watch->Device Message Not Sent!");
    }
}

#pragma mark - Time Limit

- (void)setUserDefinedParkingTimeLimit:(NSNumber *)userDefinedParkingTimeLimit
{
    // Note that we use the setter. Test case: have a spot stored in defaults, and the first thing you do is try to set this to nil
    if (_userDefinedParkingTimeLimit != userDefinedParkingTimeLimit)
    {
        _userDefinedParkingTimeLimit = userDefinedParkingTimeLimit;
        
        if (WCSession.defaultSession.activationState == WCSessionActivationStateActivated)
        {
            NSError *error;
            
            [WCSession.defaultSession updateApplicationContext:@{SPMWatchContextUserDefinedParkingTimeLimit: _userDefinedParkingTimeLimit}
                                                         error:&error];
            if (error)
            {
                NSLog(@"Could not update application context from device to watch: %@", error);
            }
        }
        else
        {
            NSLog(@"Device->Watch: could not update application context because activationState is %lu", (unsigned long)WCSession.defaultSession.activationState);
        }
    }
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context == ExtensionDelegateContext)
    {
        if ([keyPath isEqualToString:@"currentSpotLoaded"])
        {
            SPMLog(@"Current spot loaded: %@", @(self.currentSpotLoaded));
        }
    }
}

#pragma mark - Actions

- (void)fetchParkingSpot
{
    if (!self.isLoading)
    {
        self.isLoading = YES;
        [((ExtensionDelegate *)WKExtension.sharedExtension.delegate) sendMessageToPhone:@{SPMWatchAction: SPMWatchActionGetParkingSpot}
                                                                           replyHandler:^(NSDictionary<NSString *,id> * _Nonnull replyMessage) {
                                                                               self.isLoading = NO;
                                                                               NSDictionary *message = replyMessage;
                                                                               
                                                                               // If it is an empty get Parking Spot, convert to a remove action!
                                                                               if ([message[SPMWatchResponseStatus] isEqualToString:SPMWatchResponseSuccess])
                                                                               {
                                                                                   self.userDefinedParkingTimeLimit = message[SPMWatchObjectUserDefinedParkingTimeLimit];
                                                                                   self.currentSpotLoaded = YES;
                                                                                   
                                                                                   if (!message[SPMWatchObjectParkingSpot])
                                                                                   {
                                                                                       message = [replyMessage mutableCopy];
                                                                                       ((NSMutableDictionary *)message)[SPMWatchAction] = SPMWatchActionRemoveParkingSpot;
                                                                                       [[NSNotificationCenter defaultCenter] postNotificationName:SPMWatchSessionNotificationReceivedMessage
                                                                                                                                           object:nil
                                                                                                                                         userInfo:message];
                                                                                       self.currentSpot = nil;
                                                                                   }
                                                                                   else
                                                                                   {
                                                                                       ParkingSpot *newSpot = [[ParkingSpot alloc] initWithWatchConnectivityDictionary:replyMessage[SPMWatchObjectParkingSpot]];
                                                                                       
                                                                                       if (![self.currentSpot isEqual:newSpot])
                                                                                       {
                                                                                           //                             NSLog(@"New parking information received.\nNew: %@\nOld: %@", replyMessage, self.currentSpot);
                                                                                           self.currentSpot = newSpot;
                                                                                       }
                                                                                   }
                                                                               }
                                                                           }
                                                                           errorHandler:^(NSError * _Nonnull error) {
                                                                               self.currentSpotLoaded = YES;
                                                                               self.isLoading = NO;
                                                                               NSLog(@"Attempt to get new parking information in %@ failed with error %@", NSStringFromSelector(_cmd), error);
                                                                           }];
    }
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

- (void)session:(WCSession *)session didReceiveApplicationContext:(NSDictionary<NSString *, id> *)applicationContext
{
    NSNumber *userDefinedlimit = applicationContext[SPMWatchContextUserDefinedParkingTimeLimit];
    if (userDefinedlimit)
    {
        // Avoid the setter which updates the application context
        [self willChangeValueForKey:@"userDefinedParkingTimeLimit"];
        _userDefinedParkingTimeLimit = userDefinedlimit;
        [self didChangeValueForKey:@"userDefinedParkingTimeLimit"];
    }
}

- (void)session:(WCSession *)session didReceiveUserInfo:(NSDictionary<NSString *, id> *)userInfo
{
    if (!self.currentSpotLoaded)
    {
        return;
    }
    
    SPMLog(@"Watch didReceiveUserInfo: %@", userInfo);
    [self session:session didReceiveMessage:userInfo];
}

- (void)session:(WCSession *)session didReceiveMessage:(NSDictionary<NSString *, id> *)message
{
    SPMLog(@"Watch didReceiveMessage: %@", message);
    if ([message[SPMWatchAction] isEqualToString:SPMWatchActionRemoveParkingSpot])
    {
        self.currentSpot = nil;
        self.currentSpotLoaded = YES;
    }
    else if ([message[SPMWatchAction] isEqualToString:SPMWatchActionGetParkingSpot])
    {
        self.currentSpot = [[ParkingSpot alloc] initWithWatchConnectivityDictionary:message[SPMWatchObjectParkingSpot]];
        self.userDefinedParkingTimeLimit = message[SPMWatchObjectUserDefinedParkingTimeLimit];
        self.currentSpotLoaded = YES;
    }
    else if ([message[SPMWatchAction] isEqualToString:SPMWatchActionSetParkingSpot])
    {
        self.currentSpot = [[ParkingSpot alloc] initWithWatchConnectivityDictionary:message[SPMWatchObjectParkingSpot]];
        self.currentSpotLoaded = YES;
    }
    else if ([message[SPMWatchAction] isEqualToString:SPMWatchActionRemoveParkingTimeLimit] ||
             [message[SPMWatchAction] isEqualToString:SPMWatchActionSetParkingTimeLimit])
    {
        NSParameterAssert(self.currentSpot);
        self.currentSpot.timeLimit = [[ParkingTimeLimit alloc] initWithWatchConnectivityDictionary:message[SPMWatchObjectParkingTimeLimit]];
    }
    else if ([message[SPMWatchAction] isEqualToString:SPMWatchActionUpdateGeocoding])
    {
        if (self.currentSpot != nil)
        {
            self.currentSpot.address = message[SPMWatchObjectParkingSpot][SPMWatchObjectParkingAddress];
        }
        else
        {
            // Just in case we did not have it!
            self.currentSpot = [[ParkingSpot alloc] initWithWatchConnectivityDictionary:message[SPMWatchObjectParkingSpot]];
            self.userDefinedParkingTimeLimit = message[SPMWatchObjectUserDefinedParkingTimeLimit];
            self.currentSpotLoaded = YES;
        }
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SPMWatchSessionNotificationReceivedMessage
                                                        object:nil
                                                      userInfo:message];
}

- (void)session:(nonnull WCSession *)session activationDidCompleteWithState:(WCSessionActivationState)activationState error:(nullable NSError *)error {
    if (activationState != WCSessionActivationStateNotActivated)
    {
        self.initialActivationCompleted = YES;
        SPMLog(@"Watch Session activated");
        
        if (self.pendingMessages.count)
        {
            for (NSDictionary *pendingMessage in self.pendingMessages)
            {
                NSDictionary *message = pendingMessage[@"message"];
                id replyHandler = pendingMessage[@"replyHandler"];
                id errorHandler = pendingMessage[@"errorHandler"];
                
                SPMLog(@"Scheduling pending message: %@", message);
                [self sendMessageToPhone:message
                            replyHandler:replyHandler
                            errorHandler:errorHandler];
            }
            self.pendingMessages = nil;
        }
    }
    else
    {
        NSLog(@"Could not activate watch session. State: %lu, error: %@", (unsigned long)activationState, error);
    }
}

#pragma mark - Handoff

- (void)handleUserActivity:(NSDictionary *)userInfo
{
    ParkInterfaceController *controller = (ParkInterfaceController *)WKExtension.sharedExtension.rootInterfaceController;

    if (userInfo[CLKLaunchedTimelineEntryDateKey])
    {
        // Only if the app has gone to the background
        // This gets called before applicationDidBecomeActive on ExtensionDelegate, and we take advantage of that
        if (self.needsToFetchParkingSpot)
        {
            if (!self.currentSpot)
            {
                // Don't refetch it in the ExtensionDelegate's -applicationDidBecomeActive
                self.needsToFetchParkingSpot = NO;
                [controller parkWithNoTimeLimit];
            }
            else
            {
                [controller presentMapInterfaceWithContext:nil];
            }
        }
    }
    // Let the user set the time limit
    else if ([userInfo[SPMWatchAction] isEqualToString:SPMWatchActionSetParkingSpot])
    {
        [controller parkWithNoTimeLimit];
    }
}

@end
