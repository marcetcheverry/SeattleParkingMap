//
//  ParkInterfaceController.m
//  SeattleParkingMapWatch Extension
//
//  Created by Marc on 11/15/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

#import "ParkInterfaceController.h"

#import "WKInterfaceController+SPM.h"

#import "ParkingSpot.h"
#import "ParkingTimeLimit.h"

#import "UIColor+SPM.h"
#import "NSDate+SPM.h"

@import ClockKit;
@import UIKit.UIFont;
@import UIKit.NSAttributedString;

static void *ParkInterfaceControllerContext = &ParkInterfaceControllerContext;

@interface ParkInterfaceController() <WCSessionDelegate>

@property (weak, nonatomic) IBOutlet WKInterfaceButton *buttonCurrent;
@property (weak, nonatomic) IBOutlet WKInterfaceLabel *labelParkingGraphic;

@property (weak, nonatomic) IBOutlet WKInterfacePicker *pickerTimeLimit;
@property (nonatomic) NSMutableArray <WKPickerItem *> *pickerTimeLimitItems;
@property (nonatomic) NSOrderedSet <NSNumber *> *pickerTimeLimitIntervals;
@property (nonatomic) NSInteger pickerTimeLimitSelectedIndex;
@property (nonatomic) BOOL needsPickerTimeLimitUpdateOnAppearance;
@property (nonatomic) BOOL isPresentingModalController;

@end

@implementation ParkInterfaceController

- (void)awakeWithContext:(id)context
{
    [super awakeWithContext:context];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveSessionMessage:)
                                                 name:SPMWatchSessionNotificationReceivedMessage
                                               object:nil];

    [self.extensionDelegate addObserver:self
                             forKeyPath:@"userDefinedParkingTimeLimit"
                                options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld)
                                context:ParkInterfaceControllerContext];

    [self getLastParkingPointPresentingMapAutomatically:YES];

    [self buildTimeLimitsWithCustomInterval:self.extensionDelegate.userDefinedParkingTimeLimit
                    selectingCustomInterval:YES];
}

- (void)willActivate
{
    // This method is called when watch view controller is about to be visible to user
    [super willActivate];
    [self updateParkingInterface];
}

- (void)didAppear
{
    [super didAppear];

    [self updateUserActivity:SPMWatchHandoffActivityCurrentScreen
                    userInfo:@{SPMWatchHandoffUserInfoKeyCurrentScreen : NSStringFromClass(self.class)}
                  webpageURL:nil];

    if (self.needsPickerTimeLimitUpdateOnAppearance)
    {
        [self buildTimeLimitsWithCustomInterval:self.extensionDelegate.userDefinedParkingTimeLimit
                        selectingCustomInterval:YES];
        self.needsPickerTimeLimitUpdateOnAppearance = NO;
    }

    if (!self.extensionDelegate.currentSpot)
    {
        if (!self.currentOperation || self.currentOperation.finished)
        {
            [self.pickerTimeLimit focus];
        }
    }
}

- (void)didDeactivate
{
    [super didDeactivate];

    self.isPresentingModalController = NO;
}

// For a WatchKit bug
- (void)presentControllerWithName:(NSString *)name
                          context:(id)context
{
    self.isPresentingModalController = YES;
    [super presentControllerWithName:name
                             context:context];
}

- (void)willDisappear
{
    [super willDisappear];
    [self.pickerTimeLimit resignFocus];
    [self invalidateUserActivity];
}

- (void)parkWithNoTimeLimit
{
    [self.pickerTimeLimit setSelectedItemIndex:0];
    // This does not get called in time
    self.pickerTimeLimitSelectedIndex = 0;
    // Don't call updateInterface as the callback method for the picker, parkHere or the callback will do it for us!
    [self parkHereTouched];
}

- (void)handleUserActivity:(NSDictionary *)userInfo
{
    // Let the user set the time limit
    if ([userInfo[SPMWatchAction] isEqualToString:SPMWatchActionSetParkingSpot])
    {
        [self parkWithNoTimeLimit];
    }
    else if (userInfo[CLKLaunchedTimelineEntryDateKey])
    {
        if (self.extensionDelegate.currentSpot)
        {
            // Workaround for: https://forums.developer.apple.com/message/101186
            [WKInterfaceController reloadRootControllersWithNames:@[@"Park"]
                                                         contexts:nil];
        }
        else
        {
            [self parkWithNoTimeLimit];
        }
    }
}

- (void)dealloc
{
    [self.extensionDelegate removeObserver:self
                                forKeyPath:@"userDefinedParkingTimeLimit"
                                   context:ParkInterfaceControllerContext];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:SPMWatchSessionNotificationReceivedMessage
                                                  object:nil];
}

#pragma mark - Time Limit

- (void)buildTimeLimitsWithCustomInterval:(NSNumber *)customInterval
                  selectingCustomInterval:(BOOL)selectingCustomInterval
{
    WKPickerItem *itemNone = [[WKPickerItem alloc] init];
    itemNone.title = NSLocalizedString(@"Unlimited", nil);
    itemNone.caption = NSLocalizedString(@"Time Limit", nil);
    WKPickerItem *itemOther = [[WKPickerItem alloc] init];
    itemOther.title = NSLocalizedString(@"Other", nil);
    itemOther.caption = NSLocalizedString(@"Time Limit", nil);

    NSOrderedSet *predefinedIntervals = [ParkingTimeLimit defaultLengthTimeIntervals];
    if (customInterval)
    {
        NSMutableOrderedSet *mutablePredefinedIntervals = [predefinedIntervals mutableCopy];
        [mutablePredefinedIntervals addObject:customInterval];

        NSSortDescriptor *lowestToHighest = [NSSortDescriptor sortDescriptorWithKey:@"self"
                                                                          ascending:YES];
        [mutablePredefinedIntervals sortUsingDescriptors:@[lowestToHighest]];

        predefinedIntervals = mutablePredefinedIntervals;
    }

    self.pickerTimeLimitIntervals = predefinedIntervals;

    NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
    formatter.allowedUnits = NSCalendarUnitHour | NSCalendarUnitMinute;
    formatter.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorDropAll;

    NSUInteger predefinedIntervalsCount = [predefinedIntervals count];
    self.pickerTimeLimitItems = [[NSMutableArray alloc] initWithCapacity:predefinedIntervalsCount + 2];
    [self.pickerTimeLimitItems addObject:itemNone];

    NSUInteger indexToSelect = 0;
    for (NSUInteger i = 0; i < predefinedIntervalsCount; i++)
    {
        NSNumber *itemInterval = predefinedIntervals[i];
        if (selectingCustomInterval && [itemInterval isEqual:customInterval])
        {
            indexToSelect = i + 1;
        }

        NSTimeInterval interval = [itemInterval doubleValue];

        NSInteger days = ((NSInteger) interval) / (60 * 60 * 24);
        NSInteger hours = (((NSInteger) interval) / (60 * 60)) - (days * 24);
        NSInteger minutes = (((NSInteger) interval) / 60) - (days * 24 * 60) - (hours * 60);
        if (minutes == 0)
        {
            formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
        }
        else
        {
            formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleShort;
        }

        WKPickerItem *item = [[WKPickerItem alloc] init];
        item.title = [[formatter stringFromTimeInterval:interval] lowercaseString];
        item.caption = NSLocalizedString(@"Time Limit", nil);
        [self.pickerTimeLimitItems addObject:item];
    }

    [self.pickerTimeLimitItems addObject:itemOther];

    [self.pickerTimeLimit setItems:self.pickerTimeLimitItems];
    [self.pickerTimeLimit setSelectedItemIndex:indexToSelect];
    if (selectingCustomInterval)
    {
        [self updateParkingInterface];
    }
}

#pragma mark - Notifications

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context == ParkInterfaceControllerContext)
    {
        if ([keyPath isEqualToString:@"userDefinedParkingTimeLimit"])
        {
            if (![change[NSKeyValueChangeOldKey] isEqual:change[NSKeyValueChangeNewKey]])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    // For a bug in which setSelectedItemIndex on the picker would lock up if called in the background
                    if (!self.isPresentingModalController)
                    {
                        [self buildTimeLimitsWithCustomInterval:self.extensionDelegate.userDefinedParkingTimeLimit
                                        selectingCustomInterval:YES];
                    }
                    self.needsPickerTimeLimitUpdateOnAppearance = YES;
                });
            }
            //            else
            //            {
            //                dispatch_async(dispatch_get_main_queue(), ^{
            //                    NSUInteger predefinedIntervalsCount = [self.pickerTimeLimitIntervals count];
            //                    for (NSUInteger i = 0; i < predefinedIntervalsCount; i++)
            //                    {
            //                        NSNumber *interval = self.pickerTimeLimitIntervals[i];
            //                        if ([interval isEqual:change[NSKeyValueChangeNewKey]])
            //                        {
            //                            NSLog(@"Equal");
            //                            [self.pickerTimeLimit setSelectedItemIndex:i + 1];
            //                            break;
            //                        }
            //                    }
            //                });
            //            }
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath
                             ofObject:object
                               change:change
                              context:context];
    }
}

- (void)didReceiveSessionMessage:(NSNotification *)notification
{
    NSDictionary *message = [notification userInfo];

    //    NSLog(@"Watch (Park) Received Message from App %@", message);

    dispatch_async(dispatch_get_main_queue(), ^{
        if ([message[SPMWatchAction] isEqualToString:SPMWatchActionSetParkingSpot])
        {
            if ([message[SPMWatchResponseStatus] isEqualToString:SPMWatchResponseSuccess] &&
                self.extensionDelegate.currentSpot)
            {
                [self updateParkingInterface];
                [self presentControllerWithName:@"Map"
                                        context:message];
            }

            [self setLoadingIndicatorHidden:YES];
        }
        else if ([message[SPMWatchAction] isEqualToString:SPMWatchActionRemoveParkingSpot] ||
                 [message[SPMWatchAction] isEqualToString:SPMWatchActionGetParkingSpot])
        {
            [self updateParkingInterface];
        }
    });
}

#pragma mark - Interface

- (void)updateParkingInterface
{
    if (self.extensionDelegate.currentSpot != nil)
    {
        self.buttonCurrent.title = NSLocalizedString(@"View Parking Spot", nil);
        self.buttonCurrent.backgroundColor = [UIColor SPMButtonParkColor];
        [self.labelParkingGraphic setRelativeHeight:1
                                     withAdjustment:0];
        // I just needed to change the font size...
        NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:@"Ⓟ"
                                                                               attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:75]}];
        [self.labelParkingGraphic setAttributedText:attributedString];
        self.pickerTimeLimit.hidden = YES;
        [self.pickerTimeLimit resignFocus];
    }
    else
    {
        NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:@"Ⓟ"
                                                                               attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:49]}];
        [self.labelParkingGraphic setAttributedText:attributedString];
        [self.labelParkingGraphic sizeToFitHeight];

        if (self.pickerTimeLimitSelectedIndex == ([self.pickerTimeLimitItems count] - 1))
        {
            UIFont *font = [UIFont systemFontOfSize:15
                                             weight:UIFontWeightMedium];

            [self.buttonCurrent setAttributedTitle:[[NSAttributedString alloc] initWithString:NSLocalizedString(@"Set Time Limit", nil)
                                                                                   attributes:@{NSFontAttributeName:font,
                                                                                                NSForegroundColorAttributeName: [UIColor blackColor]}]];
            self.buttonCurrent.backgroundColor = [UIColor colorWithRed:1 green:0.778 blue:0.069 alpha:1];
        }
        else
        {
            self.buttonCurrent.title = NSLocalizedString(@"📍 Park Here", nil);
            self.buttonCurrent.backgroundColor = [UIColor SPMButtonParkColor];
            self.pickerTimeLimit.hidden = NO;
        }
    }
}

#pragma mark - Actions

- (void)setLoadingIndicatorHidden:(BOOL)hidden
{
    if (!hidden)
    {
        [self.pickerTimeLimit resignFocus];
    }
    else
    {
        [self.pickerTimeLimit focus];
    }

    [super setLoadingIndicatorHidden:hidden];
}

- (IBAction)pickerTimeLimitSelectedIndex:(NSInteger)selectedIndex
{
    self.pickerTimeLimitSelectedIndex = selectedIndex;

    [self updateParkingInterface];
}

- (IBAction)cancelTouched
{
    // Custom behavior
    if ([self.currentOperation.identifier isEqual:SPMWatchActionGetParkingSpot])
    {
        if (self.currentOperation)
        {
            self.currentOperation.cancelled = YES;
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

- (NSTimeInterval)loadingIndicatorDelay
{
    if (self.currentOperation.identifier == SPMWatchActionGetParkingSpot)
    {
        return 0;
    }

    return [super loadingIndicatorDelay];
}

- (void)getLastParkingPointPresentingMapAutomatically:(BOOL)presentMapAutomatically
{
    self.labelLoading.text = NSLocalizedString(@"Loading", nil);

    self.buttonCancel.alpha = 0;

    WatchConnectivityOperation *localOperation = [[WatchConnectivityOperation alloc] init];
    localOperation.identifier = SPMWatchActionGetParkingSpot;
    self.currentOperation = localOperation;

    [self setLoadingIndicatorHidden:NO
                           animated:YES];

    // Add a timeout to show the cancel button
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (localOperation.finished)
        {
            return;
        }

        [self animateWithDuration:0.3
                       animations:^{
                           self.buttonCancel.alpha = 1;
                       }];
    });

    [[WCSession defaultSession] sendMessage:@{SPMWatchAction: SPMWatchActionGetParkingSpot}
                               replyHandler:^(NSDictionary<NSString *,id> * _Nonnull replyMessage) {
                                   dispatch_async(dispatch_get_main_queue(), ^{
                                       if (localOperation.cancelled)
                                       {
                                           //                             NSLog(@"Operation cancelled %p, self.current %p", localOperation, self.currentOperation);
                                           return;
                                       }

                                       //                         NSLog(@"Watch received reply: %@", replyMessage);

                                       self.extensionDelegate.userDefinedParkingTimeLimit = replyMessage[SPMWatchObjectUserDefinedParkingTimeLimit];
                                       self.extensionDelegate.currentSpot = [[ParkingSpot alloc] initWithWatchConnectivityDictionary:replyMessage[SPMWatchObjectParkingSpot]];

                                       [self setLoadingIndicatorHidden:YES
                                                              animated:YES];
                                       self.buttonCancel.alpha = 1;
                                       [self updateParkingInterface];

                                       if (presentMapAutomatically)
                                       {
                                           if ([replyMessage[SPMWatchResponseStatus] isEqualToString:SPMWatchResponseSuccess] &&
                                               self.extensionDelegate.currentSpot)
                                           {
                                               [self presentControllerWithName:@"Map"
                                                                       context:replyMessage];
                                           }
                                       }

                                       //                         NSLog(@"Finished getLastParkingPoint");
                                       localOperation.finished = YES;
                                   });
                               }
                               errorHandler:^(NSError * _Nonnull error) {
                                   dispatch_async(dispatch_get_main_queue(), ^{
                                       if (localOperation.cancelled)
                                       {
                                           //                             NSLog(@"Operation cancelled %p, self.current %p", localOperation, self.currentOperation);
                                           return;
                                       }

                                       NSLog(@"Watch received error: %@", error);
                                       self.extensionDelegate.currentSpot = nil;
                                       [self setLoadingIndicatorHidden:YES
                                                              animated:YES];
                                       self.buttonCancel.alpha = 1;
                                       localOperation.finished = YES;
                                   });
                               }];
}

- (nonnull NSNumber *)currentTimePickerIntervalNumber
{
    if (self.pickerTimeLimitSelectedIndex == 0)
    {
        return nil;
    }
    if (self.pickerTimeLimitSelectedIndex == ([self.pickerTimeLimitItems count] - 1))
    {
        return nil;
    }

    NSUInteger index = self.pickerTimeLimitSelectedIndex;
    // Account for the +1 of the Unlimited first object,
    if (index > 0)
    {
        index -= 1;
    }

    return self.pickerTimeLimitIntervals[index];
}

- (IBAction)parkHereTouched
{
    if (self.pickerTimeLimitSelectedIndex == ([self.pickerTimeLimitItems count] - 1))
    {
        [self presentControllerWithName:@"TimeLimit"
                                context:SPMWatchContextUserDefinedParkingTimeLimit];
        return;
    }

    if (self.extensionDelegate.currentSpot)
    {
        [self presentControllerWithName:@"Map"
                                context:nil];
        return;
    }

    self.labelLoading.text = NSLocalizedString(@"Finding Current Location", nil);

    [self setLoadingIndicatorHidden:NO
                           animated:YES];

    //    NSLog(@"Sending SPMWatchActionSetParkingSpot");

    // Blocks will keep their own local reference of the cancel flag.
    // Note that if you fire two sendMessage calls quickly and cancel them, it will take 5 minutes for the second one to fail
    WatchConnectivityOperation *localOperation = [[WatchConnectivityOperation alloc] init];
    //    NSLog(@"Will set new %p, over %p", localOperation, self.currentOperation);
    self.currentOperation = localOperation;

    NSDictionary *message = @{SPMWatchAction: SPMWatchActionSetParkingSpot};

    NSNumber *selectedTimeLimit = [self currentTimePickerIntervalNumber];

    if (selectedTimeLimit)
    {
        NSDate *limitStartDate = [NSDate date];

        if (self.extensionDelegate.currentSpot.date)
        {
            if ([limitStartDate SPMIsBeforeDate:self.extensionDelegate.currentSpot.date])
            {
                NSLog(@"Start date of limit can not be before the current spot's start date");
                NSAssert(0, @"Limit start date is wrong");
                limitStartDate = self.extensionDelegate.currentSpot.date;
            }
        }

        ParkingTimeLimit *timeLimit = [[ParkingTimeLimit alloc] initWithStartDate:limitStartDate
                                                                           length:selectedTimeLimit
                                                                reminderThreshold:nil];
        if (timeLimit)
        {
            NSMutableDictionary *mutableMessage = [message mutableCopy];
            mutableMessage[SPMWatchObjectParkingTimeLimit] = [timeLimit watchConnectivityDictionaryRepresentation];
            message = mutableMessage;
        }
    }

    [[WCSession defaultSession] sendMessage:message
                               replyHandler:^(NSDictionary<NSString *,id> * _Nonnull replyMessage) {
                                   dispatch_async(dispatch_get_main_queue(), ^{
                                       if (localOperation.cancelled)
                                       {
                                           //                             NSLog(@"Operation cancelled %p, self.current %p", localOperation, self.currentOperation);

                                           [[WKInterfaceDevice currentDevice] playHaptic:WKHapticTypeSuccess];
                                           self.extensionDelegate.currentSpot = [[ParkingSpot alloc] initWithWatchConnectivityDictionary:replyMessage[SPMWatchObjectParkingSpot]];
                                           [[NSNotificationCenter defaultCenter] postNotificationName:SPMWatchSessionNotificationReceivedMessage
                                                                                               object:nil
                                                                                             userInfo:replyMessage];

                                           return;
                                       }

                                       //                         NSLog(@"Watch received reply: %@", replyMessage);

                                       if ([replyMessage[SPMWatchResponseStatus] isEqualToString:SPMWatchResponseSuccess])
                                       {
                                           self.extensionDelegate.currentSpot = [[ParkingSpot alloc] initWithWatchConnectivityDictionary:replyMessage[SPMWatchObjectParkingSpot]];
                                           [self updateParkingInterface];
                                           [self setLoadingIndicatorHidden:YES
                                                                  animated:NO];
                                           [self presentControllerWithName:@"Map"
                                                                   context:replyMessage];
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
                                       if (localOperation.cancelled)
                                       {
                                           //                             NSLog(@"Operation cancelled %p, self.current %p", localOperation, self.currentOperation);
                                           return;
                                       }
                                       
                                       self.extensionDelegate.currentSpot = nil;
                                       NSLog(@"Watch received error: %@", error);
                                       [self displayErrorMessage:NSLocalizedString(@"Could Not Set Parking Spot", nil)];
                                   });
                               }];
}

@end
