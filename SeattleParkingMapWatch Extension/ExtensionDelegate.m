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

@import ClockKit;

static void *ExtensionDelegateContext = &ExtensionDelegateContext;

@interface ExtensionDelegate() <WCSessionDelegate>

@property (nonatomic, readwrite, getter=isCurrentSpotLoaded) BOOL currentSpotLoaded;
@property (nonatomic) BOOL needsToFetchParkingSpot;
@property (nonatomic) BOOL isLoading;

@end

@implementation ExtensionDelegate

#pragma mark - Application Lifecycle

- (void)applicationDidFinishLaunching
{
    // Perform any final initialization of your application.
    [self establishSession];

    [self addObserver:self
           forKeyPath:@"currentSpot"
              options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld)
              context:ExtensionDelegateContext];

    [self addObserver:self
           forKeyPath:@"currentSpot.timeLimit"
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

- (void)handleActionWithIdentifier:(nullable NSString *)identifier
              forLocalNotification:(UILocalNotification *)localNotification
{
    if ([localNotification.category isEqualToString:SPMNotificationCategoryTimeLimit])
    {
        [self updateComplications];
    }
}

#pragma mark - Session

- (void)establishSession
{
    WCSession *session = [WCSession defaultSession];
    session.delegate = self;
    [session activateSession];
}

#pragma mark - Complications

- (void)updateComplication:(CLKComplicationFamily)complicationFamily
{
    CLKComplicationServer *server = [CLKComplicationServer sharedInstance];
    for (CLKComplication *complication in server.activeComplications)
    {
        if (complication.family == complicationFamily)
        {
            [server reloadTimelineForComplication:complication];
        }
    }
}

- (void)updateComplications
{
    CLKComplicationServer *server = [CLKComplicationServer sharedInstance];
    for (CLKComplication *complication in server.activeComplications)
    {
        [server reloadTimelineForComplication:complication];
    }
}

#pragma mark - Time Limit

- (void)setUserDefinedParkingTimeLimit:(NSNumber *)userDefinedParkingTimeLimit
{
    // Note that we use the setter. Test case: have a spot stored in defaults, and the first thing you do is try to set this to nil
    if (_userDefinedParkingTimeLimit != userDefinedParkingTimeLimit)
    {
        _userDefinedParkingTimeLimit = userDefinedParkingTimeLimit;

        NSError *error;
        [[WCSession defaultSession] updateApplicationContext:@{SPMWatchContextUserDefinedParkingTimeLimit: _userDefinedParkingTimeLimit}
                                                       error:&error];
        if (error)
        {
            NSLog(@"Could not update application context from watch to device: %@", error);
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
        if ([keyPath isEqualToString:@"currentSpot.timeLimit"] ||
            [keyPath isEqualToString:@"currentSpot"])
        {
            if (![change[NSKeyValueChangeOldKey] isEqual:change[NSKeyValueChangeNewKey]])
            {
                [self updateComplications];
            }
        }
    }
}

#pragma mark - Actions

- (void)fetchParkingSpot
{
    if (!self.isLoading)
    {
        self.isLoading = YES;
        [[WCSession defaultSession] sendMessage:@{SPMWatchAction: SPMWatchActionGetParkingSpot}
                                   replyHandler:^(NSDictionary<NSString *,id> * _Nonnull replyMessage) {
                                       self.isLoading = NO;
                                       NSDictionary *message = replyMessage;

                                       // If it is an empty get parking point, convert to a remove action!
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

- (void)session:(WCSession *)session didReceiveMessage:(NSDictionary<NSString *, id> *)message
{
    if ([message[SPMWatchAction] isEqualToString:SPMWatchActionRemoveParkingSpot])
    {
        self.currentSpot = nil;
        self.currentSpotLoaded = YES;
        [self updateComplications];
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
    else if ([message[SPMWatchAction] isEqualToString:SPMWatchActionUpdateComplications])
    {
        SPMLog(@"Received notification to update complications!");
        [self updateComplications];
    }
    else if ([message[SPMWatchAction] isEqualToString:SPMWatchActionUpdateGeocoding])
    {
        self.currentSpotLoaded = YES;
        self.currentSpot.address = message[SPMWatchObjectParkingSpotAddress];
        [self updateComplication:CLKComplicationFamilyModularLarge];
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:SPMWatchSessionNotificationReceivedMessage
                                                        object:nil
                                                      userInfo:message];
}

@end
