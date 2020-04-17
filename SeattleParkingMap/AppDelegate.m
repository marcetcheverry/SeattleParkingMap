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
#import "Analytics.h"
#import "WCSession+SPM.h"

@import UserNotifications;

@interface AppDelegate () <CLLocationManagerDelegate, WCSessionDelegate, UNUserNotificationCenterDelegate>

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
    [AGSArcGISRuntimeEnvironment setLicenseKey:SPMExternalAPIArcGISLicenseKey error:&error];
    if (error)
    {
        NSLog(@"Error using client ID: %@", [error localizedDescription]);
        [Analytics logError:@"ArcGIS_setClientID" message:@"Could not setClientID on startup" error:error];
    }
    
    self.applicationConfiguredForForegroundOperation = YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Code for screenshots
    //    CLLocation *location = [[CLLocation alloc] initWithLatitude:47.613584
    //                                                      longitude:-122.339480];
    //    NSDate *parkDate = [NSDate date];
    //    ParkingSpot *spot = [[ParkingSpot alloc] initWithLocation:location
    //                                                         date:parkDate];
    //
    //    ParkingTimeLimit *timeLimit = [[ParkingTimeLimit alloc] initWithStartDate:parkDate
    //                                                                       length:@(20 * 60)
    //                                                            reminderThreshold:nil];
    //    spot.timeLimit = timeLimit;
    //    [ParkingManager sharedManager].currentSpot = spot;
    //

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(notificationAuthorizationDenied)
                                               name:SPMNotificationAuthorizationDeniedNotification
                                             object:nil];

    if ([WCSession isSupported])
    {
        WCSession *session = [WCSession defaultSession];
        session.delegate = self;
        [session activateSession];
    }
    
    // Search
    //    [UITextField appearance].keyboardAppearance = UIKeyboardAppearanceDark;
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateBackground)
    {
        [self configureApplicationForForegroundOperation];
    }

    [[NSUserDefaults standardUserDefaults] registerDefaults:@{SPMDefaultsShownInitialWarning: @(NO),
                                                              SPMDefaultsNeedsBackgroundLocationWarning: @(NO),
                                                              SPMDefaultsLegendOpacity: @(.75),
                                                              SPMDefaultsLegendHidden: @(NO),
                                                              SPMDefaultsSelectedMapType: @(SPMMapTypeStreet),
                                                              SPMDefaultsSelectedMapProvider: @(SPMMapProviderSDOT),
                                                              SPMDefaultsLastParkingTimeLimitReminderThreshold: @(SPMDefaultsParkingTimeLimitReminderThreshold)}
     ];

    UNUserNotificationCenter.currentNotificationCenter.delegate = self;

    UNNotificationAction *viewAction = [UNNotificationAction actionWithIdentifier:SPMNotificationActionViewSpot
                                                                            title:NSLocalizedString(@"View Parking Spot", nil)
                                                                          options:UNNotificationActionOptionForeground];

    UNNotificationAction *removeAction = [UNNotificationAction actionWithIdentifier:SPMNotificationActionRemoveSpot
                                                                              title:NSLocalizedString(@"Remove Spot", nil)
                                                                            options:UNNotificationActionOptionDestructive];

    UNNotificationCategory *timeLimit = [UNNotificationCategory categoryWithIdentifier:SPMNotificationCategoryTimeLimit
                                                                               actions:@[viewAction, removeAction]
                                                                     intentIdentifiers:@[]
                                                                               options:UNNotificationCategoryOptionAllowInCarPlay];

    [UNUserNotificationCenter.currentNotificationCenter setNotificationCategories:[NSSet setWithObjects:timeLimit, nil]];

    // Test case: reinstall
    if (![[NSUserDefaults standardUserDefaults] boolForKey:SPMDefaultsRegisteredForLocalNotifications]) {
        [UNUserNotificationCenter.currentNotificationCenter getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
             if (settings.authorizationStatus == UNAuthorizationStatusAuthorized)
            {
                [[NSUserDefaults standardUserDefaults] setBool:YES
                                                        forKey:SPMDefaultsRegisteredForLocalNotifications];
            }
        }];
    }

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
    [UNUserNotificationCenter.currentNotificationCenter removeAllDeliveredNotifications];

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

#pragma mark - Notification Permissions

- (void)notificationAuthorizationDenied
{
    dispatch_async(dispatch_get_main_queue(), ^{
        dispatch_block_t presentAlertController = ^{
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Warning", nil)
                                                                                     message:NSLocalizedString(@"Please allow notifications to be reminded about time limit expiration.", nil)
                                                                              preferredStyle:UIAlertControllerStyleAlert];

            UIAlertAction *settingsAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Open Settings", nil)
                                                                     style:UIAlertActionStyleDefault
                                                                   handler:^(UIAlertAction * _Nonnull action) {
                                                                       // I don't see the need for canOpenURL here and dependent UIAlertActions
                                                                       NSURL *settingsURL = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                                                                       [UIApplication.sharedApplication openURL:settingsURL
                                                                                                        options:@{}
                                                                                              completionHandler:nil];
                                                                   }];

            UIAlertAction *laterAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Later", nil)
                                                                  style:UIAlertActionStyleCancel
                                                                handler:nil];

            [alertController addAction:settingsAction];
            [alertController addAction:laterAction];

            self.lastTimeLimitNotificationAlertController = alertController;

            // Chain them (test case, other alert controllers present, or information panel is up
            UIViewController *presentingViewController = self.window.rootViewController;

            while ([presentingViewController presentedViewController] != nil)
            {
                presentingViewController = [presentingViewController presentedViewController];
            }


            [presentingViewController presentViewController:self.lastTimeLimitNotificationAlertController
                                                   animated:YES
                                                 completion:nil];
        };

        if (self.lastTimeLimitNotificationAlertController)
        {
            [self.lastTimeLimitNotificationAlertController dismissViewControllerAnimated:YES
                                                                              completion:^{
                                                                                  self.lastTimeLimitNotificationAlertController = nil;
                                                                                  presentAlertController();
                                                                              }];
            return;
        }

        presentAlertController();
    });
}

#pragma mark - User Notifications

- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler
{
    if (self.lastTimeLimitNotificationAlertController)
    {
        [self.lastTimeLimitNotificationAlertController dismissViewControllerAnimated:YES
                                                                          completion:^{
                                                                              self.lastTimeLimitNotificationAlertController = nil;
                                                                              [self userNotificationCenter:center
                                                                                   willPresentNotification:notification
                                                                                     withCompletionHandler:completionHandler];
                                                                          }];
        return;
    }

    self.lastTimeLimitNotificationAlertController = [UIAlertController alertControllerWithTitle:notification.request.content.title
                                                                                        message:notification.request.content.body
                                                                                 preferredStyle:UIAlertControllerStyleAlert];
    [self.lastTimeLimitNotificationAlertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Dismiss", nil)
                                                                                      style:UIAlertActionStyleCancel
                                                                                    handler:^(UIAlertAction * _Nonnull action) {
                                                                                        self.lastTimeLimitNotificationAlertController = nil;
                                                                                    }]];

    [UNUserNotificationCenter.currentNotificationCenter getNotificationCategoriesWithCompletionHandler:^(NSSet<UNNotificationCategory *> * _Nonnull categories) {
        dispatch_async(dispatch_get_main_queue(), ^{
            for (UNNotificationCategory *category in categories)
            {
                if ([category.identifier isEqualToString:notification.request.content.categoryIdentifier])
                {
                    for (UNNotificationAction *action in category.actions)
                    {
                        UIAlertActionStyle style = UIAlertActionStyleDefault;
                        if (action.options & UNNotificationActionOptionDestructive)
                        {
                            style = UIAlertActionStyleDestructive;
                        }
                        [self.lastTimeLimitNotificationAlertController addAction:[UIAlertAction actionWithTitle:action.title
                                                                                                          style:style
                                                                                                        handler:^(UIAlertAction * _Nonnull alertAction) {
                                                                                                            [self handleReceivedNotificationActionIdentifier:action.identifier
                                                                                                                                                    userInfo:notification.request.content.userInfo
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
                                                     completionHandler(UNNotificationPresentationOptionSound);
                                                 }];
        });
    }];
}

// The method will be called on the delegate when the user responded to the notification by opening the application, dismissing the notification or choosing a UNNotificationAction. The delegate must be set before the application returns from application:didFinishLaunchingWithOptions:.
- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void(^)(void))completionHandler
{
    [self handleReceivedNotificationActionIdentifier:response.actionIdentifier
                                            userInfo:response.notification.request.content.userInfo
                                   completionHandler:completionHandler];
}

- (void)handleReceivedNotificationActionIdentifier:(NSString *)actionIdentifier
                                          userInfo:(NSDictionary *)userInfo
                                 completionHandler:(void(^)(void))completionHandler
{
    if ([actionIdentifier isEqualToString:SPMNotificationActionRemoveSpot])
    {
        NSDictionary *currentParkingSpot = [[NSUserDefaults standardUserDefaults] objectForKey:SPMDefaultsLastParkingPoint];
        NSDictionary *notificationParkingSpot = userInfo[SPMNotificationUserInfoKeyParkingSpot];
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
                                              SPMErrorCode: @(error.code),
                                              NSLocalizedFailureReasonErrorKey: error.userInfo[NSLocalizedFailureReasonErrorKey]});
            
            [Analytics logError:@"ParkingSpot_SetFromWatch_Failure"
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
                mutableReplyDictionary[SPMWatchObjectWarningMessage] = WCSession.defaultSession.SPMWatchWarningMessageEnableNotifications;
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
        
        [Analytics logEvent:@"ParkingSpot_SetFromWatch_Success"];
        
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
                                          SPMErrorCode: @(error.code),
                                          NSLocalizedFailureReasonErrorKey: watchError.userInfo[NSLocalizedFailureReasonErrorKey]});
        
        [Analytics logError:@"ParkingSpot_SetFromWatch_Failure"
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

- (void)session:(WCSession *)session didReceiveApplicationContext:(NSDictionary<NSString *, id> *)applicationContext
{
    NSNumber *userDefinedlimit = applicationContext[SPMWatchContextUserDefinedParkingTimeLimit];
    if (userDefinedlimit)
    {
        [[NSUserDefaults standardUserDefaults] setObject:userDefinedlimit
                                                  forKey:SPMDefaultsUserDefinedParkingTimeLimit];
    }
}

- (void)session:(WCSession *)session didFinishUserInfoTransfer:(WCSessionUserInfoTransfer *)userInfoTransfer error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Could not transfer user info: %@, error %@", userInfoTransfer, error);
    }
    else
    {
        SPMLog(@"Transfered user info %@", userInfoTransfer);
    }
}

- (void)session:(WCSession *)session didReceiveMessage:(NSDictionary<NSString *, id> *)message replyHandler:(void(^)(NSDictionary<NSString *, id> *replyMessage))replyHandler
{
    //    NSLog(@"App Received Message from Watch %@", message);
    
    if ([message[SPMWatchAction] isEqualToString:SPMWatchActionRemoveParkingSpot])
    {
        // No need to warn the user and follow a failure path
        //        if ([ParkingManager sharedManager].currentSpot == nil)
        //        {
        //            NSError *error = [NSError errorWithDomain:SPMErrorDomain
        //                                                 code:SPMErrorCodeDataDiscrepancy
        //                                             userInfo:@{NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"The Parking Spot Was Already Removed", nil)}];
        //
        //            replyHandler(@{SPMWatchAction: message[SPMWatchAction],
        //                           SPMWatchResponseStatus: SPMWatchResponseFailure,
        //                           SPMErrorCode: @(error.code),
        //                           NSLocalizedFailureReasonErrorKey: error.userInfo[NSLocalizedFailureReasonErrorKey]});
        //            return;
        //        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive)
            {
                [ParkingManager sharedManager].currentSpot = nil;
                
                replyHandler(@{SPMWatchAction: message[SPMWatchAction],
                               SPMWatchResponseStatus: SPMWatchResponseSuccess});
                
                // Edge case if we do it in the background and we launch entirely before as the spot is removed.
                if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive)
                {
                    [Analytics logEvent:@"ParkingSpot_RemoveFromWatch"];
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
        if ([ParkingManager sharedManager].currentSpot != nil)
        {
            NSError *error = [NSError errorWithDomain:SPMErrorDomain
                                                 code:SPMErrorCodeDataDiscrepancy
                                             userInfo:@{NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"A Parking Spot is\nAlready Set", nil)}];
            
            replyHandler(@{SPMWatchAction: message[SPMWatchAction],
                           SPMWatchResponseStatus: SPMWatchResponseFailure,
                           SPMErrorCode: @(error.code),
                           SPMWatchObjectParkingSpot: [[ParkingManager sharedManager].currentSpot watchConnectivityDictionaryRepresentation],
                           NSLocalizedFailureReasonErrorKey: error.userInfo[NSLocalizedFailureReasonErrorKey]});
            return;
        }
        
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
                                   SPMErrorCode: @(error.code),
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
                        NSMutableDictionary *replyDictionary = [[NSMutableDictionary alloc] initWithCapacity:4];
                        replyDictionary[SPMWatchAction] = message[SPMWatchAction];
                        replyDictionary[SPMWatchResponseStatus] = SPMWatchResponseSuccess;
                        replyDictionary[SPMWatchObjectParkingSpot] = parkingObject;
                        
                        if (parkingTimeLimit &&
                            [self shouldWarnWatchAboutRespondingToNotificationPrompt])
                        {
                            replyDictionary[SPMWatchObjectWarningMessage] = WCSession.defaultSession.SPMWatchWarningMessageEnableNotifications;
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
                                       SPMErrorCode: @(error.code),
                                       NSLocalizedFailureReasonErrorKey: error.userInfo[NSLocalizedFailureReasonErrorKey]});
                    }
                }
                else
                {
                    replyHandler(@{SPMWatchAction: message[SPMWatchAction],
                                   SPMWatchResponseStatus: SPMWatchResponseFailure,
                                   SPMErrorCode: @(error.code),
                                   NSLocalizedFailureReasonErrorKey: error.userInfo[NSLocalizedFailureReasonErrorKey]});
                }
            }
        });
    }
    else if ([message[SPMWatchAction] isEqualToString:SPMWatchActionGetParkingSpot])
    {
        [Analytics logEvent:@"ParkingSpot_GetFromWatch"];
        
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
        // No need to warn the user and follow a failure path
        //        if ([ParkingManager sharedManager].currentSpot.timeLimit == nil)
        //        {
        //            NSError *error = [NSError errorWithDomain:SPMErrorDomain
        //                                                 code:SPMErrorCodeDataDiscrepancy
        //                                             userInfo:@{NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"The Time Limit Was Already Removed", nil)}];
        //
        //            replyHandler(@{SPMWatchAction: message[SPMWatchAction],
        //                           SPMWatchResponseStatus: SPMWatchResponseFailure,
        //                           SPMErrorCode: @(error.code),
        //                           NSLocalizedFailureReasonErrorKey: error.userInfo[NSLocalizedFailureReasonErrorKey]});
        //            return;
        //        }
        
        [Analytics logEvent:@"ParkingTimeLimit_RemoveFromWatch_Success"];
        [ParkingManager sharedManager].currentSpot.timeLimit = nil;
        replyHandler(@{SPMWatchAction: message[SPMWatchAction],
                       SPMWatchResponseStatus: SPMWatchResponseSuccess});
    }
    else if ([message[SPMWatchAction] isEqualToString:SPMWatchActionSetParkingTimeLimit])
    {
        if ([ParkingManager sharedManager].currentSpot.timeLimit != nil)
        {
            NSError *error = [NSError errorWithDomain:SPMErrorDomain
                                                 code:SPMErrorCodeDataDiscrepancy
                                             userInfo:@{NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"A Time Limit is\nAlready Set", nil)}];
            
            replyHandler(@{SPMWatchAction: message[SPMWatchAction],
                           SPMWatchResponseStatus: SPMWatchResponseFailure,
                           SPMErrorCode: @(error.code),
                           SPMWatchObjectParkingTimeLimit: [[ParkingManager sharedManager].currentSpot.timeLimit watchConnectivityDictionaryRepresentation],
                           NSLocalizedFailureReasonErrorKey: error.userInfo[NSLocalizedFailureReasonErrorKey]});
            return;
        }
        
        ParkingTimeLimit *timeLimit = [[ParkingTimeLimit alloc] initWithWatchConnectivityDictionary:message[SPMWatchObjectParkingTimeLimit]];
        
        if (!timeLimit || ![ParkingManager sharedManager].currentSpot)
        {
            [Analytics logError:@"ParkingTimeLimit_SetFromWatch_Failure"
                        message:@"Missing limit or current spot"
                          error:nil];
            NSLog(@"Missing length or parking spot");
            replyHandler(@{SPMWatchAction: message[SPMWatchAction],
                           SPMWatchResponseStatus: SPMWatchResponseFailure});
        }
        else
        {
            [Analytics logEvent:@"ParkingTimeLimit_SetFromWatch_Success"
                 withParameters:@{@"length": timeLimit.length,
                                  @"reminderThreshold": timeLimit.reminderThreshold}];
            [ParkingManager sharedManager].currentSpot.timeLimit = timeLimit;
            
            NSDictionary *replyDictionary = @{SPMWatchAction: message[SPMWatchAction],
                                              SPMWatchResponseStatus: SPMWatchResponseSuccess,
                                              SPMWatchObjectParkingTimeLimit: [timeLimit watchConnectivityDictionaryRepresentation]};
            if ([self shouldWarnWatchAboutRespondingToNotificationPrompt])
            {
                NSMutableDictionary *mutableReplyDictionary = [replyDictionary mutableCopy];
                mutableReplyDictionary[SPMWatchObjectWarningMessage] = WCSession.defaultSession.SPMWatchWarningMessageEnableNotifications;
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

- (void)session:(nonnull WCSession *)session activationDidCompleteWithState:(WCSessionActivationState)activationState error:(nullable NSError *)error
{
}

- (void)sessionDidBecomeInactive:(nonnull WCSession *)session
{
}

- (void)sessionDidDeactivate:(nonnull WCSession *)session
{
    // Begin the activation process for the new Apple Watch.
    [[WCSession defaultSession] activateSession];
}

@end
