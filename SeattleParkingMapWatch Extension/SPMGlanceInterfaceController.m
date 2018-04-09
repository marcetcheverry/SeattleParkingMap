//
//  SPMGlanceInterfaceController.m
//  SeattleParkingMapWatch Extension
//
//  Created by Marc on 11/15/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

#import "SPMGlanceInterfaceController.h"

#import "WKInterfaceMap+SPM.h"

@interface SPMGlanceInterfaceController()

@property (weak, nonatomic) IBOutlet WKInterfaceMap *interfaceMap;
@property (weak, nonatomic) IBOutlet WKInterfaceLabel *labelTime;
@property (weak, nonatomic) IBOutlet WKInterfaceLabel *labelHeader;
@property (weak, nonatomic) IBOutlet WKInterfaceLabel *labelParkingIcon;

@property (nonatomic) BOOL isLoading;

@end

@implementation SPMGlanceInterfaceController

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
                                                 name:SPMWatchSessionNotficationReceivedMessage
                                               object:nil];
}

- (void)willActivate
{
    [super willActivate];

    if (self.isLoading)
    {
        return;
    }

    self.isLoading = YES;

    [[WCSession defaultSession] sendMessage:@{SPMWatchAction: SPMWatchActionGetParkingPoint}
                               replyHandler:^(NSDictionary<NSString *,id> * _Nonnull replyMessage) {
                                   dispatch_async(dispatch_get_main_queue(), ^{
                                       self.extensionDelegate.lastParkingSpot = replyMessage;
                                       //                         NSLog(@"Glance received reply: %@", replyMessage);
                                       [self updateInterface];
                                       self.isLoading = NO;
                                   });
                               }
                               errorHandler:^(NSError * _Nonnull error) {
                                   dispatch_async(dispatch_get_main_queue(), ^{
                                       //                         NSLog(@"Glance received error: %@", error);
                                       // Don't lose our data
                                       //                         ((SPMExtensionDelegate *)[WKExtension sharedExtension].delegate).lastParkingSpot = nil;
                                       //                         [self updateInterface];
                                       self.isLoading = NO;
                                   });
                               }];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:SPMWatchSessionNotficationReceivedMessage
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
    });
}

#pragma mark - Interface

- (void)timeDidChangeSignificantly:(NSNotification *)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        //        NSLog(@"Significant time change %@", notification);
        NSDictionary *lastParkingSpot = self.extensionDelegate.lastParkingSpot;
        if ([lastParkingSpot[SPMWatchResponseStatus] isEqualToString:SPMWatchResponseSuccess] &&
            lastParkingSpot[SPMWatchObjectParkingDate] != nil &&
            lastParkingSpot[SPMWatchObjectParkingPoint] != nil)
        {
            [self updateParkingDateWithParkingSpot:lastParkingSpot];
        }
    });
}

- (void)updateParkingDateWithParkingSpot:(nonnull NSDictionary *)lastParkingSpot
{
    NSParameterAssert(lastParkingSpot);

    NSDate *date = lastParkingSpot[SPMWatchObjectParkingDate];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.doesRelativeDateFormatting = YES;
    formatter.locale = [NSLocale currentLocale];
    formatter.dateStyle = NSDateFormatterShortStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;
    self.labelTime.text = [formatter stringFromDate:date];
}

- (void)updateInterface
{
    NSDictionary *lastParkingSpot = self.extensionDelegate.lastParkingSpot;
    if ([lastParkingSpot[SPMWatchResponseStatus] isEqualToString:SPMWatchResponseSuccess] &&
        lastParkingSpot[SPMWatchObjectParkingDate] != nil &&
        lastParkingSpot[SPMWatchObjectParkingPoint] != nil)
    {
        self.labelHeader.text = NSLocalizedString(@"Parked", nil);

        [self updateParkingDateWithParkingSpot:lastParkingSpot];

        self.interfaceMap.hidden = NO;
        self.labelParkingIcon.hidden = YES;

        [self animateWithDuration:0.3
                       animations:^{
                           self.interfaceMap.alpha = 1;
                           self.labelParkingIcon.alpha = 0;
                       }];

        [self.interfaceMap SPMSetCurrentParkingSpot:lastParkingSpot];

        [self invalidateUserActivity];
    }
    else
    {
        //        NSLog(@"Glance Debug: Setting Tap To Park %@", lastParkingSpot);
        self.labelHeader.text = NSLocalizedString(@"Seattle Parking", nil);
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
