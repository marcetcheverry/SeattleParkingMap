//
//  SPMAppDelegate.m
//  Seattle Parking Map
//
//  Created by Marc on 6/5/14.
//  Copyright (c) 2014 Tap Light Software. All rights reserved.
//

#import "SPMAppDelegate.h"

#import "SPMRootViewController.h"

@interface SPMAppDelegate () <CLLocationManagerDelegate>

@property (nonatomic) CLLocationManager *locationManager;
@property (nonatomic, copy) void(^setParkingSpotReplyHandler)(NSDictionary<NSString *, id> *replyMessage);
@property (nonatomic) BOOL applicationConfiguredForForegroundOperation;

@end

@implementation SPMAppDelegate

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

            self.setParkingSpotReplyHandler = nil;
            return;
        }

        CLLocation *location = [locations firstObject];


        AGSPoint *coreLocationPoint = [AGSPoint pointWithX:location.coordinate.longitude
                                                         y:location.coordinate.latitude
                                          spatialReference:[AGSSpatialReference wgs84SpatialReference]];

        // WGS_1984_Web_Mercator_Auxiliary_Sphere
        // 102100 is a Mercator projection in meters, where WGS-84 is in decimal degrees (4326)
//        AGSPoint *parkingPoint = (AGSPoint *)AGSGeometryGeographicToWebMercator(coreLocationPoint);

        // For legacy reasons, we store in 2926
        AGSGeometryEngine *engine = [AGSGeometryEngine defaultGeometryEngine];
        AGSSpatialReference *spatialReferenceSDOT = [AGSSpatialReference spatialReferenceWithWKID:SPMSpatialReferenceWKIDSDOT];
        AGSPoint *parkingPoint = (AGSPoint *)[engine projectGeometry:coreLocationPoint
                                                  toSpatialReference:spatialReferenceSDOT];

        NSDate *parkDate = [NSDate date];

        [[NSUserDefaults standardUserDefaults] setObject:[parkingPoint encodeToJSON] forKey:SPMDefaultsLastParkingPoint];
        [[NSUserDefaults standardUserDefaults] setObject:parkDate forKey:SPMDefaultsLastParkingDate];

        NSDictionary *coordinates = @{SPMWatchObjectParkingPointLatitude: @(location.coordinate.latitude),
                                      SPMWatchObjectParkingPointLongitude: @(location.coordinate.longitude)};

        self.setParkingSpotReplyHandler(@{SPMWatchAction: SPMWatchActionSetParkingSpot,
                                          SPMWatchResponseStatus: SPMWatchResponseSuccess,
                                          SPMWatchObjectParkingPoint: coordinates,
                                          SPMWatchObjectParkingDate: parkDate});

        self.setParkingSpotReplyHandler = nil;

        [Flurry logEvent:@"ParkingSpot_SetFromWatch_Success"];

        // Edge case if we do it in the background and we launch entirely before as the spot is set.
        if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive)
        {
            SPMRootViewController *rootViewController = (SPMRootViewController *)self.window.rootViewController;
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

        self.setParkingSpotReplyHandler = nil;
    }

    self.locationManager.delegate = nil;
    self.locationManager = nil;
}

#pragma mark - WCSessionDelegate

- (void)session:(WCSession *)session didReceiveMessage:(NSDictionary<NSString *, id> *)message replyHandler:(void(^)(NSDictionary<NSString *, id> *replyMessage))replyHandler
{
//    NSLog(@"App Received Message from Watch %@", message);

    if ([message[SPMWatchAction] isEqualToString:SPMWatchActionRemoveParkingSpot])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![UIApplication sharedApplication].applicationState == UIApplicationStateActive)
            {
                [[NSUserDefaults standardUserDefaults] setObject:nil forKey:SPMDefaultsLastParkingPoint];
                [[NSUserDefaults standardUserDefaults] setObject:nil forKey:SPMDefaultsLastParkingDate];
                replyHandler(@{SPMWatchAction: message[SPMWatchAction],
                               SPMWatchResponseStatus: SPMWatchResponseSuccess});

                // Edge case if we do it in the background and we launch entirely before as the spot is removed.
                if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive)
                {
                    [Flurry logEvent:@"ParkingSpot_RemoveFromWatch"];
                    SPMRootViewController *rootViewController = (SPMRootViewController *)self.window.rootViewController;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [rootViewController synchronizeParkingSpotDisplayFromDataStore];
                    });
                }
            }
            else
            {
                // dispatch_after for testing cancellation
                SPMRootViewController *rootViewController = (SPMRootViewController *)self.window.rootViewController;
                [rootViewController removeCurrentParkingSpotFromWatch];
                replyHandler(@{SPMWatchAction: message[SPMWatchAction],
                               SPMWatchResponseStatus: SPMWatchResponseSuccess});
            }
        });
    }
    else if ([message[SPMWatchAction] isEqualToString:SPMWatchActionSetParkingSpot])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            // OpenGL will crash on the background!
            if (![UIApplication sharedApplication].applicationState == UIApplicationStateActive)
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
                    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:SPMDefaultsNeedsBackgroundLocationWarning];

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

                self.setParkingSpotReplyHandler = replyHandler;
            }
            else
            {
                // dispatch_after for testing cancellation
                SPMRootViewController *rootViewController = (SPMRootViewController *)self.window.rootViewController;
                NSError *error;
                if ([rootViewController attemptToSetParkingSpotInCurrentLocationFromWatch:YES error:&error])
                {
                    NSDictionary *parkingObject = [rootViewController watchSessionEncodedParkingDictionary];
                    if (parkingObject)
                    {
                        NSMutableDictionary *replyDictionary = [parkingObject mutableCopy];
                        replyDictionary[SPMWatchAction] = message[SPMWatchAction];
                        replyDictionary[SPMWatchResponseStatus] = SPMWatchResponseSuccess;
                        replyHandler(replyDictionary);
                    }
                    else
                    {
                        NSError *error = [NSError errorWithDomain:SPMErrorDomain
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
    else if ([message[SPMWatchAction] isEqualToString:SPMWatchActionGetParkingPoint])
    {
        if (replyHandler)
        {
            SPMRootViewController *rootViewController = (SPMRootViewController *)self.window.rootViewController;
            NSDictionary *parkingObject = [rootViewController watchSessionEncodedParkingDictionary];
            [Flurry logEvent:@"ParkingSpot_GetFromWatch"];
            if (parkingObject)
            {
                NSMutableDictionary *replyDictionary = [parkingObject mutableCopy];
                replyDictionary[SPMWatchAction] = message[SPMWatchAction];
                replyDictionary[SPMWatchResponseStatus] = SPMWatchResponseSuccess;
                replyHandler(replyDictionary);
            }
            else
            {
                replyHandler(@{SPMWatchAction: message[SPMWatchAction],
                               SPMWatchResponseStatus: SPMWatchResponseSuccess});
            }
        }
    }
    else
    {
        NSAssert(NO, @"Watch Message not handled");
        NSLog(@"Watch Message not handled");
    }
}

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
                                                              SPMDefaultsRenderMapsAtNativeResolution: @(renderMapsAtNativeResolution)}];;
    [[NSUserDefaults standardUserDefaults] synchronize];

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
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
