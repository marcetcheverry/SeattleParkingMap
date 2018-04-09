//
//  SPMMapInterfaceController.m
//  SeattleParkingMap
//
//  Created by Marc on 12/5/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

#import "SPMMapInterfaceController.h"

#import "WKInterfaceMap+SPM.h"

@interface SPMMapInterfaceController () <WCSessionDelegate>

@property (weak, nonatomic) IBOutlet WKInterfaceMap *interfaceMap;
@property (nonatomic) BOOL parkedOnSameDay;

@end

@implementation SPMMapInterfaceController

- (void)awakeWithContext:(id)context
{
    [super awakeWithContext:context];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(timeDidChangeSignificantly:)
                                                 name:NSSystemClockDidChangeNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(timeDidChangeSignificantly:)
                                                 name:NSCalendarDayChangedNotification
                                               object:nil];

    [self updateInterfaceWithContext:context];
}

- (void)willActivate
{
    [super willActivate];

    NSDate *date = [self extensionDelegate].lastParkingSpot[SPMWatchObjectParkingDate];

    if (date)
    {
        if (self.parkedOnSameDay != [[NSCalendar currentCalendar] isDate:date inSameDayAsDate:[NSDate date]])
        {
            [self updateParkingDateWithContext:[self extensionDelegate].lastParkingSpot];
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
                                                 name:SPMWatchSessionNotficationReceivedMessage
                                               object:nil];
}

- (void)willDisappear
{
    [super willDisappear];

    [self invalidateUserActivity];

    if (self.currentOperation)
    {
        self.currentOperation[@"cancelled"] = @YES;
    }

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:SPMWatchSessionNotficationReceivedMessage
                                                  object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSSystemClockDidChangeNotification
                                                  object:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSCalendarDayChangedNotification
                                                  object:nil];
}

#pragma makr - Interface

- (void)timeDidChangeSignificantly:(NSNotification *)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        //        NSLog(@"Significant time change %@", notification);
        [self updateParkingDateWithContext:[self extensionDelegate].lastParkingSpot];
    });
}

- (void)updateParkingDateWithContext:(nonnull NSDictionary *)context
{
    NSParameterAssert(context);

    NSDate *date = context[SPMWatchObjectParkingDate];
    NSParameterAssert(date);

    if (!date)
    {
        self.title = NSLocalizedString(@"Parked", nil);
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

- (void)updateInterfaceWithContext:(nonnull NSDictionary *)context
{
    NSParameterAssert(context);

    if ([context isKindOfClass:[NSDictionary class]])
    {
        [self updateParkingDateWithContext:context];
        [self.interfaceMap SPMSetCurrentParkingSpot:context];
    }
}

#pragma mark - Notifications

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
            else if ([message[SPMWatchAction] isEqualToString:SPMWatchActionGetParkingPoint])
            {
                [self updateInterfaceWithContext:message];
            }
        }
    });
}

#pragma mark - Actions

- (IBAction)removeParkingSpotTouched
{
    [self setLoadingIndicatorHidden:NO animated:YES];

    NSMutableDictionary *currentOperationDictionary = [[NSMutableDictionary alloc] initWithObjectsAndKeys:@(NO), @"cancelled", nil];
    self.currentOperation = currentOperationDictionary;

    self.title = nil;

    self.labelLoading.text = NSLocalizedString(@"Removing\nParking Spot", nil);

    [[WCSession defaultSession] sendMessage:@{SPMWatchAction: SPMWatchActionRemoveParkingSpot}
                               replyHandler:^(NSDictionary<NSString *,id> * _Nonnull replyMessage) {
                                   dispatch_async(dispatch_get_main_queue(), ^{
                                       if ([currentOperationDictionary[@"cancelled"] boolValue])
                                       {
                                           //                               NSLog(@"Operation cancelled %p, self.current %p", currentOperationDictionary, self.currentOperation);

                                           if ([replyMessage[SPMWatchResponseStatus] isEqualToString:SPMWatchResponseSuccess])
                                           {
                                               [[WKInterfaceDevice currentDevice] playHaptic:WKHapticTypeClick];
                                               [self extensionDelegate].lastParkingSpot = nil;
                                           }

                                           [[NSNotificationCenter defaultCenter] postNotificationName:SPMWatchSessionNotficationReceivedMessage
                                                                                               object:nil
                                                                                             userInfo:replyMessage];

                                           return;
                                       }

                                       //                           NSLog(@"Watch received reply: %@", replyMessage);

                                       if ([replyMessage[SPMWatchResponseStatus] isEqualToString:SPMWatchResponseSuccess])
                                       {
                                           [[WKInterfaceDevice currentDevice] playHaptic:WKHapticTypeClick];
                                           [self extensionDelegate].lastParkingSpot = nil;
                                           [self dismissController];
                                       }
                                       else
                                       {
                                           [self displayErrorMessage:NSLocalizedString(@"Could Not Remove Parking Point", nil)];
                                       }
                                       self.currentOperation = nil;
                                   });
                               }
                               errorHandler:^(NSError * _Nonnull error) {
                                   dispatch_async(dispatch_get_main_queue(), ^{
                                       if ([currentOperationDictionary[@"cancelled"] boolValue])
                                       {
                                           //                               NSLog(@"Operation cancelled %p, self.current %p", currentOperationDictionary, self.currentOperation);
                                           return;
                                       }
                                       
                                       [self displayErrorMessage:NSLocalizedString(@"Could Not Remove Parking Point", nil)];
                                       self.currentOperation = nil;
                                   });
                               }];
}

@end
