//
//  AppDelegate.m
//  Seattle Parking Map
//
//  Created by Marc on 6/5/14.
//  Copyright (c) 2014 Tap Light Software. All rights reserved.
//

#import "AppDelegate.h"

#import "RootViewController.h"

#import "ParkingManager.h"
#import "ParkingSpot.h"
#import "ParkingTimeLimit.h"

@import AudioToolbox;

@interface AppDelegate () <CLLocationManagerDelegate, WCSessionDelegate>

@property (nonatomic) BOOL applicationConfiguredForForegroundOperation;
@property (nonatomic, strong) UIAlertController *lastTimeLimitNotificationAlertController;

// WatchKit
@property (nonatomic) CLLocationManager *locationManager;
@property (nullable, nonatomic) ParkingTimeLimit *setParkingSpotTimeLimit;
@property (nullable, nonatomic, copy) void(^setParkingSpotReplyHandler)(NSDictionary<NSString *, id> *replyMessage);

@end

@implementation AppDelegate

#pragma mark - UIApplicationDelegate

- (void)configureApplicationForForegroundOperation
{
    if (self.applicationConfiguredForForegroundOperation)
    {
        return;
    }

    NSError *error;
    [AGSRuntimeEnvironment setClientID:SPM_API_KEY_ARCGIS_CLIENT_ID error:&error];
    if (error)
    {
        NSLog(@"Error using client ID: %@", [error localizedDescription]);
        [Flurry logError:@"ArcGIS_setClientID" message:@"Could not setClientID on startup" error:error];
    }

    self.applicationConfiguredForForegroundOperation = YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    if ([WCSession isSupported])
    {
        WCSession *session = [WCSession defaultSession];
        session.delegate = self;
        [session activateSession];
    }

    [Flurry setCrashReportingEnabled:YES];

#ifdef DEBUG
    //    [Flurry setLogLevel:FlurryLogLevelDebug];
    [Flurry startSession:SPM_API_KEY_FLURRY_DEV];
#else
    [Flurry setLogLevel:FlurryLogLevelNone];
    [Flurry startSession:SPM_API_KEY_FLURRY_PROD];
#endif

    // Search
    //    [UITextField appearance].keyboardAppearance = UIKeyboardAppearanceDark;
    [UIApplication sharedApplication].idleTimerDisabled = YES;

    if ([UIApplication sharedApplication].applicationState != UIApplicationStateBackground)
    {
        [self configureApplicationForForegroundOperation];
    }

    BOOL renderMapsAtNativeResolution = NO;

    if ([[UIScreen mainScreen] scale] > 1)
    {
        renderMapsAtNativeResolution = YES;
    }

    [[NSUserDefaults standardUserDefaults] registerDefaults:@{SPMDefaultsShownInitialWarning: @(NO),
                                                              SPMDefaultsNeedsBackgroundLocationWarning: @(NO),
                                                              SPMDefaultsLegendOpacity: @(.75),
                                                              SPMDefaultsLegendHidden: @(NO),
                                                              SPMDefaultsSelectedMapType: @(SPMMapTypeStreet),
                                                              SPMDefaultsSelectedMapProvider: @(SPMMapProviderSDOT),
                                                              //                                                              SPMDefaultsRenderLabelsAtNativeResolution: @(NO),
                                                              SPMDefaultsRenderMapsAtNativeResolution: @(renderMapsAtNativeResolution),
                                                              SPMDefaultsLastParkingTimeLimitReminderThreshold: @(SPMDefaultsParkingTimeLimitReminderThreshold)}
     ];

    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    [UIApplication sharedApplication].idleTimerDisabled = NO;

    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    [UIApplication sharedApplication].idleTimerDisabled = YES;

    [self configureApplicationForForegroundOperation];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.

    // Clear old notifications
    [UIApplication sharedApplication].scheduledLocalNotifications = [UIApplication sharedApplication].scheduledLocalNotifications;

    if (self.lastTimeLimitNotificationAlertController)
    {
        NSAssert([ParkingManager sharedManager].currentSpot.timeLimit, @"Alert must not be shown if the parking spot time limit is off");
        if (![ParkingManager sharedManager].currentSpot.timeLimit)
        {
            [self.lastTimeLimitNotificationAlertController dismissViewControllerAnimated:YES
                                                                              completion:nil];
        }
    }
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings
{
    [[NSUserDefaults standardUserDefaults] setBool:YES
                                            forKey:SPMDefaultsRegisteredForLocalNotifications];

    if (notificationSettings.types != UIUserNotificationTypeNone)
    {
        [[ParkingManager sharedManager] scheduleTimeLimitNotifications];
    }
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification
{
    if (self.lastTimeLimitNotificationAlertController)
    {
        [self.lastTimeLimitNotificationAlertController dismissViewControllerAnimated:YES
                                                                          completion:^{
                                                                              self.lastTimeLimitNotificationAlertController = nil;
                                                                              [self application:application
                                                                    didReceiveLocalNotification:notification];
                                                                          }];
        return;
    }

    if ([notification.category isEqualToString:SPMNotificationCategoryTimeLimit])
    {
        if ([WCSession isSupported] && [WCSession defaultSession].isReachable)
        {
            [[WCSession defaultSession] sendMessage:@{SPMWatchAction: SPMWatchActionUpdateComplications}
                                       replyHandler:nil
                                       errorHandler:^(NSError * _Nonnull error) {
                                           NSLog(@"Could not send watch message %@", error);
                                       }];
        }
    }

    self.lastTimeLimitNotificationAlertController = [UIAlertController alertControllerWithTitle:notification.alertTitle
                                                                                        message:notification.alertBody
                                                                                 preferredStyle:UIAlertControllerStyleAlert];
    [self.lastTimeLimitNotificationAlertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Dismiss", nil)
                                                                                      style:UIAlertActionStyleCancel
                                                                                    handler:^(UIAlertAction * _Nonnull action) {
                                                                                        self.lastTimeLimitNotificationAlertController = nil;
                                                                                    }]];

    UIUserNotificationSettings *settings = [UIApplication sharedApplication].currentUserNotificationSettings;

    for (UIUserNotificationCategory *category in settings.categories)
    {
        if ([category.identifier isEqualToString:notification.category])
        {
            for (UIUserNotificationAction *action in [category actionsForContext:UIUserNotificationActionContextDefault])
            {
                UIAlertActionStyle style = UIAlertActionStyleDefault;
                if (action.isDestructive)
                {
                    style = UIAlertActionStyleDestructive;
                }
                [self.lastTimeLimitNotificationAlertController addAction:[UIAlertAction actionWithTitle:action.title
                                                                                                  style:style
                                                                                                handler:^(UIAlertAction * _Nonnull alertAction) {
                                                                                                    [self application:application
                                                                                           handleActionWithIdentifier:action.identifier
                                                                                                 forLocalNotification:notification
                                                                                                    completionHandler:^{
                                                                                                        self.lastTimeLimitNotificationAlertController = nil;
                                                                                                    }];
                                                                                                }]];
            }

            break;
        }
    }

    // Chain them (test case, other alert controllers present, or information panel is up
    UIViewController *presentingViewController = self.window.rootViewController;

    while ([presentingViewController presentedViewController] != nil)
    {
        presentingViewController = [presentingViewController presentedViewController];
    }

    [presentingViewController presentViewController:self.lastTimeLimitNotificationAlertController
                                           animated:YES
                                         completion:^{
                                             NSArray *resource = [notification.soundName componentsSeparatedByString:@"."];
                                             NSAssert([resource count] == 2, @"Can not separate soundName");
                                             if ([resource count] == 2)
                                             {
                                                 NSString *notificationSound = [[NSBundle mainBundle] pathForResource:[resource firstObject]
                                                                                                               ofType:[resource lastObject]];
                                                 NSURL *notificationURL = [NSURL fileURLWithPath:notificationSound];
                                                 SystemSoundID notificationSoundID;
                                                 AudioServicesCreateSystemSoundID((__bridge CFURLRef)notificationURL, &notificationSoundID);
                                                 AudioServicesPlaySystemSound(notificationSoundID);
                                             }
                                         }];
}

- (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forLocalNotification:(UILocalNotification *)notification completionHandler:(void (^)())completionHandler
{
    if ([identifier isEqualToString:SPMNotificationActionRemoveSpot])
    {
        NSDictionary *currentParkingSpot = [[NSUserDefaults standardUserDefaults] objectForKey:SPMDefaultsLastParkingPoint];
        NSDictionary *notificationParkingSpot = notification.userInfo[SPMNotificationUserInfoKeyParkingSpot];
        NSAssert([currentParkingSpot isEqualToDictionary:notificationParkingSpot], @"Current parking spot and notification parking spot don't match!");
        if ([currentParkingSpot isEqualToDictionary:notificationParkingSpot])
        {
            RootViewController *rootViewController = (RootViewController *)self.window.rootViewController;
            [rootViewController removeParkingSpotFromSource:SPMParkingSpotActionSourceNotification];
        }
        else
        {
            NSLog(@"Warning attempting to remove parking spot %@, when the current one is %@", notificationParkingSpot, currentParkingSpot);
        }

        if (self.lastTimeLimitNotificationAlertController)
        {
            [self.lastTimeLimitNotificationAlertController dismissViewControllerAnimated:YES
                                                                              completion:^{
                                                                                  self.lastTimeLimitNotificationAlertController = nil;
                                                                              }];
        }
    }
    completionHandler();
}

- (void)application:(UIApplication *)application performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(void (^)(BOOL))completionHandler
{
    if ([shortcutItem.type isEqualToString:SPMShortcutItemTypeParkInCurrentLocation])
    {
        RootViewController *rootViewController = (RootViewController *)self.window.rootViewController;
        NSError *error;
        if ([rootViewController setParkingSpotInCurrentLocationFromSource:SPMParkingSpotActionSourceQuickAction
                                                                    error:&error])
        {
            completionHandler(YES);
        }
        else
        {
            NSLog(@"Could not set parking spot from shortcutItem: %@", error);
            completionHandler(NO);
        }
        return;
    }
    else if ([shortcutItem.type isEqualToString:SPMShortcutItemTypeRemoveParkingSpot])
    {
        RootViewController *rootViewController = (RootViewController *)self.window.rootViewController;
        [rootViewController removeParkingSpotFromSource:SPMParkingSpotActionSourceQuickAction];
    }

    completionHandler(YES);
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray<CLLocation *> *)locations
{
    //    NSLog(@"%@: %@", NSStringFromSelector(_cmd), locations);

    if (self.setParkingSpotReplyHandler)
    {
        NSAssert([locations count] > 0, @"Must have at least one location");
        if (![locations count])
        {
            NSError *error = [NSError errorWithDomain:SPMErrorDomain
                                                 code:SPMErrorCodeLocationUnknown
                                             userInfo:@{NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"Could Not Find Your Current Location", nil)}];

            self.setParkingSpotReplyHandler(@{SPMWatchAction: SPMWatchActionSetParkingSpot,
                                              SPMWatchResponseStatus: SPMWatchResponseFailure,
                                              NSLocalizedFailureReasonErrorKey: error.userInfo[NSLocalizedFailureReasonErrorKey]});

            [Flurry logError:@"ParkingSpot_SetFromWatch_Failure"
                     message:@"Could Not Find Your Current Location"
                       error:error];

            self.setParkingSpotTimeLimit = nil;
            self.setParkingSpotReplyHandler = nil;
            return;
        }

        CLLocation *location = [locations firstObject];

        NSDate *parkDate;

        // Make sure that we use the date a watch passes to us, for example
        if (self.setParkingSpotTimeLimit.startDate)
        {
            parkDate = self.setParkingSpotTimeLimit.startDate;
        }
        else
        {
            parkDate = [NSDate date];
        }
        
        ParkingSpot *parkingSpot = [[ParkingSpot alloc] initWithLocation:location
                                                                          date:parkDate];

        if (self.setParkingSpotTimeLimit)
        {
            parkingSpot.timeLimit = self.setParkingSpotTimeLimit;
        }

        [ParkingManager sharedManager].currentSpot = parkingSpot;

        NSDictionary *replyDictionary;

        if ([ParkingManager sharedManager].currentSpot)
        {
            replyDictionary = @{SPMWatchAction: SPMWatchActionSetParkingSpot,
                                SPMWatchResponseStatus: SPMWatchResponseSuccess,
                                SPMWatchObjectParkingSpot: [[ParkingManager sharedManager].currentSpot watchConnectivityDictionaryRepresentation]};

            if (parkingSpot.timeLimit &&
                [self shouldWarnWatchAboutRespondingToNotificationPrompt])
            {
                NSMutableDictionary *mutableReplyDictionary = [replyDictionary mutableCopy];
                mutableReplyDictionary[SPMWatchObjectWarningMessage] = [self watchWarningMessageEnableNotifications];
                replyDictionary = mutableReplyDictionary;
            }
        }
        else
        {
            NSLog(@"%@: Failed to set parking spot %@", NSStringFromSelector(_cmd), [ParkingManager sharedManager]);
            replyDictionary = @{SPMWatchAction: SPMWatchActionSetParkingSpot,
                                SPMWatchResponseStatus: SPMWatchResponseFailure};
        }

        self.setParkingSpotReplyHandler(replyDictionary);

        self.setParkingSpotTimeLimit = nil;
        self.setParkingSpotReplyHandler = nil;

        [Flurry logEvent:@"ParkingSpot_SetFromWatch_Success"];

        // Edge case if we do it in the background and we launch entirely before as the spot is set.
        if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive)
        {
            RootViewController *rootViewController = (RootViewController *)self.window.rootViewController;
            dispatch_async(dispatch_get_main_queue(), ^{
                [rootViewController synchronizeParkingSpotDisplayFromDataStore];
            });
        }
    }

    self.locationManager.delegate = nil;
    self.locationManager = nil;
}

- (void)locationManager:(CLLocationManager *)manager
       didFailWithError:(NSError *)error
{
    NSLog(@"%@: %@", NSStringFromSelector(_cmd), error);

    if (self.setParkingSpotReplyHandler)
    {
        NSError *watchError = [NSError errorWithDomain:SPMErrorDomain
                                                  code:SPMErrorCodeLocationUnknown
                                              userInfo:@{NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"Could Not Find Your Current Location", nil),
                                                         NSUnderlyingErrorKey: error}];

        self.setParkingSpotReplyHandler(@{SPMWatchAction: SPMWatchActionSetParkingSpot,
                                          SPMWatchResponseStatus: SPMWatchResponseFailure,
                                          NSLocalizedFailureReasonErrorKey: watchError.userInfo[NSLocalizedFailureReasonErrorKey]});

        [Flurry logError:@"ParkingSpot_SetFromWatch_Failure"
                 message:@"Could Not Find Your Current Location"
                   error:error];

        self.setParkingSpotTimeLimit = nil;
        self.setParkingSpotReplyHandler = nil;
    }

    self.locationManager.delegate = nil;
    self.locationManager = nil;
}

#pragma mark - WCSessionDelegate

- (BOOL)shouldWarnWatchAboutRespondingToNotificationPrompt
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SPMDefaultsRegisteredForLocalNotifications])
    {
        return NO;
    }

    return YES;
}

- (nonnull NSString *)watchWarningMessageEnableNotifications
{
    return NSLocalizedString(@"Please enable notifications on your iPhone to be reminded when your time limit is about to expire.", nil);
}

- (void)session:(WCSession *)session didReceiveApplicationContext:(NSDictionary<NSString *, id> *)applicationContext
{
    NSNumber *userDefinedlimit = applicationContext[SPMWatchContextUserDefinedParkingTimeLimit];
    if (userDefinedlimit)
    {
        [[NSUserDefaults standardUserDefaults] setObject:userDefinedlimit
                                                  forKey:SPMDefaultsUserDefinedParkingTimeLimit];
    }
}

- (void)session:(WCSession *)session didReceiveMessage:(NSDictionary<NSString *, id> *)message replyHandler:(void(^)(NSDictionary<NSString *, id> *replyMessage))replyHandler
{
    //    NSLog(@"App Received Message from Watch %@", message);

    if ([message[SPMWatchAction] isEqualToString:SPMWatchActionRemoveParkingSpot])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive)
            {
                [ParkingManager sharedManager].currentSpot = nil;

                replyHandler(@{SPMWatchAction: message[SPMWatchAction],
                               SPMWatchResponseStatus: SPMWatchResponseSuccess});

                // Edge case if we do it in the background and we launch entirely before as the spot is removed.
                if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive)
                {
                    [Flurry logEvent:@"ParkingSpot_RemoveFromWatch"];
                    RootViewController *rootViewController = (RootViewController *)self.window.rootViewController;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [rootViewController synchronizeParkingSpotDisplayFromDataStore];
                    });
                }
            }
            else
            {
                if (self.lastTimeLimitNotificationAlertController)
                {
                    [self.lastTimeLimitNotificationAlertController dismissViewControllerAnimated:YES
                                                                                      completion:nil];
                }

                // dispatch_after for testing cancellation
                RootViewController *rootViewController = (RootViewController *)self.window.rootViewController;
                [rootViewController removeParkingSpotFromSource:SPMParkingSpotActionSourceWatch];
                replyHandler(@{SPMWatchAction: message[SPMWatchAction],
                               SPMWatchResponseStatus: SPMWatchResponseSuccess});
            }
        });
    }
    else if ([message[SPMWatchAction] isEqualToString:SPMWatchActionSetParkingSpot])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            // OpenGL will crash on the background!
            if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive)
            {
                NSError *error;

                CLAuthorizationStatus authorizationStatus = [CLLocationManager authorizationStatus];
                if (authorizationStatus != kCLAuthorizationStatusAuthorizedAlways &&
                    authorizationStatus != kCLAuthorizationStatusAuthorizedWhenInUse)
                {
                    error = [NSError errorWithDomain:SPMErrorDomain
                                                code:SPMErrorCodeLocationAuthorization
                                            userInfo:@{NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"Open the App on iPhone to Enable Watch Location Support", nil)}];
                }
                else if (authorizationStatus == kCLAuthorizationStatusAuthorizedWhenInUse)
                {
                    [[NSUserDefaults standardUserDefaults] setBool:YES
                                                            forKey:SPMDefaultsNeedsBackgroundLocationWarning];

                    error = [NSError errorWithDomain:SPMErrorDomain
                                                code:SPMErrorCodeLocationBackgroundAuthorization
                                            userInfo:@{NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"Open the App on iPhone to Enable Watch Location Support", nil)}];
                }

                if (error)
                {
                    replyHandler(@{SPMWatchAction: message[SPMWatchAction],
                                   SPMWatchResponseStatus: SPMWatchResponseFailure,
                                   NSLocalizedFailureReasonErrorKey: error.userInfo[NSLocalizedFailureReasonErrorKey]});
                    return;
                }

                if (!self.locationManager)
                {
                    self.locationManager = [[CLLocationManager alloc] init];
                    self.locationManager.delegate = self;
                    self.locationManager.allowsBackgroundLocationUpdates = YES;
                    self.locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation;
                }

                [self.locationManager requestLocation];

                self.setParkingSpotTimeLimit = [[ParkingTimeLimit alloc] initWithWatchConnectivityDictionary:message[SPMWatchObjectParkingTimeLimit]];
                self.setParkingSpotReplyHandler = replyHandler;
            }
            else
            {
                // dispatch_after for testing cancellation
                RootViewController *rootViewController = (RootViewController *)self.window.rootViewController;
                NSError *error;

                NSDictionary *timeLimit = message[SPMWatchObjectParkingTimeLimit];
                ParkingTimeLimit *parkingTimeLimit;
                if (timeLimit)
                {
                    parkingTimeLimit = [[ParkingTimeLimit alloc] initWithWatchConnectivityDictionary:timeLimit];
                }
                if ([rootViewController setParkingSpotInCurrentLocationFromSource:SPMParkingSpotActionSourceWatch
                                                                        timeLimit:parkingTimeLimit
                                                                            error:&error])
                {
                    NSDictionary *parkingObject = [[ParkingManager sharedManager].currentSpot watchConnectivityDictionaryRepresentation];
                    if (parkingObject)
                    {
                        NSMutableDictionary *replyDictionary = [[NSMutableDictionary alloc] initWithCapacity:3];
                        replyDictionary[SPMWatchAction] = message[SPMWatchAction];
                        replyDictionary[SPMWatchResponseStatus] = SPMWatchResponseSuccess;
                        replyDictionary[SPMWatchObjectParkingSpot] = parkingObject;

                        if (parkingTimeLimit &&
                            [self shouldWarnWatchAboutRespondingToNotificationPrompt])
                        {
                            replyDictionary[SPMWatchObjectWarningMessage] = [self watchWarningMessageEnableNotifications];
                        }

                        replyHandler(replyDictionary);
                    }
                    else
                    {
                        error = [NSError errorWithDomain:SPMErrorDomain
                                                    code:SPMErrorCodeLocationUnknown
                                                userInfo:@{NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"Could Not Find Your Current Location", nil)}];

                        replyHandler(@{SPMWatchAction: message[SPMWatchAction],
                                       SPMWatchResponseStatus: SPMWatchResponseFailure,
                                       NSLocalizedFailureReasonErrorKey: error.userInfo[NSLocalizedFailureReasonErrorKey]});
                    }
                }
                else
                {
                    replyHandler(@{SPMWatchAction: message[SPMWatchAction],
                                   SPMWatchResponseStatus: SPMWatchResponseFailure,
                                   NSLocalizedFailureReasonErrorKey: error.userInfo[NSLocalizedFailureReasonErrorKey]});
                }
            }
        });
    }
    else if ([message[SPMWatchAction] isEqualToString:SPMWatchActionGetParkingSpot])
    {
        [Flurry logEvent:@"ParkingSpot_GetFromWatch"];

        NSMutableDictionary *replyDictionary = [[NSMutableDictionary alloc] initWithCapacity:3];
        replyDictionary[SPMWatchAction] = message[SPMWatchAction];
        replyDictionary[SPMWatchResponseStatus] = SPMWatchResponseSuccess;
        NSNumber *userDefinedTimeLimit = [[NSUserDefaults standardUserDefaults] objectForKey:SPMDefaultsUserDefinedParkingTimeLimit];
        if (userDefinedTimeLimit)
        {
            replyDictionary[SPMWatchObjectUserDefinedParkingTimeLimit] = userDefinedTimeLimit;
        }

        NSDictionary *parkingObject = [[ParkingManager sharedManager].currentSpot watchConnectivityDictionaryRepresentation];
        if (parkingObject)
        {
            replyDictionary[SPMWatchObjectParkingSpot] = parkingObject;
        }

        replyHandler(replyDictionary);
    }
    else if ([message[SPMWatchAction] isEqualToString:SPMWatchActionRemoveParkingTimeLimit])
    {
        [Flurry logEvent:@"ParkingTimeLimit_RemoveFromWatch_Success"];
        [ParkingManager sharedManager].currentSpot.timeLimit = nil;
        replyHandler(@{SPMWatchAction: message[SPMWatchAction],
                       SPMWatchResponseStatus: SPMWatchResponseSuccess});
    }
    else if ([message[SPMWatchAction] isEqualToString:SPMWatchActionSetParkingTimeLimit])
    {
        ParkingTimeLimit *timeLimit = [[ParkingTimeLimit alloc] initWithWatchConnectivityDictionary:message[SPMWatchObjectParkingTimeLimit]];

        if (!timeLimit || ![ParkingManager sharedManager].currentSpot)
        {
            [Flurry logError:@"ParkingTimeLimit_SetFromWatch_Failure"
                     message:@"Missing limit or current spot"
                       error:nil];
            NSLog(@"Missing length or parking spot");
            replyHandler(@{SPMWatchAction: message[SPMWatchAction],
                           SPMWatchResponseStatus: SPMWatchResponseFailure});
        }
        else
        {
            [Flurry logEvent:@"ParkingTimeLimit_SetFromWatch_Success"
              withParameters:@{@"length": timeLimit.length,
                               @"reminderThreshold": timeLimit.reminderThreshold}];
            [ParkingManager sharedManager].currentSpot.timeLimit = timeLimit;

            NSDictionary *replyDictionary = @{SPMWatchAction: message[SPMWatchAction],
                                              SPMWatchResponseStatus: SPMWatchResponseSuccess,
                                              SPMWatchObjectParkingTimeLimit: [timeLimit watchConnectivityDictionaryRepresentation]};
            if ([self shouldWarnWatchAboutRespondingToNotificationPrompt])
            {
                NSMutableDictionary *mutableReplyDictionary = [replyDictionary mutableCopy];
                mutableReplyDictionary[SPMWatchObjectWarningMessage] = [self watchWarningMessageEnableNotifications];
                replyDictionary = mutableReplyDictionary;
            }

            replyHandler(replyDictionary);
        }
    }
    else
    {
        NSAssert(NO, @"Watch Message not handled");
        NSLog(@"Watch Message not handled");
        replyHandler(nil);
    }
}

@end
