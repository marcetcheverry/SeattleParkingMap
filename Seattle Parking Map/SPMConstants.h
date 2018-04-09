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

#pragma mark - Defaults

static NSString * const SPMDefaultsLastParkingPoint = @"SPMLastParkingPoint"; // AGSPoint encodeToJSON (NSDictionary)
static NSString * const SPMDefaultsShownInitialWarning = @"SPMShownInitialWarning"; // BOOL

static NSString * const SPMDefaultsLegendHidden = @"SPMLegendHidden"; // BOOL, default NO
static NSString * const SPMDefaultsLegendOpacity = @"SPMLegendOpacity"; // NSNumber float, default .75
static NSString * const SPMDefaultsSelectedMapType = @"SPMSelecteddMapType"; // NSNumber SPMMapType, default SPMMapTypeStreet


#define SPMFlurryAPIKey_Development @"KEY"
#define SPMFlurryAPIKey_Production @"KEY"

//#define SPMDisableAds

// Build checks
#ifndef DEBUG
    #ifdef SPMDisableAds
        #error Ads must be enabled for release builds
    #endif
#endif
