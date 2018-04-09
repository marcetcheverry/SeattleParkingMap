//
//  MapInterfaceController.m
//  SeattleParkingMap
//
//  Created by Marc on 12/5/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

#import "MapInterfaceController.h"

#import "ParkingSpot.h"
#import "ParkingTimeLimit.h"
#import "ParkingTimeLimit+Watch.h"

#import "TimeLimitInterfaceController.h"

#import "WKInterfaceMap+SPM.h"
#import "UIColor+SPM.h"

static void *MapInterfaceControllerContext = &MapInterfaceControllerContext;

@interface MapInterfaceController () <WCSessionDelegate>

@property (weak, nonatomic) IBOutlet WKInterfaceTimer *timerInterfaceReminder;
@property (weak, nonatomic) IBOutlet WKInterfaceLabel *labelRemaining;
@property (weak, nonatomic) IBOutlet WKInterfaceImage *imageBell;
@property (weak, nonatomic) IBOutlet WKInterfaceMap *interfaceMap;
@property (weak, nonatomic) IBOutlet WKInterfaceButton *buttonTimeLimit;

@property (nonatomic) NSTimer *timerReminder;

@property (nonatomic) BOOL parkedOnSameDay;
@property (nonatomic) BOOL needsTimeLimitRemovalOnAppearance;

@property (nonatomic) id context;

@end

@implementation MapInterfaceController

- (void)awakeWithContext:(id)context
{
    [super awakeWithContext:context];

    self.context = context;

    [self.extensionDelegate addObserver:self
                               forKeyPath:@"currentSpot.timeLimit"
                                  options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld)
                                  context:MapInterfaceControllerContext];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(timeDidChangeSignificantly:)
                                                 name:NSSystemClockDidChangeNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(timeDidChangeSignificantly:)
                                                 name:NSCalendarDayChangedNotification
                                               object:nil];

    [self updateInterface];
}

- (void)willActivate
{
    [super willActivate];

    NSDate *date = self.extensionDelegate.currentSpot.date;

    if (date)
    {
        if (self.parkedOnSameDay != [[NSCalendar currentCalendar] isDate:date inSameDayAsDate:[NSDate date]])
        {
            [self updateParkingDate];
        }
    }
}

- (void)didAppear
{
    [super didAppear];

    [self updateUserActivity:SPMWatchHandoffActivityCurrentScreen
                    userInfo:@{SPMWatchHandoffUserInfoKeyCurrentScreen : NSStringFromClass(self.class)}
                  webpageURL:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveSessionMessage:)
                                                 name:SPMWatchSessionNotificationReceivedMessage
                                               object:nil];

    [self updateParkingTimeLimit];

    if (self.needsTimeLimitRemovalOnAppearance)
    {
        [self removeTimeLimit];
        self.needsTimeLimitRemovalOnAppearance = NO;
    }

    if (self.context[SPMWatchObjectWarningMessage])
    {
        [self presentAlertControllerWithTitle:nil
                                      message:self.context[SPMWatchObjectWarningMessage]
                               preferredStyle:WKAlertControllerStyleAlert
                                      actions:@[[WKAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                                         style:WKAlertActionStyleCancel
                                                                       handler:^{}]]];
        self.context = nil;
    }
}

- (void)willDisappear
{
    [super willDisappear];

    [self invalidateUserActivity];

    if (self.currentOperation)
    {
        self.currentOperation.cancelled = YES;
    }

    [self.timerReminder invalidate];
    [self.timerInterfaceReminder stop];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:SPMWatchSessionNotificationReceivedMessage
                                                  object:nil];
}

- (void)dealloc
{
    [self.timerReminder invalidate];

    [self.extensionDelegate removeObserver:self
                                  forKeyPath:@"currentSpot.timeLimit"
                                     context:MapInterfaceControllerContext];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSSystemClockDidChangeNotification
                                                  object:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSCalendarDayChangedNotification
                                                  object:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:SPMWatchSessionNotificationReceivedMessage
                                                  object:nil];
}

#pragma mark - Interface

- (void)updateParkingTimeLimit
{
    ParkingTimeLimit *timeLimit = self.extensionDelegate.currentSpot.timeLimit;
    if (!timeLimit)
    {
        [self.timerInterfaceReminder stop];
        self.timerInterfaceReminder.hidden = YES;
        self.labelRemaining.text = NSLocalizedString(@"Set Time Limit", nil);
        self.labelRemaining.textColor = [UIColor whiteColor];
        self.imageBell.hidden = YES;
        [self.buttonTimeLimit setHeight:37.5];
        [self.timerReminder invalidate];
        self.timerReminder = nil;
    }
    else if ([timeLimit isExpired])
    {
        [self.timerInterfaceReminder stop];
        self.timerInterfaceReminder.hidden = YES;
        self.labelRemaining.text = NSLocalizedString(@"Time Limit Expired", nil);
        self.labelRemaining.textColor = [timeLimit textColorForThreshold:SPMParkingTimeLimitThresholdExpired];
        self.imageBell.hidden = YES;
        [self.buttonTimeLimit setHeight:37.5];
        [self.timerReminder invalidate];
        self.timerReminder = nil;
    }
    else
    {
        if (!self.timerReminder)
        {
            self.timerReminder = [NSTimer timerWithTimeInterval:60
                                                         target:self
                                                       selector:@selector(updateParkingTimeLimit)
                                                       userInfo:nil
                                                        repeats:YES];
            [[NSRunLoop currentRunLoop] addTimer:self.timerReminder
                                         forMode:NSRunLoopCommonModes];
        }

        NSDate *endDate = timeLimit.endDate;
        self.timerInterfaceReminder.date = endDate;
        [self.timerInterfaceReminder start];
        self.timerInterfaceReminder.hidden = NO;
        self.labelRemaining.text = NSLocalizedString(@"⇢", nil);
        UIColor *textColor = [timeLimit textColor];
        self.labelRemaining.textColor = textColor;
        self.timerInterfaceReminder.textColor = textColor;
        self.imageBell.hidden = NO;
        self.imageBell.tintColor = textColor;
        [self.buttonTimeLimit setHeight:37.5];
    }
}

- (void)updateParkingDate
{
    NSDate *date = self.extensionDelegate.currentSpot.date;
    if (!date)
    {
        self.title = NSLocalizedString(@"Parked", nil);
        return;
    }

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.doesRelativeDateFormatting = YES;
    formatter.locale = [NSLocale currentLocale];
    formatter.timeStyle = NSDateFormatterShortStyle;

    self.parkedOnSameDay = [[NSCalendar currentCalendar] isDate:date
                                                inSameDayAsDate:[NSDate date]];

    if (!self.parkedOnSameDay)
    {
        formatter.dateStyle = NSDateFormatterShortStyle;
        self.title = [formatter stringFromDate:date];
    }
    else
    {
        self.title = [NSString stringWithFormat:NSLocalizedString(@"Parked at %@", nil), [formatter stringFromDate:date]];
    }
}

- (void)updateInterface
{
    [self updateParkingDate];
    [self updateParkingTimeLimit];
    [self.interfaceMap SPMSetCurrentParkingSpot:self.extensionDelegate.currentSpot];
}

#pragma mark - Notifications

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context == MapInterfaceControllerContext)
    {
        if ([keyPath isEqualToString:@"currentSpot.timeLimit"])
        {
            if (![change[NSKeyValueChangeOldKey] isEqual:change[NSKeyValueChangeNewKey]])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self updateParkingTimeLimit];
                });
            }
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

    //    NSLog(@"Watch (Map) Received Message from App %@", message);

    dispatch_async(dispatch_get_main_queue(), ^{
        if ([message[SPMWatchResponseStatus] isEqualToString:SPMWatchResponseSuccess])
        {
            if ([message[SPMWatchAction] isEqualToString:SPMWatchActionRemoveParkingSpot])
            {
                [self dismissController];
            }
            else if ([message[SPMWatchAction] isEqualToString:SPMWatchActionGetParkingSpot])
            {
                [self updateInterface];
            }
        }
    });
}

- (void)timeDidChangeSignificantly:(NSNotification *)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        //        NSLog(@"Significant time change %@", notification);
        [self updateParkingDate];
    });
}

#pragma mark - Actions

- (IBAction)removeParkingSpotTouched
{
    [self setLoadingIndicatorHidden:NO
                           animated:YES];

    WatchConnectivityOperation *localOperation = [[WatchConnectivityOperation alloc] init];
    self.currentOperation = localOperation;

    self.title = nil;

    self.buttonCancel.alpha = 0;

    self.labelLoading.text = NSLocalizedString(@"Removing\nParking Spot", nil);

    [[WCSession defaultSession] sendMessage:@{SPMWatchAction: SPMWatchActionRemoveParkingSpot}
                               replyHandler:^(NSDictionary<NSString *,id> * _Nonnull replyMessage) {
                                   dispatch_async(dispatch_get_main_queue(), ^{
                                       if (localOperation.cancelled)
                                       {
                                           //                               NSLog(@"Operation cancelled %p, self.current %p", localOperation, self.currentOperation);

                                           if ([replyMessage[SPMWatchResponseStatus] isEqualToString:SPMWatchResponseSuccess])
                                           {
                                               [[WKInterfaceDevice currentDevice] playHaptic:WKHapticTypeClick];
                                               self.extensionDelegate.currentSpot = nil;
                                           }

                                           [[NSNotificationCenter defaultCenter] postNotificationName:SPMWatchSessionNotificationReceivedMessage
                                                                                               object:nil
                                                                                             userInfo:replyMessage];

                                           return;
                                       }

                                       //                           NSLog(@"Watch received reply: %@", replyMessage);

                                       if ([replyMessage[SPMWatchResponseStatus] isEqualToString:SPMWatchResponseSuccess])
                                       {
                                           [[WKInterfaceDevice currentDevice] playHaptic:WKHapticTypeClick];
                                           self.extensionDelegate.currentSpot = nil;
                                           [self dismissController];
                                       }
                                       else
                                       {
                                           [self displayErrorMessage:NSLocalizedString(@"Could Not Remove Parking Point", nil)];
                                       }
                                       self.buttonCancel.alpha = 1;
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

                                       [self displayErrorMessage:NSLocalizedString(@"Could Not Remove Parking Point", nil)];
                                       self.currentOperation = nil;
                                       self.buttonCancel.alpha = 1;
                                   });
                               }];
}

- (IBAction)touchedTimeLimit
{
    ParkingTimeLimit *timeLimit = self.extensionDelegate.currentSpot.timeLimit;
    if (!timeLimit)
    {
        [self presentControllerWithName:@"TimeLimit"
                                context:nil];
    }
    else if ([timeLimit isExpired])
    {
        NSString *message = [NSString stringWithFormat:NSLocalizedString(@"The time limit of %@ expired %@ ago", nil),
                             [timeLimit localizedLengthString],
                             [timeLimit localizedExpiredAgoString]];
        WKAlertAction *actionRemove = [WKAlertAction actionWithTitle:NSLocalizedString(@"Remove", nil)
                                                               style:WKAlertActionStyleDestructive
                                                             handler:^{
                                                                 // Because we can't do the animations properly otherwise!
                                                                 self.needsTimeLimitRemovalOnAppearance = YES;
                                                             }];

        [self presentAlertControllerWithTitle:NSLocalizedString(@"Time Limit Expired", nil)
                                      message:message
                               preferredStyle:WKAlertControllerStyleAlert
                                      actions:@[actionRemove]];
    }
    else
    {
        NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to remove the time limit of %@?", nil), [timeLimit localizedLengthString]];
        WKAlertAction *actionRemove = [WKAlertAction actionWithTitle:NSLocalizedString(@"Remove", nil)
                                                               style:WKAlertActionStyleDestructive
                                                             handler:^{
                                                                 // Because we can't do the animations properly otherwise!
                                                                 self.needsTimeLimitRemovalOnAppearance = YES;
                                                             }];

        [self presentAlertControllerWithTitle:NSLocalizedString(@"Remove Time Limit", nil)
                                      message:message
                               preferredStyle:WKAlertControllerStyleActionSheet
                                      actions:@[actionRemove]];
    }
}

- (void)removeTimeLimit
{
    [self setLoadingIndicatorHidden:NO
                           animated:YES];

    WatchConnectivityOperation *localOperation = [[WatchConnectivityOperation alloc] init];
    self.currentOperation = localOperation;

    self.labelLoading.text = NSLocalizedString(@"Removing\nTime Limit", nil);

    [[WCSession defaultSession] sendMessage:@{SPMWatchAction: SPMWatchActionRemoveParkingTimeLimit}
                               replyHandler:^(NSDictionary<NSString *,id> * _Nonnull replyMessage) {
                                   dispatch_async(dispatch_get_main_queue(), ^{
                                       if (localOperation.cancelled)
                                       {
                                           //                               NSLog(@"Operation cancelled %p, self.current %p", localOperation, self.currentOperation);

                                           if ([replyMessage[SPMWatchResponseStatus] isEqualToString:SPMWatchResponseSuccess])
                                           {
                                               [[WKInterfaceDevice currentDevice] playHaptic:WKHapticTypeClick];
                                               self.extensionDelegate.currentSpot.timeLimit = nil;
                                           }

                                           [[NSNotificationCenter defaultCenter] postNotificationName:SPMWatchSessionNotificationReceivedMessage
                                                                                               object:nil
                                                                                             userInfo:replyMessage];

                                           return;
                                       }

                                       //                           NSLog(@"Watch received reply: %@", replyMessage);

                                       if ([replyMessage[SPMWatchResponseStatus] isEqualToString:SPMWatchResponseSuccess])
                                       {
                                           [[WKInterfaceDevice currentDevice] playHaptic:WKHapticTypeClick];
                                           self.extensionDelegate.currentSpot.timeLimit = nil;

                                           [self updateParkingTimeLimit];
                                           [self setLoadingIndicatorHidden:YES
                                                                  animated:YES];
                                       }
                                       else
                                       {
                                           [self displayErrorMessage:NSLocalizedString(@"Could Not Remove Time Limit", nil)];
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
                                       
                                       [self displayErrorMessage:NSLocalizedString(@"Could Not Remove Time Limit", nil)];
                                       self.currentOperation = nil;
                                   });
                               }];
}

@end
