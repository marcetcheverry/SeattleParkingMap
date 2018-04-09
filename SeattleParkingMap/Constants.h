//
//  Constants.h
//  Seattle Parking Map
//
//  Created by Marc on 7/26/14.
//  Copyright (c) 2014 Tap Light Software. All rights reserved.
//

#import "ConstantsExternal.h"

#pragma mark - Constants

typedef NS_ENUM(NSInteger, SPMMapType)
{
    SPMMapTypeStreet,
    SPMMapTypeAerial
};

typedef NS_ENUM(NSInteger, SPMMapProvider)
{
    SPMMapProviderSDOT,
    SPMMapProviderOpenStreetMap,
    SPMMapProviderBing
};

// Please note that only the SDOT map is in 2926, all other ones are in Web Mercator 102100.
static NSUInteger SPMSpatialReferenceWKIDSDOT = 2926;

// UIApplicationShortcutItem type
#define SPMShortcutItemTypeParkInCurrentLocation [[[NSBundle mainBundle] bundleIdentifier] stringByAppendingString:@".ParkInCurrentLocation"]
#define SPMShortcutItemTypeRemoveParkingSpot [[[NSBundle mainBundle] bundleIdentifier] stringByAppendingString:@".RemoveParkingSpot"]

#pragma mark - Notification Keys

// UIUserNotification
static NSString * const SPMNotificationCategoryTimeLimit = @"SPMNotificationCategoryTimeLimit";
static NSString * const SPMNotificationActionRemoveSpot = @"SPMNotificationActionRemoveSpot";
// Goes in userInfo
static NSString * const SPMNotificationUserInfoKeyParkingSpot = @"SPMNotificationUserInfoKeyParkingSpot";
static NSString * const SPMNotificationUserInfoKeyIdentifier = @"SPMNotificationUserInfoKeyIdentifier";
static NSString * const SPMNotificationIdentifierTimeLimitExpiring = @"SPMNotificationIdentifierTimeLimitExpiring";
static NSString * const SPMNotificationIdentifierTimeLimitExpired = @"SPMNotificationIdentifierTimeLimitExpired";

#pragma mark - Defaults

static NSString * const SPMDefaultsLastParkingPoint = @"SPMLastParkingPoint"; // AGSPoint encodeToJSON (NSDictionary) with a WKID that varies: SPMSpatialReferenceWKIDSDOT or Web Mercator
static NSString * const SPMDefaultsLastParkingDate = @"SPMDefaultsLastParkingDate"; // NSDate
static NSString * const SPMDefaultsLastParkingTimeLimitStartDate = @"SPMDefaultsLastParkingTimeLimitStartDate"; // NSDate (the date in which you set the time limit). You may extend your parking stay, which should not affect your original parking date.
static NSString * const SPMDefaultsLastParkingTimeLimit = @"SPMDefaultsLastParkingTimeLimit"; // NSNumber NSTimeInterval
static NSString * const SPMDefaultsLastParkingTimeLimitReminderThreshold = @"SPMDefaultsLastParkingTimeLimitReminderThreshold"; // NSNumber NSTimeInterval
static NSString * const SPMDefaultsLastParkingAddress = @"SPMDefaultsLastParkingAddress"; // NSString
static NSString * const SPMDefaultsUserDefinedParkingTimeLimit = @"SPMDefaultsUserDefinedParkingTimeLimit"; // NSNumber NSTimeInterval
static NSString * const SPMDefaultsShownInitialWarning = @"SPMShownInitialWarning"; // BOOL
static NSString * const SPMDefaultsShownMaintenanceWarningDate = @"SPMDefaultsShownMaintenanceWarningDate"; // NSDate
static NSString * const SPMDefaultsNeedsBackgroundLocationWarning = @"SPMDefaultsNeedsBackgroundLocationWarning"; // BOOL
static NSString * const SPMDefaultsRegisteredForLocalNotifications = @"SPMDefaultsRegisteredForLocalNotifications"; // BOOL

static NSString * const SPMDefaultsLegendHidden = @"SPMLegendHidden"; // BOOL, default NO
static NSString * const SPMDefaultsLegendOpacity = @"SPMLegendOpacity"; // NSNumber float, default .75
static NSString * const SPMDefaultsSelectedMapType = @"SPMSelecteddMapType"; // NSNumber SPMMapType, default SPMMapTypeStreet
static NSString * const SPMDefaultsSelectedMapProvider = @"SPMDefaultsSelectedMapProvider"; // NSNumber SPMMapProvider, default SPMMapProviderSDOT
static NSString * const SPMDefaultsRenderMapsAtNativeResolution = @"SPMDefaultsRenderMapsAtNativeResolution"; // NSNumber BOOL, default YES for retina devices otherwise NO
//static NSString * const SPMDefaultsRenderLabelsAtNativeResolution = @"SPMDefaultsRenderLabelsAtNativeResolution"; // NSNumber BOOL, default NO (only applies to SDOT)

// Time Limit
static NSTimeInterval const SPMDefaultsParkingTimeLimitReminderThreshold = 10 * 60;
static NSInteger const SPMDefaultsParkingTimeLimitMinuteInterval = 10;

#pragma mark - Errors

static NSString * const SPMErrorDomain = @"SPMErrorDomain";
static NSInteger SPMErrorCodeLocationAuthorization = 0;
static NSInteger SPMErrorCodeLocationBackgroundAuthorization = 1;
static NSInteger SPMErrorCodeLocationServiceArea = 2;
static NSInteger SPMErrorCodeLocationUnknown = 3;

#pragma mark - Watch Connectivity

static NSString * const SPMWatchAction = @"SPMWatchAction";
static NSString * const SPMWatchActionGetParkingSpot = @"SPMWatchActionGetParkingSpot"; // Will get you a SPMWatchObjectUserDefinedParkingTimeLimit as well for convenience
static NSString * const SPMWatchActionRemoveParkingSpot = @"SPMWatchActionRemoveParkingSpot";
static NSString * const SPMWatchActionSetParkingSpot = @"SPMWatchActionSetParkingSpot"; // May return a SPMWatchObjectWarningMessage for notification permissions

static NSString * const SPMWatchActionRemoveParkingTimeLimit = @"SPMWatchActionRemoveParkingTimeLimit";
static NSString * const SPMWatchActionSetParkingTimeLimit = @"SPMWatchActionSetParkingTimeLimit"; // Sends a SPMWatchObjectParkingTimeLimit responds with success or failure. May return a SPMWatchObjectWarningMessage for notification permissions

static NSString * const SPMWatchActionUpdateComplications = @"SPMWatchActionUpdateComplications";
static NSString * const SPMWatchActionUpdateGeocoding = @"SPMWatchActionUpdateGeocoding"; // Sends a SPMWatchObjectParkingSpotAddress

static NSString * const SPMWatchContextUserDefinedParkingTimeLimit = @"SPMWatchContextUserDefinedParkingTimeLimit";

static NSString * const SPMWatchResponseStatus = @"SPMWatchResponseStatus";
static NSString * const SPMWatchResponseSuccess = @"SPMWatchResponseSuccess";
static NSString * const SPMWatchResponseFailure = @"SPMWatchResponseFailure";

static NSString * const SPMWatchObjectUserDefinedParkingTimeLimit = @"SPMWatchObjectUserDefinedParkingTimeLimit"; // NSNumber NSTimeInterval

static NSString * const SPMWatchObjectParkingSpot = @"SPMWatchObjectParkingSpot"; // ParkingSpot (serialized)
static NSString * const SPMWatchObjectParkingTimeLimit = @"SPMWatchObjectParkingTimeLimit"; // ParkingTimeLimit (serialized)
static NSString * const SPMWatchObjectParkingSpotAddress = @"SPMWatchObjectParkingSpotAddress"; // NSString
static NSString * const SPMWatchObjectWarningMessage = @"SPMWatchObjectWarningMessage"; // NSString

#pragma mark - Watch Handoff

static NSString * const SPMWatchHandoffActivityCurrentScreen = @"com.taplightsoftware.SeattleParkingMap.currentScreen";
static NSString * const SPMWatchHandoffUserInfoKeyCurrentScreen = @"SPMWatchHandoffUserInfoKeyCurrentScreen";

#pragma mark - Functions

#ifdef DEBUG
#   define SPMLog(...) NSLog(__VA_ARGS__)
#else
#   define SPMLog(...)
#endif
