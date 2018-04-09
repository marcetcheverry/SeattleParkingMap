//
//  SPMConstants.h
//  Seattle Parking Map
//
//  Created by Marc on 7/26/14.
//  Copyright (c) 2014 Tap Light Software. All rights reserved.
//

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

static NSUInteger SPMSpatialReferenceWKIDSDOT = 2926;

#pragma mark - Defaults

static NSString * const SPMDefaultsLastParkingPoint = @"SPMLastParkingPoint"; // AGSPoint encodeToJSON (NSDictionary) with WKID of SPMSpatialReferenceWKIDSDOT
static NSString * const SPMDefaultsLastParkingDate = @"SPMDefaultsLastParkingDate"; // NSDate
static NSString * const SPMDefaultsShownInitialWarning = @"SPMShownInitialWarning"; // BOOL
static NSString * const SPMDefaultsShownMaintenanceWarningDate = @"SPMDefaultsShownMaintenanceWarningDate"; // NSDate
static NSString * const SPMDefaultsNeedsBackgroundLocationWarning = @"SPMDefaultsNeedsBackgroundLocationWarning"; // BOOL

static NSString * const SPMDefaultsLegendHidden = @"SPMLegendHidden"; // BOOL, default NO
static NSString * const SPMDefaultsLegendOpacity = @"SPMLegendOpacity"; // NSNumber float, default .75
static NSString * const SPMDefaultsSelectedMapType = @"SPMSelecteddMapType"; // NSNumber SPMMapType, default SPMMapTypeStreet
static NSString * const SPMDefaultsSelectedMapProvider = @"SPMDefaultsSelectedMapProvider"; // NSNumber SPMMapProvider, default SPMMapProviderSDOT
static NSString * const SPMDefaultsRenderMapsAtNativeResolution = @"SPMDefaultsRenderMapsAtNativeResolution"; // NSNumber BOOL, default YES for retina devices otherwise NO
//static NSString * const SPMDefaultsRenderLabelsAtNativeResolution = @"SPMDefaultsRenderLabelsAtNativeResolution"; // NSNumber BOOL, default NO (only applies to SDOT)

#define SPM_API_KEY_ARCGIS_CLIENT_ID @"KEY"

#define SPM_API_KEY_BING_MAPS @"KEY"

#define SPM_API_KEY_FLURRY_DEV @"KEY"
#define SPM_API_KEY_FLURRY_PROD @"KEY"

#pragma mark - Errors

static NSString * const SPMErrorDomain = @"SPMErrorDomain";
static NSUInteger SPMErrorCodeLocationAuthorization = 0;
static NSUInteger SPMErrorCodeLocationBackgroundAuthorization = 1;
static NSUInteger SPMErrorCodeLocationServiceArea = 2;
static NSUInteger SPMErrorCodeLocationUnknown = 3;

#pragma mark - Watch Connectivity

static NSString * const SPMWatchAction = @"SPMWatchAction";
static NSString * const SPMWatchActionGetParkingPoint = @"SPMWatchActionGetParkingPoint";
static NSString * const SPMWatchActionRemoveParkingSpot = @"SPMWatchActionRemoveParkingSpot";
static NSString * const SPMWatchActionSetParkingSpot = @"SPMWatchActionSetParkingSpot";

static NSString * const SPMWatchResponseStatus = @"SPMWatchResponseStatus";
static NSString * const SPMWatchResponseSuccess = @"SPMWatchResponseSuccess";
static NSString * const SPMWatchResponseFailure = @"SPMWatchResponseFailure";

static NSString * const SPMWatchObjectParkingPoint = @"SPMWatchObjectParkingPoint";
static NSString * const SPMWatchObjectParkingPointLatitude = @"SPMWatchObjectParkingPointLatitude";
static NSString * const SPMWatchObjectParkingPointLongitude = @"SPMWatchObjectParkingPointLongitude";
static NSString * const SPMWatchObjectParkingDate = @"SPMWatchObjectParkingDate";

#pragma mark - Watch Handoff

static NSString * const SPMWatchHandoffActivityCurrentScreen = @"com.taplightsoftware.SeattleParkingMap.currentScreen";
static NSString * const SPMWatchHandoffUserInfoKeyCurrentScreen = @"SPMWatchHandoffUserInfoKeyCurrentScreen";
