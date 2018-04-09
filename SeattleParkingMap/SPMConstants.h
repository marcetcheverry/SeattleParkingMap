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

#pragma mark - Defaults

static NSString * const SPMDefaultsLastParkingPoint = @"SPMLastParkingPoint"; // AGSPoint encodeToJSON (NSDictionary)
static NSString * const SPMDefaultsLastParkingDate = @"SPMDefaultsLastParkingDate"; // NSDate
static NSString * const SPMDefaultsShownInitialWarning = @"SPMShownInitialWarning"; // BOOL

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
