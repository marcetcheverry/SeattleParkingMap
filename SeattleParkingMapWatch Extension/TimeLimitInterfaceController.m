//
//  TimeLimitInterfaceController.m
//  SeattleParkingMap
//
//  Created by Marc on 12/26/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

#import "TimeLimitInterfaceController.h"

#import "ParkingSpot.h"
#import "ParkingTimeLimit.h"

@interface TimeLimitInterfaceController ()

@property (nonatomic, copy) NSString *context;

@property (weak, nonatomic) IBOutlet WKInterfaceGroup *groupCustomPickerTimeLimit;
@property (weak, nonatomic) IBOutlet WKInterfacePicker *pickerHours;
@property (weak, nonatomic) IBOutlet WKInterfacePicker *pickerMinutes;
@property (weak, nonatomic) IBOutlet WKInterfaceLabel *labelReminder;
@property (nonatomic) NSInteger pickerTimeLimitHoursSelectedIndex;
@property (nonatomic) NSInteger pickerTimeLimitMinutesSelectedIndex;

@property (nonatomic) WKPickerItem *pickerMinutesItemZero;
@property (nonatomic) NSMutableArray *pickerMinutesItems;
@property (nonatomic) BOOL reminderLabelIsBelowThreshold;

@end

@implementation TimeLimitInterfaceController

- (void)awakeWithContext:(id)context
{
    [super awakeWithContext:context];

    self.context = context;

    NSMutableArray *itemsHours = [[NSMutableArray alloc] initWithCapacity:24];
    for (NSUInteger i = 0; i < 24; i++)
    {
        WKPickerItem *item = [[WKPickerItem alloc] init];
        item.title = [NSString stringWithFormat:@"%lu", (unsigned long)i];
        [itemsHours addObject:item];
    }

    [self.pickerHours setItems:itemsHours];

    NSMutableArray *itemsMinutes = [[NSMutableArray alloc] initWithCapacity:6];
    //    for (NSUInteger i = 0; i < 55; i += 5)
    //    {
    //        if (i == 5)
    //        {
    //            continue;
    //        }

    for (NSUInteger i = 0; i < 60; i += SPMDefaultsParkingTimeLimitMinuteInterval)
    {
        WKPickerItem *item = [[WKPickerItem alloc] init];
        item.title = [NSString stringWithFormat:@"%lu", (unsigned long)i];
        [itemsMinutes addObject:item];
        if (i == 0)
        {
            self.pickerMinutesItemZero = item;
        }
    }

    self.pickerMinutesItems = itemsMinutes;

    [self.pickerMinutes setItems:itemsMinutes];

    if (self.extensionDelegate.userDefinedParkingTimeLimit)
    {
        NSTimeInterval duration = [self.extensionDelegate.userDefinedParkingTimeLimit doubleValue];
        NSInteger days = ((NSInteger) duration) / (60 * 60 * 24);
        NSInteger hours = (((NSInteger) duration) / (60 * 60)) - (days * 24);
        NSInteger minutes = (((NSInteger) duration) / 60) - (days * 24 * 60) - (hours * 60);
        [self.pickerHours setSelectedItemIndex:hours];
        self.pickerTimeLimitHoursSelectedIndex = hours;
        NSInteger minutesIndex = minutes / SPMDefaultsParkingTimeLimitMinuteInterval;
        [self.pickerMinutes setSelectedItemIndex:minutesIndex];
        self.pickerTimeLimitMinutesSelectedIndex = minutesIndex;
    }
    else
    {
        [self.pickerHours setSelectedItemIndex:3];
        self.pickerTimeLimitHoursSelectedIndex = 3;
        [self.pickerMinutes setSelectedItemIndex:0];
        self.pickerTimeLimitMinutesSelectedIndex = 0;
    }

    [self constrainMinutesPickerIfNeeded];

    [self.pickerHours focus];
}

- (void)willDisappear
{
    [super willDisappear];

    [self.pickerHours resignFocus];
    [self.pickerMinutes resignFocus];
}

- (void)setLoadingIndicatorHidden:(BOOL)hidden
{
    if (!hidden)
    {
        [self.pickerHours resignFocus];
        [self.pickerMinutes resignFocus];
    }
    else
    {
        [self.pickerHours focus];
    }

    [super setLoadingIndicatorHidden:hidden];
}

- (IBAction)pickerHoursSelectedIndex:(NSInteger)selectedIndex
{
    self.pickerTimeLimitHoursSelectedIndex = selectedIndex;

    [self constrainMinutesPickerIfNeeded];
}

- (IBAction)pickerMinutesSelectedIndex:(NSInteger)selectedIndex
{
    self.pickerTimeLimitMinutesSelectedIndex = selectedIndex;

    [self updateReminderLabel];
}

- (void)constrainMinutesPickerIfNeeded
{
    if (self.pickerTimeLimitHoursSelectedIndex == 0)
    {
        if (self.pickerMinutesItems[0] == self.pickerMinutesItemZero)
        {
            [self.pickerMinutesItems removeObject:self.pickerMinutesItemZero];
            [self.pickerMinutes setItems:self.pickerMinutesItems];

            if (self.pickerTimeLimitMinutesSelectedIndex > 0)
            {
                self.pickerTimeLimitMinutesSelectedIndex -= 1;
            }
            [self.pickerMinutes setSelectedItemIndex:self.pickerTimeLimitMinutesSelectedIndex];
        }
    }
    else
    {
        if (self.pickerMinutesItems[0] != self.pickerMinutesItemZero)
        {
            [self.pickerMinutesItems insertObject:self.pickerMinutesItemZero
                                          atIndex:0];
            [self.pickerMinutes setItems:self.pickerMinutesItems];
            self.pickerTimeLimitMinutesSelectedIndex += 1;
            NSAssert(self.pickerTimeLimitMinutesSelectedIndex < [self.pickerMinutesItems count], @"Must be smaller");
            [self.pickerMinutes setSelectedItemIndex:self.pickerTimeLimitMinutesSelectedIndex];
        }
    }

    [self updateReminderLabel];
}

- (void)updateReminderLabel
{
    if (self.pickerTimeLimitHoursSelectedIndex == 0 &&
        self.pickerTimeLimitMinutesSelectedIndex == 0)
    {
        if (!self.reminderLabelIsBelowThreshold)
        {
            [self.labelReminder setText:NSLocalizedString(@"You will be reminded 5 minutes before", nil)];
            self.reminderLabelIsBelowThreshold = YES;
        }
    }
    else
    {
        if (self.reminderLabelIsBelowThreshold)
        {
            [self.labelReminder setText:NSLocalizedString(@"You will be reminded 10 minutes before", nil)];
            self.reminderLabelIsBelowThreshold = NO;
        }
    }
}

- (nonnull NSNumber *)currentTimePickerIntervalNumber
{
    NSInteger minutesSelectedIndex = self.pickerTimeLimitMinutesSelectedIndex;

    if (self.pickerTimeLimitHoursSelectedIndex == 0)
    {
        minutesSelectedIndex += 1;
    }

    return @((self.pickerTimeLimitHoursSelectedIndex * 60 * 60) + (minutesSelectedIndex * SPMDefaultsParkingTimeLimitMinuteInterval * 60));
}

- (IBAction)touchedSetTimeLimit
{
    NSNumber *length = [self currentTimePickerIntervalNumber];

    self.title = nil;

    self.labelLoading.text = NSLocalizedString(@"Setting\nTime Limit", nil);
    [self setLoadingIndicatorHidden:NO
                           animated:YES];

    if ([self.context isEqualToString:SPMWatchContextUserDefinedParkingTimeLimit])
    {
        [self setParkingTimeLimitWithLength:length
                             limitStartDate:[NSDate date]];
        return;
    }

    [ParkingTimeLimit creationActionPathForParkDate:self.extensionDelegate.currentSpot.date
                                    timeLimitLength:length
                                            handler:^(SPMParkingTimeLimitSetActionPath actionPath, NSString * _Nullable alertTitle, NSString * _Nullable alertMessage) {
                                                if (actionPath == SPMParkingTimeLimitSetActionPathSet)
                                                {
                                                    [self setParkingTimeLimitWithLength:length
                                                                         limitStartDate:[NSDate date]];
                                                }
                                                else
                                                {
                                                    NSArray <WKAlertAction *> *actions;
                                                    if (actionPath == SPMParkingTimeLimitSetActionPathWarn)
                                                    {
                                                        actions = @[[WKAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                                                             style:WKAlertActionStyleDefault
                                                                                           handler:^{
                                                                                               [self setParkingTimeLimitWithLength:length
                                                                                                                    limitStartDate:[NSDate date]];
                                                                                           }]];
                                                        [self presentAlertControllerWithTitle:alertTitle
                                                                                      message:alertMessage
                                                                               preferredStyle:WKAlertControllerStyleAlert
                                                                                      actions:actions];

                                                    }
                                                    else if (actionPath == SPMParkingTimeLimitSetActionPathAsk)
                                                    {
                                                        actions = @[[WKAlertAction actionWithTitle:NSLocalizedString(@"Initial", nil)
                                                                                             style:WKAlertActionStyleDefault
                                                                                           handler:^{
                                                                                               [self setParkingTimeLimitWithLength:length
                                                                                                                    limitStartDate:self.extensionDelegate.currentSpot.date];
                                                                                           }],
                                                                    [WKAlertAction actionWithTitle:NSLocalizedString(@"Now", nil)
                                                                                             style:WKAlertActionStyleDestructive
                                                                                           handler:^{
                                                                                               [self setParkingTimeLimitWithLength:length
                                                                                                                    limitStartDate:[NSDate date]];
                                                                                           }]];
                                                        [self presentAlertControllerWithTitle:alertTitle
                                                                                      message:alertMessage
                                                                               preferredStyle:WKAlertControllerStyleSideBySideButtonsAlert
                                                                                      actions:actions];
                                                    }
                                                }
                                            }];
}

- (void)setParkingTimeLimitWithLength:(nonnull NSNumber *)length
                       limitStartDate:(nonnull NSDate *)limitStartDate
{
    NSParameterAssert(length);
    NSParameterAssert(limitStartDate);

    if (!length || !limitStartDate)
    {
        return;
    }

    self.extensionDelegate.userDefinedParkingTimeLimit = length;

    if ([self.context isEqualToString:SPMWatchContextUserDefinedParkingTimeLimit])
    {
        [self dismissController];
        return;
    }


    WatchConnectivityOperation *localOperation = [[WatchConnectivityOperation alloc] init];
    self.currentOperation = localOperation;

    ParkingTimeLimit *timeLimit = [[ParkingTimeLimit alloc] initWithStartDate:limitStartDate
                                                                       length:length
                                                            reminderThreshold:nil];

    [[WCSession defaultSession] sendMessage:@{SPMWatchAction: SPMWatchActionSetParkingTimeLimit,
                                              SPMWatchObjectParkingTimeLimit: [timeLimit watchConnectivityDictionaryRepresentation]}
                               replyHandler:^(NSDictionary<NSString *,id> * _Nonnull replyMessage) {
                                   dispatch_async(dispatch_get_main_queue(), ^{
                                       if ([replyMessage[SPMWatchResponseStatus] isEqualToString:SPMWatchResponseSuccess])
                                       {
                                           [[WKInterfaceDevice currentDevice] playHaptic:WKHapticTypeClick];
                                           self.extensionDelegate.currentSpot.timeLimit = timeLimit;
                                       }

                                       if (localOperation.cancelled)
                                       {
                                           // NSLog(@"Operation cancelled %p, self.current %p", localOperation, self.currentOperation);

                                           [[NSNotificationCenter defaultCenter] postNotificationName:SPMWatchSessionNotificationReceivedMessage
                                                                                               object:nil
                                                                                             userInfo:replyMessage];

                                           return;
                                       }

                                       // NSLog(@"Watch received reply: %@", replyMessage);

                                       if ([replyMessage[SPMWatchResponseStatus] isEqualToString:SPMWatchResponseSuccess])
                                       {
                                           dispatch_block_t dismissBlock = ^{
                                               [self dismissController];
                                           };

                                           if (replyMessage[SPMWatchObjectWarningMessage])
                                           {
                                               [self presentAlertControllerWithTitle:nil
                                                                             message:replyMessage[SPMWatchObjectWarningMessage]
                                                                      preferredStyle:WKAlertControllerStyleAlert
                                                                             actions:@[[WKAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                                                                                style:WKAlertActionStyleCancel
                                                                                                              handler:^{
                                                                                                                  dismissBlock();
                                                                                                              }]]];
                                           }
                                           else
                                           {
                                               dismissBlock();
                                           }
                                       }
                                       else
                                       {
                                           [self displayErrorMessage:NSLocalizedString(@"Could Not Set Time Limit", nil)];
                                       }
                                       self.currentOperation = nil;
                                   });
                               }
                               errorHandler:^(NSError * _Nonnull error) {
                                   dispatch_async(dispatch_get_main_queue(), ^{
                                       if (localOperation.cancelled)
                                       {
                                           //                               NSLog(@"Operation cancelled %p, self.current %p", localOperation, self.currentOperation);
                                           return;
                                       }
                                       
                                       [self displayErrorMessage:NSLocalizedString(@"Could Not Set Time Limit", nil)];
                                       self.currentOperation = nil;
                                   });
                               }];
}

@end
