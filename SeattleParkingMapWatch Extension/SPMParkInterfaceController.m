//
//  SPMParkInterfaceController.m
//  SeattleParkingMapWatch Extension
//
//  Created by Marc on 11/15/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

#import "SPMParkInterfaceController.h"

@interface SPMParkInterfaceController() <WCSessionDelegate>

@property (weak, nonatomic) IBOutlet WKInterfaceButton *buttonCurrent;

@end

@implementation SPMParkInterfaceController

- (void)awakeWithContext:(id)context
{
    [super awakeWithContext:context];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveSessionMessage:)
                                                 name:SPMWatchSessionNotficationReceivedMessage
                                               object:nil];

    [self getLastParkingPointPresentingMapAutomatically:YES];
}

- (void)willActivate
{
    // This method is called when watch view controller is about to be visible to user
    [super willActivate];
    [self updateCurrentButtonAnimated:NO];
}

- (void)didAppear
{
    [super didAppear];
    [self updateUserActivity:SPMWatchHandoffActivityCurrentScreen
                    userInfo:@{SPMWatchHandoffUserInfoKeyCurrentScreen : NSStringFromClass(self.class)}
                  webpageURL:nil];
}

- (void)willDisappear
{
    [super willDisappear];
    [self invalidateUserActivity];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:SPMWatchSessionNotficationReceivedMessage
                                                  object:nil];
}

- (void)handleUserActivity:(NSDictionary *)userInfo
{
    if ([userInfo[SPMWatchAction] isEqualToString:SPMWatchActionSetParkingSpot])
    {
        [self parkHereTouched];
    }
}

#pragma mark - Notifications

- (void)didReceiveSessionMessage:(NSNotification *)notification
{
    NSDictionary *message = [notification userInfo];

    //    NSLog(@"Watch (Park) Received Message from App %@", message);

    dispatch_async(dispatch_get_main_queue(), ^{
        if ([message[SPMWatchAction] isEqualToString:SPMWatchActionSetParkingSpot])
        {
            if ([message[SPMWatchResponseStatus] isEqualToString:SPMWatchResponseSuccess] &&
                [self extensionDelegate].lastParkingSpot[SPMWatchObjectParkingPoint])
            {
                [self presentControllerWithName:@"Map"
                                        context:message];
            }

            [self setLoadingIndicatorHidden:YES];
        }
        else if ([message[SPMWatchAction] isEqualToString:SPMWatchActionRemoveParkingSpot] ||
                 [message[SPMWatchAction] isEqualToString:SPMWatchActionGetParkingPoint])
        {
            [self updateCurrentButton];
        }
    });
}

#pragma mark - Interface

- (void)updateCurrentButtonAnimated:(BOOL)animated
{
    [self animateWithDuration:0.3
                   animations:^{
                       [self updateCurrentButton];
                   }];
}

- (void)updateCurrentButton
{
    if ([self extensionDelegate].lastParkingSpot[SPMWatchObjectParkingPoint] != nil)
    {
        self.buttonCurrent.title = NSLocalizedString(@"View Parking Spot", nil);
        self.buttonCurrent.backgroundColor = nil;
    }
    else
    {
        self.buttonCurrent.title = NSLocalizedString(@"Park In Current Location", nil);
        self.buttonCurrent.backgroundColor = [UIColor colorWithRed:0 green:0.569 blue:1 alpha:1];
    }
}

#pragma mark - Actions

- (IBAction)cancelTouched
{
    // Custon behavior
    if ([self.currentOperation[SPMWatchAction] isEqual:SPMWatchActionGetParkingPoint])
    {
        if (self.currentOperation)
        {
            self.currentOperation[@"cancelled"] = @YES;
        }

        WKAlertAction *actionDismiss = [WKAlertAction actionWithTitle:NSLocalizedString(@"Dismiss", nil)
                                                                style:WKAlertActionStyleCancel
                                                              handler:^{
                                                                  [self dismissController];

                                                                  // This is for a bug that leaves the screen empty
                                                                  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                                                      [self setLoadingIndicatorHidden:YES
                                                                                             animated:YES];
                                                                  });
                                                              }];

        WKAlertAction *actionTryAgain = [WKAlertAction actionWithTitle:NSLocalizedString(@"Try Again", nil)
                                                                 style:WKAlertActionStyleDefault
                                                               handler:^{
                                                                   [self dismissController];
                                                                   [self getLastParkingPointPresentingMapAutomatically:YES];
                                                               }];

        [self presentAlertControllerWithTitle:NSLocalizedString(@"Warning", nil)
                                      message:NSLocalizedString(@"Could not determine your current parking spot. Please try again if there is one set on your iPhone", nil)
                               preferredStyle:WKAlertControllerStyleSideBySideButtonsAlert
                                      actions:@[actionTryAgain, actionDismiss]];
    }
    else
    {
        [super cancelTouched];
    }
}

- (void)getLastParkingPointPresentingMapAutomatically:(BOOL)presentMapAutomatically
{
    self.labelLoading.text = NSLocalizedString(@"Loading", nil);

    [self setLoadingIndicatorHidden:NO
                           animated:YES];

    self.buttonCancel.alpha = 0;

    NSMutableDictionary *currentOperationDictionary = [[NSMutableDictionary alloc] initWithObjectsAndKeys:@(NO), @"cancelled",
                                                       @(NO), @"finished",
                                                       SPMWatchActionGetParkingPoint, SPMWatchAction,
                                                       nil];
    self.currentOperation = currentOperationDictionary;

    // Add a timeout to show the cancel button
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([currentOperationDictionary[@"finished"] boolValue])
        {
            return;
        }

        [self animateWithDuration:0.3
                       animations:^{
                           self.buttonCancel.alpha = 1;
                       }];
    });

    [[WCSession defaultSession] sendMessage:@{SPMWatchAction: SPMWatchActionGetParkingPoint}
                               replyHandler:^(NSDictionary<NSString *,id> * _Nonnull replyMessage) {
                                   currentOperationDictionary[@"finished"] = @(YES);

                                   dispatch_async(dispatch_get_main_queue(), ^{
                                       if ([currentOperationDictionary[@"cancelled"] boolValue])
                                       {
                                           //                             NSLog(@"Operation cancelled %p, self.current %p", currentOperationDictionary, self.currentOperation);
                                           return;
                                       }

                                       //                         NSLog(@"Watch received reply: %@", replyMessage);

                                       [self extensionDelegate].lastParkingSpot = replyMessage;

                                       if (presentMapAutomatically)
                                       {
                                           if ([replyMessage[SPMWatchResponseStatus] isEqualToString:SPMWatchResponseSuccess] &&
                                               [self extensionDelegate].lastParkingSpot[SPMWatchObjectParkingPoint])
                                           {
                                               [self presentControllerWithName:@"Map"
                                                                       context:replyMessage];
                                           }
                                       }

                                       [self setLoadingIndicatorHidden:YES
                                                              animated:YES];
                                       self.buttonCancel.alpha = 1;
                                       [self updateCurrentButtonAnimated:NO];
                                       //                         NSLog(@"Finished getLastParkingPoint");
                                   });
                               }
                               errorHandler:^(NSError * _Nonnull error) {
                                   currentOperationDictionary[@"finished"] = @(YES);

                                   dispatch_async(dispatch_get_main_queue(), ^{
                                       if ([currentOperationDictionary[@"cancelled"] boolValue])
                                       {
                                           //                             NSLog(@"Operation cancelled %p, self.current %p", currentOperationDictionary, self.currentOperation);
                                           return;
                                       }

                                       NSLog(@"Watch received error: %@", error);
                                       [self extensionDelegate].lastParkingSpot = nil;
                                       [self setLoadingIndicatorHidden:YES
                                                              animated:YES];
                                       self.buttonCancel.alpha = 1;
                                   });
                               }];
}

- (IBAction)parkHereTouched
{
    if ([self extensionDelegate].lastParkingSpot[SPMWatchObjectParkingPoint] != nil)
    {
        [self presentControllerWithName:@"Map"
                                context:[self extensionDelegate].lastParkingSpot];
        return;
    }

    self.labelLoading.text = NSLocalizedString(@"Finding Current Location", nil);

    [self setLoadingIndicatorHidden:NO
                           animated:YES];

    //    NSLog(@"Sending SPMWatchActionSetParkingSpot");

    // Blocks will keep their own local reference of the cancel flag.
    // Note that if you fire two sendMessage calls quickly and cancel them, it will take 5 minutes for the second one to fail
    NSMutableDictionary *currentOperationDictionary = [[NSMutableDictionary alloc] initWithObjectsAndKeys:@(NO), @"cancelled", nil];
    //    NSLog(@"Will set new %p, over %p", currentOperationDictionary, self.currentOperation);
    self.currentOperation = currentOperationDictionary;

    [[WCSession defaultSession] sendMessage:@{SPMWatchAction: SPMWatchActionSetParkingSpot}
                               replyHandler:^(NSDictionary<NSString *,id> * _Nonnull replyMessage) {
                                   dispatch_async(dispatch_get_main_queue(), ^{
                                       if ([currentOperationDictionary[@"cancelled"] boolValue])
                                       {
                                           //                             NSLog(@"Operation cancelled %p, self.current %p", currentOperationDictionary, self.currentOperation);

                                           [[WKInterfaceDevice currentDevice] playHaptic:WKHapticTypeSuccess];
                                           [self extensionDelegate].lastParkingSpot = replyMessage;
                                           [[NSNotificationCenter defaultCenter] postNotificationName:SPMWatchSessionNotficationReceivedMessage
                                                                                               object:nil
                                                                                             userInfo:replyMessage];

                                           return;
                                       }

                                       //                         NSLog(@"Watch received reply: %@", replyMessage);

                                       if ([replyMessage[SPMWatchResponseStatus] isEqualToString:SPMWatchResponseSuccess])
                                       {
                                           [self extensionDelegate].lastParkingSpot = replyMessage;
                                           [self presentControllerWithName:@"Map"
                                                                   context:replyMessage];
                                           [self setLoadingIndicatorHidden:YES
                                                                  animated:NO];
                                           [[WKInterfaceDevice currentDevice] playHaptic:WKHapticTypeSuccess];
                                       }
                                       else
                                       {
                                           [self displayErrorMessage:replyMessage[NSLocalizedFailureReasonErrorKey] ?: NSLocalizedString(@"Could Not Set Parking Spot", nil)];
                                       }
                                   });
                               }
                               errorHandler:^(NSError * _Nonnull error) {
                                   dispatch_async(dispatch_get_main_queue(), ^{
                                       if ([currentOperationDictionary[@"cancelled"] boolValue])
                                       {
                                           //                             NSLog(@"Operation cancelled %p, self.current %p", currentOperationDictionary, self.currentOperation);
                                           return;
                                       }
                                       
                                       [self extensionDelegate].lastParkingSpot = nil;
                                       NSLog(@"Watch received error: %@", error);
                                       [self displayErrorMessage:NSLocalizedString(@"Could Not Set Parking Spot", nil)];
                                   });
                               }];
}

@end
