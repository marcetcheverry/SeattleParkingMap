//
//  GlanceInterfaceController.m
//  SeattleParkingMapWatch Extension
//
//  Created by Marc on 11/15/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

#import "GlanceInterfaceController.h"

#import "ParkingSpot.h"
#import "ParkingTimeLimit.h"
#import "ParkingTimeLimit+Watch.h"

#import "WKInterfaceMap+SPM.h"
#import "UIColor+SPM.h"

@interface GlanceInterfaceController()

@property (weak, nonatomic) IBOutlet WKInterfaceMap *interfaceMap;
@property (weak, nonatomic) IBOutlet WKInterfaceLabel *labelTime;
@property (weak, nonatomic) IBOutlet WKInterfaceLabel *labelHeader;
@property (weak, nonatomic) IBOutlet WKInterfaceLabel *labelParkingIcon;
@property (strong, nonatomic) NSTimer *timerReminder;
@property (strong, nonatomic) NSDateComponentsFormatter *dateComponentsFormatter;

@end

@implementation GlanceInterfaceController

- (void)awakeWithContext:(id)context
{
    [super awakeWithContext:context];

    [self.extensionDelegate establishSession];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(timeDidChangeSignificantly:)
                                                 name:NSSystemClockDidChangeNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(timeDidChangeSignificantly:)
                                                 name:NSCalendarDayChangedNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveSessionMessage:)
                                                 name:SPMWatchSessionNotificationReceivedMessage
                                               object:nil];
}

- (void)didDeactivate
{
    [super didDeactivate];

    // Restore defaults
    self.labelHeader.text = NSLocalizedString(@"Seattle Parking", nil);
    self.labelHeader.textColor = [UIColor SPMWatchTintColor];
    self.labelTime.text = NSLocalizedString(@"Loading", nil);
    self.interfaceMap.hidden = YES;
    self.labelParkingIcon.hidden = NO;

    self.dateComponentsFormatter = nil;
    [self.timerReminder invalidate];
    self.timerReminder = nil;
}

- (void)willActivate
{
    [super willActivate];

    if (self.currentOperation && ![self.currentOperation isFinished])
    {
        return;
    }

    WatchConnectivityOperation *localOperation = [[WatchConnectivityOperation alloc] init];
    self.currentOperation = localOperation;

    [[WCSession defaultSession] sendMessage:@{SPMWatchAction: SPMWatchActionGetParkingSpot}
                               replyHandler:^(NSDictionary<NSString *,id> * _Nonnull replyMessage) {
                                   if (localOperation.cancelled)
                                   {
                                       return;
                                   }

                                   dispatch_async(dispatch_get_main_queue(), ^{
                                       self.extensionDelegate.userDefinedParkingTimeLimit = replyMessage[SPMWatchObjectUserDefinedParkingTimeLimit];
                                       self.extensionDelegate.currentSpot = [[ParkingSpot alloc] initWithWatchConnectivityDictionary:replyMessage[SPMWatchObjectParkingSpot]];
                                       //                         NSLog(@"Glance received reply: %@", replyMessage);
                                       [self updateInterface];
                                       
                                       localOperation.finished = YES;
                                   });
                               }
                               errorHandler:^(NSError * _Nonnull error) {
                                   if (localOperation.cancelled)
                                   {
                                       return;
                                   }
                                   localOperation.finished = YES;

//                                   dispatch_async(dispatch_get_main_queue(), ^{
//                                       NSLog(@"Glance received error: %@", error);
//                                       // Don't lose our data
//                                       ((ExtensionDelegate *)[WKExtension sharedExtension].delegate).currentSpot = nil;
//                                       [self updateInterface];
//                                   });
                               }];
}

- (void)dealloc
{
    [self.timerReminder invalidate];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:SPMWatchSessionNotificationReceivedMessage
                                                  object:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSSystemClockDidChangeNotification
                                                  object:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSCalendarDayChangedNotification
                                                  object:nil];
}

#pragma mark - Notifications

- (void)didReceiveSessionMessage:(NSNotification *)notification
{
    NSDictionary *message = [notification userInfo];

    //    NSLog(@"Glance Received Message from App %@", message);

    dispatch_async(dispatch_get_main_queue(), ^{
        if ([message[SPMWatchAction] isEqualToString:SPMWatchActionSetParkingSpot])
        {
            [self updateInterface];
        }
        else if ([message[SPMWatchAction] isEqualToString:SPMWatchActionRemoveParkingSpot])
        {
            [self updateInterface];
        }
        else if ([message[SPMWatchAction] isEqualToString:SPMWatchActionSetParkingTimeLimit] ||
                 [message[SPMWatchAction] isEqualToString:SPMWatchActionRemoveParkingTimeLimit])
        {
            ParkingSpot *currentSpot = self.extensionDelegate.currentSpot;
            if (currentSpot)
            {
                [self updateParkingDateWithParkingSpot:currentSpot];
            }
            [self updateTopLabel];
        }
    });
}

#pragma mark - Interface

- (void)timeDidChangeSignificantly:(NSNotification *)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        //        NSLog(@"Significant time change %@", notification);
        [self updateTopLabel];
        [self updateParkingDateWithParkingSpot:self.extensionDelegate.currentSpot];
    });
}

- (void)updateParkingDateWithParkingSpot:(nonnull ParkingSpot *)currentSpot
{
    NSParameterAssert(currentSpot);

    NSDate *date = currentSpot.date;
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.doesRelativeDateFormatting = YES;
    formatter.locale = [NSLocale currentLocale];
    formatter.timeStyle = NSDateFormatterShortStyle;

    if (self.extensionDelegate.currentSpot.timeLimit)
    {
        if (![[NSCalendar currentCalendar] isDate:date
                                                    inSameDayAsDate:[NSDate date]])
        {
            formatter.dateStyle = NSDateFormatterShortStyle;
            self.labelTime.text = [formatter stringFromDate:date];
        }
        else
        {
            formatter.dateStyle = NSDateFormatterNoStyle;
            self.labelTime.text = [NSString stringWithFormat:NSLocalizedString(@"Parked at %@", nil), [formatter stringFromDate:date]];
        }
    }
    else
    {
        formatter.dateStyle = NSDateFormatterShortStyle;
        self.labelTime.text = [formatter stringFromDate:date];
    }
}

- (void)updateTopLabel
{
    ParkingSpot *currentSpot = self.extensionDelegate.currentSpot;
    if (currentSpot)
    {
        ParkingTimeLimit *timeLimit = currentSpot.timeLimit;

        if (!timeLimit)
        {
            self.labelHeader.text = NSLocalizedString(@"Parked", nil);
            self.labelHeader.textColor = [UIColor SPMParkedColor];
            self.dateComponentsFormatter = nil;
            [self.timerReminder invalidate];
            self.timerReminder = nil;
        }
        else if (timeLimit)
        {
            if ([timeLimit isExpired])
            {
                self.labelHeader.text = NSLocalizedString(@"⚠️ Time Expired", nil);
                self.labelHeader.textColor = [timeLimit textColorForThreshold:SPMParkingTimeLimitThresholdExpired];
                self.dateComponentsFormatter = nil;
                [self.timerReminder invalidate];
                self.timerReminder = nil;
            }
            else
            {
                if (!self.timerReminder)
                {
                    self.timerReminder = [NSTimer timerWithTimeInterval:60
                                                                 target:self
                                                               selector:@selector(updateTopLabel)
                                                               userInfo:nil
                                                                repeats:YES];
                    [[NSRunLoop currentRunLoop] addTimer:self.timerReminder
                                                 forMode:NSRunLoopCommonModes];

                }

                if (!self.dateComponentsFormatter)
                {
                    self.dateComponentsFormatter = [[NSDateComponentsFormatter alloc] init];
                    self.dateComponentsFormatter.allowedUnits = NSCalendarUnitHour | NSCalendarUnitMinute;
                    self.dateComponentsFormatter.unitsStyle = NSDateComponentsFormatterUnitsStyleShort;
                    self.dateComponentsFormatter.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorDropAll;
                }

                NSString *title = [self.dateComponentsFormatter stringFromDate:[NSDate date] toDate:timeLimit.endDate];
                self.labelHeader.text = [NSString stringWithFormat:@"%@ ⇢ 🔔", title];
                self.labelHeader.textColor = [timeLimit textColor];
            }
        }

        [self updateParkingDateWithParkingSpot:currentSpot];
    }
    else
    {
        self.dateComponentsFormatter = nil;
        [self.timerReminder invalidate];
        self.timerReminder = nil;

        self.labelHeader.text = NSLocalizedString(@"Seattle Parking", nil);
        self.labelHeader.textColor = [UIColor SPMWatchTintColor];
    }
}

- (void)updateInterface
{
    [self updateTopLabel];

    ParkingSpot *currentSpot = self.extensionDelegate.currentSpot;
    if (currentSpot)
    {
        [self updateParkingDateWithParkingSpot:currentSpot];

        self.interfaceMap.hidden = NO;
        self.labelParkingIcon.hidden = YES;

        [self animateWithDuration:0.3
                       animations:^{
                           self.interfaceMap.alpha = 1;
                           self.labelParkingIcon.alpha = 0;
                       }];

        [self.interfaceMap SPMSetCurrentParkingSpot:currentSpot];

        [self invalidateUserActivity];
    }
    else
    {
        //        NSLog(@"Glance Debug: Setting Tap To Park %@", currentSpot);
        self.labelTime.text = NSLocalizedString(@"Tap to Park", nil);
        self.interfaceMap.hidden = YES;
        self.labelParkingIcon.hidden = NO;

        [self animateWithDuration:0.3
                       animations:^{
                           self.interfaceMap.alpha = 0;
                           self.labelParkingIcon.alpha = 1;
                       }];

        [self updateUserActivity:[NSBundle mainBundle].bundleIdentifier
                        userInfo:@{SPMWatchAction: SPMWatchActionSetParkingSpot}
                      webpageURL:nil];
    }
}

@end
