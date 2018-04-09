//
//  SPMAppDelegate.m
//  Seattle Parking Map
//
//  Created by Marc on 6/5/14.
//  Copyright (c) 2014 Tap Light Software. All rights reserved.
//

#import "SPMAppDelegate.h"

@implementation SPMAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Search
//    [UITextField appearance].keyboardAppearance = UIKeyboardAppearanceDark;

    [Flurry setCrashReportingEnabled:YES];

#ifdef DEBUG
//    [Flurry setLogLevel:FlurryLogLevelDebug];
    [Flurry startSession:SPM_API_KEY_FLURRY_DEV];
#else
    [Flurry setLogLevel:FlurryLogLevelNone];
    [Flurry startSession:SPM_API_KEY_FLURRY_PROD];
#endif

    [UIApplication sharedApplication].idleTimerDisabled = YES;

    NSError *error;
    [AGSRuntimeEnvironment setClientID:SPM_API_KEY_ARCGIS_CLIENT_ID error:&error];
    if (error)
    {
        NSLog(@"Error using client ID: %@", [error localizedDescription]);
        [Flurry logError:@"ArcGIS_setClientID" message:@"Could not setClientID on startup" error:error];
    }

    BOOL renderMapsAtNativeResolution = NO;

    if ([[UIScreen mainScreen] scale] > 1)
    {
        renderMapsAtNativeResolution = YES;
    }

    [[NSUserDefaults standardUserDefaults] registerDefaults:@{SPMDefaultsShownInitialWarning: @(NO),
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
    
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
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
