//
//  RootViewController.m
//  Seattle Parking Map
//
//  Created by Marc on 6/5/14.
//  Copyright (c) 2014 Tap Light Software. All rights reserved.
//

#import "RootViewController.h"

//@import MapKit;
//@import AddressBook;

#import "ParkingManager.h"
#import "ParkingSpot.h"
#import "ParkingTimeLimit.h"
#import "LegendDataSource.h"
#import "Legend.h"
#import "LegendTableViewCell.h"
#import "NeighborhoodDataSource.h"
#import "Neighborhood.h"

#import "SettingsTableViewController.h"
#import "TimeLimitViewController.h"
#import "NeighborhoodsViewController.h"

#import "ParkingSpotCalloutView.h"

#import "Analytics.h"

#import "WCSession+SPM.h"

//#import "SPMMapActivityProvider.h"

static void *RootViewControllerContext = &RootViewControllerContext;
static void *ARCGISContext = &ARCGISContext;

// Street
#define SPMMapTiledRoadURL @"https://gisrevprxy.seattle.gov/ArcGIS/rest/services/ext/SP_CityBM_Roads/MapServer/"
// Aerial
#define SPMMapTiledAerialURL @"https://gisrevprxy.seattle.gov/ArcGIS/rest/services/ext/SP_CityBM_Ortho_2009/MapServer/"
// Street Names
#define SPMMapTiledLabelsURL @"https://gisrevprxy.seattle.gov/ArcGIS/rest/services/ext/SP_CityBM_Labels/MapServer/"
// Parking Data
#define SPMMapParkingLinesURL @"https://gisrevprxy.seattle.gov/ArcGIS/rest/services/SDOT_EXT/sdot_parking/MapServer/"

// Virtual Earth (looks the same)
//#define SPMMapVETiledRoadURL @"https://gisrevprxy.seattle.gov/ArcGIS/rest/services/ext/VE_CityBM_Roads/MapServer/"
//#define SPMMapVETiledLabelsURL @"https://gisrevprxy.seattle.gov/ArcGIS/rest/services/ext/VE_CityBM_Labels/MapServer/"
//#define SPMMapVETiledAerialURL @"https://gisrevprxy.seattle.gov/ArcGIS/rest/services/ext/VE_CityBM_Orthos/MapServer/"

@interface RootViewController () <AGSGeoViewTouchDelegate, AGSCalloutDelegate, CLLocationManagerDelegate, TimeLimitViewControllerDelegate, UITableViewDelegate, UINavigationControllerDelegate>

@property (weak, nonatomic) IBOutlet AGSMapView *mapView;
@property (weak, nonatomic) IBOutlet UIButton *legendsButton;
@property (weak, nonatomic) IBOutlet UITableView *legendTableView;
@property (weak, nonatomic) IBOutlet UIButton *neighborhoodsButton;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *legendsContainerCollapsedHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *legendContainerCollapsedWidthConstraint;

@property (weak, nonatomic) IBOutlet UIButton *parkingButton;
@property (weak, nonatomic) IBOutlet UIButton *locationButton;
@property (weak, nonatomic) IBOutlet UIButton *infoButton;
@property (weak, nonatomic) IBOutlet UIView *legendContainerView;
//@property (weak, nonatomic) IBOutlet UIButton *searchButton;
@property (weak, nonatomic) IBOutlet UISlider *legendSlider;
@property (strong, nonatomic) IBOutlet UITapGestureRecognizer *gestureRecognizerGuideContainer;

@property (strong, nonatomic) IBOutletCollection(UIView) NSArray *borderedViews;

@property (nonatomic) AGSArcGISMapImageLayer *SDOTParkingLinesLayer;
@property (nonatomic) AGSLayer *SDOTStreetLabelsLayer;
@property (nonatomic) AGSGraphicsOverlay *parkingSpotGraphicsLayer;
@property (nonatomic) AGSArcGISMapServiceInfo *serviceInfo;

@property (nonatomic) AGSEnvelope *cachedHoodEnvelope;

// For Aerial status bar overlay
@property (nonatomic) CAGradientLayer *gradientLayer;

@property (nonatomic) SPMMapProvider currentMapProvider;
@property (nonatomic) SPMMapType currentMapType;
@property (nonatomic) BOOL needsMapRefreshOnAppearance;

@property (nonatomic) CLLocationManager *locationManager;
@property (nonatomic) UIAlertController *timeLimitAlertController;

@property (nonatomic) BOOL isObservingLocationUpdates;
@property (nonatomic) BOOL needsToSetParkingSpotOnLoad;
@property (nonatomic) BOOL needsCenteringOnCurentLocation;
@property (nonatomic) BOOL loadedAllMapLayers;
@property (nonatomic) BOOL loadedGuide;

@property (strong, nonatomic) IBOutlet LegendDataSource *legendDataSource;
@property (strong, nonatomic) NeighborhoodDataSource *neighborhoodDataSource;

@end

@implementation RootViewController

#pragma mark - View Lifecycle

- (void)dealloc
{
    //    self.searchBar.delegate = nil;
    
    [[ParkingManager sharedManager] removeObserver:self
                                        forKeyPath:@"currentSpot"
                                           context:RootViewControllerContext];
    
    [self.mapView removeObserver:self
                      forKeyPath:@"locationDisplay.autoPanMode"
                         context:RootViewControllerContext];
    
    [self stopObservingLocationUpdates];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationWillEnterForegroundNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSUserDefaultsDidChangeNotification
                                                  object:nil];
}

- (void)removeAGSLogoView {
    for (UIView *view in self.mapView.subviews) {
        NSString *className = NSStringFromClass([view class]);
        if ([className isEqualToString:@"AGSLogoView"]) {
            [view removeFromSuperview];
        }
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self removeAGSLogoView];
    
    self.legendTableView.estimatedRowHeight = 17;
    self.legendTableView.rowHeight = UITableViewAutomaticDimension;
    
    self.mapView.interactionOptions.magnifierEnabled = YES;
    
    [self.legendSlider setThumbImage:[UIImage imageNamed:@"SliderThumbEye"]
                            forState:UIControlStateNormal];
    
    [self.legendSlider setThumbImage:[UIImage imageNamed:@"SliderThumbEyeSelected"]
                            forState:UIControlStateDisabled];
    
    [self.legendSlider setThumbImage:[UIImage imageNamed:@"SliderThumbEyeSelected"]
                            forState:UIControlStateHighlighted];
    
    [self.legendSlider setThumbImage:[UIImage imageNamed:@"SliderThumbEyeSelected"]
                            forState:UIControlStateSelected];
    
    // Restore defaults
    self.legendSlider.value = [[NSUserDefaults standardUserDefaults] floatForKey:SPMDefaultsLegendOpacity];
    
    UIColor *colorOne = [UIColor colorWithWhite:0 alpha:.6];
    UIColor *colorTwo = [UIColor colorWithWhite:0 alpha:.3];
    UIColor *colorThree = [UIColor clearColor];
    
    self.gradientLayer = [CAGradientLayer layer];
    self.gradientLayer.colors = @[(id)colorOne.CGColor, (id)colorTwo.CGColor, (id)colorThree.CGColor];
    self.gradientLayer.locations = @[@0.25, @0.5, @1];
    self.gradientLayer.opacity = 0;
    [self.view.layer addSublayer:self.gradientLayer];
    
    [[ParkingManager sharedManager] addObserver:self
                                     forKeyPath:@"currentSpot"
                                        options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld)
                                        context:RootViewControllerContext];

    [self.mapView addObserver:self
                   forKeyPath:@"locationDisplay.autoPanMode"
                      options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld)
                      context:RootViewControllerContext];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(userDefaultsChanged:)
                                                 name:NSUserDefaultsDidChangeNotification
                                               object:nil];
    
    //    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
    //    self.searchBar.delegate = self;
    //    self.searchBar.placeholder = NSLocalizedString(@"Search", nil);
    //    self.navigationItem.titleView = self.searchBar;
    
    for (UIView *borderedView in self.borderedViews)
    {
        borderedView.layer.borderColor = [UIColor whiteColor].CGColor;
        borderedView.layer.borderWidth = 1;
        
        //        borderedView.layer.shadowColor = [UIColor blackColor].CGColor;
        //        borderedView.layer.shadowRadius = 10;
        //        borderedView.layer.shadowOpacity = .7;
        //        borderedView.layer.shadowOffset = CGSizeZero;
        //        borderedView.layer.masksToBounds = NO;
        //        borderedView.clipsToBounds = NO;
        //        if ([borderedView isKindOfClass:[UIButton class]])
        //        {
        //            borderedView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:borderedView.bounds
        //                                                                       cornerRadius:borderedView.layer.cornerRadius].CGPath;
        //        }
    }
    
    // Disabled border for now (can't set it in IB)
    self.locationButton.layer.borderColor = [UIColor colorWithWhite:1 alpha:.5].CGColor;
    self.parkingButton.layer.borderColor = [UIColor colorWithWhite:1 alpha:.5].CGColor;

    //#define DEGREES_TO_RADIANS(x) (M_PI * (x) / 180.0)
    //    self.searchButton.layer.transform = CATransform3DMakeRotation(DEGREES_TO_RADIANS(45), 0, 0, 1);
    //    self.searchButton.titleLabel.transform = CGAffineTransformMakeRotation(DEGREES_TO_RADIANS(45));
    
    // Set up the map
    self.mapView.interactionOptions.rotateEnabled = YES;

    if ([UIApplication sharedApplication].applicationState != UIApplicationStateBackground)
    {
        [self updateNeighborhoodsButtonAnimated:NO
                                     completion:nil];

        [self.neighborhoodDataSource loadNeighboorhoodsWithCompletionHandler:^(BOOL success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updateNeighborhoodsButtonAnimated:YES
                                             completion:nil];
            });
        }];

        [self loadMapView];
    }
}

- (void)updateNeighborhoodsButtonAnimated:(BOOL)animated completion:(void (^ __nullable)(BOOL finished))completion
{
    dispatch_block_t changeBlock = ^{
        if (!self.loadedAllMapLayers || self.neighborhoodDataSource.state == SPMStateUnknown || self.neighborhoodDataSource.state == SPMStateLoading)
        {
            [self.neighborhoodsButton setTitle:NSLocalizedString(@"Loading…", nil)
                                      forState:UIControlStateNormal];
            self.neighborhoodsButton.enabled = NO;
        }
        else if (self.neighborhoodDataSource.state == SPMStateFailedToLoad)
        {
            [self.neighborhoodsButton setTitle:NSLocalizedString(@"Try Again", nil)
                                      forState:UIControlStateNormal];
            self.neighborhoodsButton.enabled = YES;
        }
        else if (self.neighborhoodDataSource.neighborhoods.count)
        {
            self.neighborhoodsButton.enabled = self.loadedAllMapLayers;
            NSString *neighborhoodSelected = self.neighborhoodDataSource.selectedNeighborhood.name;

            if (neighborhoodSelected)
            {
                for (Neighborhood *hood in self.neighborhoodDataSource.neighborhoods)
                {
                    if ([hood.name isEqualToString:neighborhoodSelected])
                    {
                        [self.neighborhoodsButton setTitle:neighborhoodSelected
                                                  forState:UIControlStateNormal];
                        return;
                    }
                }
            }

            [self.neighborhoodsButton setTitle:NSLocalizedString(@"Neighborhoods", nil)
                                      forState:UIControlStateNormal];
        }
    };

    if (!animated)
    {
        changeBlock();
    }
    else
    {
        [UIView transitionWithView:self.neighborhoodsButton
                          duration:0.3
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:changeBlock
                        completion:completion];

    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateBackground)
    {
        if (self.needsMapRefreshOnAppearance)
        {
            [self refreshMapSettingsIfNeeded];
            self.needsMapRefreshOnAppearance = NO;
        }
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // Default SPMDefaultsSelectedMapProvider
    NSString *mapProviderName = @"SDOT";
    
    switch ([[NSUserDefaults standardUserDefaults] integerForKey:SPMDefaultsSelectedMapProvider])
    {
        case SPMMapProviderSDOT:
            mapProviderName = @"SDOT";
            break;
        case SPMMapProviderARCGISVector:
            mapProviderName = @"ARCGISVector";
            break;
        case SPMMapProviderBing:
            mapProviderName = @"Bing";
            break;
        default:
            break;
    }
    
    // Default SPMMapTypeStreet
    NSString *mapTypeName = @"Street";
    
    switch ([[NSUserDefaults standardUserDefaults] integerForKey:SPMDefaultsSelectedMapType])
    {
        case SPMMapTypeStreet:
            mapTypeName = @"Street";
            break;
        case SPMMapTypeAerial:
            mapTypeName = @"Aerial";
            break;
        default:
            break;
    }

    BOOL watchAppInstalled = NO;
    
    if ([WCSession isSupported])
    {
        watchAppInstalled = [WCSession defaultSession].isWatchAppInstalled;
    }
    
    BOOL watchAppReachable = NO;
    
    if ([WCSession isSupported])
    {
        watchAppReachable = [WCSession defaultSession].isReachable;
    }
    
    [Analytics logEvent:@"Map_viewDidAppear"
         withParameters:@{SPMDefaultsLegendHidden: [[NSUserDefaults standardUserDefaults] objectForKey:SPMDefaultsLegendHidden],
                          SPMDefaultsSelectedMapProvider: mapProviderName,
                          SPMDefaultsSelectedMapType: mapTypeName,
                          @"SPMDefaultsHasStoredParkingPoint": @([ParkingManager sharedManager].currentSpot != nil),
                          SPMDefaultsLegendOpacity: [[NSUserDefaults standardUserDefaults] objectForKey:SPMDefaultsLegendOpacity],
                          @"watchAppInstalled": @(watchAppInstalled),
                          @"watchAppReachable": @(watchAppReachable)
                          }];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    self.gradientLayer.frame = CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), self.view.safeAreaInsets.top * 1.25);
    [self updateLegendTableViewBounce];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll; // rotate upside down on the iPhone for car users
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    if (self.currentMapType == SPMMapTypeAerial)
    {
        return UIStatusBarStyleLightContent;
    }
    
    return UIStatusBarStyleDefault;
}

#pragma mark - Notifications

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
    // Try Again
    if (self.mapView.map == nil || self.mapView.map.loadStatus != AGSLoadStatusLoaded)
    {
        [self loadMapView];
    }
    else
    {
        // Hapens if you set a parking spot while app is backgrounded (from watch)
        if ([ParkingManager sharedManager].currentSpot &&
            ![self isParkingSpotShownOnMap])
        {
            [self restoreParkingSpotMarker];
        }
        else if (![ParkingManager sharedManager].currentSpot &&
                 [self isParkingSpotShownOnMap])
        {
            [self removeParkingSpotFromSource:SPMParkingSpotActionSourceWatch];
        }
        else if ([ParkingManager sharedManager].currentSpot)
        {
            [self centerOnParkingSpot];
        }
        else
        {
            [self centerOnBestSpotWithLocationAuthorizationWarning:NO
                                                          animated:YES];
        }
        
        // For the background location alert
        [self presentInitialAlertsIfNeededWithCompletion:nil];
    }
}

- (void)userDefaultsChanged:(NSNotification *)notification
{
    // So the spatial reference gets recalculated for the viewpoint changed handler
    SPMMapProvider newMapProvider = [[NSUserDefaults standardUserDefaults] integerForKey:SPMDefaultsSelectedMapProvider];
    if (self.currentMapProvider != newMapProvider)
    {
        self.cachedHoodEnvelope = nil;
    }

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        [self refreshMapSettingsIfNeeded];
    }
    else
    {
        self.needsMapRefreshOnAppearance = YES;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context == ARCGISContext) {
        if ([keyPath isEqualToString:@"loadStatus"])
        {
            if (![change[NSKeyValueChangeOldKey] isEqual:change[NSKeyValueChangeNewKey]])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ([object isKindOfClass:[AGSLayer class]])
                    {
                        AGSLayer *layer = (AGSLayer *)object;
                        if (layer.loadStatus == AGSLoadStatusFailedToLoad)
                        {
                            [self layer:object didFailToLoadWithError:layer.loadError];
                        }
                        else if (layer.loadStatus == AGSLoadStatusLoaded)
                        {
                            [self layerDidLoad:layer];
                        }
                    }
                });
            }
        }
    }
    else if (context == RootViewControllerContext)
    {
        if ([keyPath isEqualToString:@"currentSpot"])
        {
            if (![change[NSKeyValueChangeOldKey] isEqual:change[NSKeyValueChangeNewKey]])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (![ParkingManager sharedManager].currentSpot)
                    {
                        if (self.timeLimitAlertController)
                        {
                            [self.timeLimitAlertController dismissViewControllerAnimated:YES
                                                                              completion:^{
                                                                                  self.timeLimitAlertController = nil;
                                                                              }];
                        }
                    }
                });
            }
        }
        else if ([keyPath isEqualToString:@"locationDisplay.autoPanMode"])
        {
            if (![change[NSKeyValueChangeOldKey] isEqual:change[NSKeyValueChangeNewKey]])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [UIView transitionWithView:self.locationButton
                                      duration:.3
                                       options:UIViewAnimationOptionCurveEaseInOut
                                    animations:^{
                                        if (self.mapView.locationDisplay.autoPanMode == AGSLocationDisplayAutoPanModeOff)
                                        {
                                            self.locationButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:.65];
                                            self.locationButton.layer.shadowColor = nil;
                                            self.locationButton.layer.shadowRadius = 0;
                                            self.locationButton.layer.shadowOpacity = 0;
                                            self.locationButton.layer.masksToBounds = YES;
                                            self.locationButton.clipsToBounds = YES;
                                        }
                                        else
                                        {
                                            // Based on the ArcGIS current location dot color.
                                            UIColor *color = [UIColor colorWithRed:0 green:0.47 blue:0.771 alpha:1];
                                            self.locationButton.backgroundColor = color;
                                            self.locationButton.layer.shadowColor = color.CGColor;
                                            self.locationButton.layer.shadowRadius = 10;
                                            self.locationButton.layer.shadowOpacity = .7;
                                            self.locationButton.layer.shadowOffset = CGSizeZero;
                                            self.locationButton.layer.masksToBounds = NO;
                                            self.locationButton.clipsToBounds = NO;
                                            
                                            UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:self.locationButton.bounds
                                                                                            cornerRadius:self.parkingButton.layer.cornerRadius];
                                            self.locationButton.layer.shadowPath = path.CGPath;
                                        }
                                    }
                                    completion:nil];
                });
            }
        }
        else
        {
            if ([keyPath isEqualToString:@"locationDisplay.location"])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (self.needsToSetParkingSpotOnLoad)
                    {
                        if (self.mapView.locationDisplay.location)
                        {
                            NSLog(@"Found current location, will stop observing for location updates");
                            [self setParkingSpotInCurrentLocationFromSource:SPMParkingSpotActionSourceQuickAction
                                                                      error:nil];
                            self.needsToSetParkingSpotOnLoad = NO;
                        }
                    }
                    else if (self.needsCenteringOnCurentLocation)
                    {
                        self.needsCenteringOnCurentLocation = nil;
                        [self centerOnBestSpotWithLocationAuthorizationWarning:NO
                                                                      animated:YES];
                    }
                    
                    [self stopObservingLocationUpdates];
                });
            }
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath
                             ofObject:object
                               change:change
                              context:context];
    }
}

#pragma mark - Actions

- (nullable AGSLayer *)layerForMapType:(SPMMapType)mapType
{
    AGSLayer *mapLayer;
    
    SPMMapProvider mapProvider = [[NSUserDefaults standardUserDefaults] integerForKey:SPMDefaultsSelectedMapProvider];
    
    switch (mapProvider)
    {
        case SPMMapProviderSDOT:
        {
            if (mapType == SPMMapTypeAerial)
            {
                // Aerial
                mapLayer = [[AGSArcGISMapImageLayer alloc] initWithURL:[NSURL URLWithString:SPMMapTiledAerialURL]];
            }
            else
            {
                // Street is the default
                mapLayer = [[AGSArcGISMapImageLayer alloc] initWithURL:[NSURL URLWithString:SPMMapTiledRoadURL]];
            }
            break;
        }
        case SPMMapProviderBing:
        {
            if (mapType == SPMMapTypeAerial)
            {
                // Aerial
                mapLayer = [[AGSBingMapsLayer alloc] initWithKey:SPMExternalAPIBing style:AGSBingMapsLayerStyleHybrid];
            }
            else
            {
                // Street is the default
                mapLayer = [[AGSBingMapsLayer alloc] initWithKey:SPMExternalAPIBing style:AGSBingMapsLayerStyleRoad];
            }
            break;
        }
        default:
            break;
    }
    
    if (mapType == SPMMapTypeAerial)
    {
        mapLayer.name = NSLocalizedString(@"Aerial", nil);
    }
    else
    {
        mapLayer.name = NSLocalizedString(@"Street", nil);
    }
    
    return mapLayer;
}

- (AGSBasemap *)basemap
{
    AGSBasemap *basemap;

    // SDOT Parking Lines
    self.SDOTParkingLinesLayer = [[AGSArcGISMapImageLayer alloc] initWithURL:[NSURL URLWithString:SPMMapParkingLinesURL]];
    self.SDOTParkingLinesLayer.name = NSLocalizedString(@"Parking", nil);
    self.SDOTParkingLinesLayer.opacity = [NSUserDefaults.standardUserDefaults floatForKey:SPMDefaultsLegendOpacity];

    if (self.currentMapProvider == SPMMapProviderARCGISVector)
    {
        if (self.currentMapType == SPMMapTypeAerial)
        {
            basemap = [AGSBasemap imageryWithLabelsVectorBasemap];
        }
        else
        {
            basemap = [AGSBasemap streetsWithReliefVectorBasemap];
        }

        [basemap.referenceLayers addObject:self.SDOTParkingLinesLayer];
    }
    else
    {
        AGSLayer *baseLayer = [self layerForMapType:self.currentMapType];

        // Add street labels when needed
        if (self.currentMapProvider == SPMMapProviderSDOT)
        {
            // SDOT Street Labels (they have terrible resolution)
//            self.SDOTStreetLabelsLayer = [[AGSArcGISMapImageLayer alloc] initWithURL:[NSURL URLWithString:SPMMapTiledLabelsURL]];
//            self.SDOTStreetLabelsLayer.name = NSLocalizedString(@"Labels SDOT", nil);


            // Here Maps Street Labels (much better resolution, but still raster)

            /*
             @[[AGSLevelOfDetail levelOfDetailWithLevel:0 resolution:156543.0339280001 scale:591657527.591555],
             [AGSLevelOfDetail levelOfDetailWithLevel:1 resolution:78271.51696399994 scale:295828763.795777],
             [AGSLevelOfDetail levelOfDetailWithLevel:2 resolution:39135.75848200009 scale:147914381.897889],
             [AGSLevelOfDetail levelOfDetailWithLevel:3 resolution:19567.87924099992 scale:73957190.948944],
             [AGSLevelOfDetail levelOfDetailWithLevel:4 resolution:9783.939620499959 scale:36978595.474472],
             [AGSLevelOfDetail levelOfDetailWithLevel:5 resolution:4891.96981024998 scale:18489297.737236],
             [AGSLevelOfDetail levelOfDetailWithLevel:6 resolution:2445.98490512499 scale:9244648.868618],
             [AGSLevelOfDetail levelOfDetailWithLevel:7 resolution:1222.992452562495 scale:4622324.434309],
             [AGSLevelOfDetail levelOfDetailWithLevel:8 resolution:611.4962262813797 scale:2311162.217155],
             [AGSLevelOfDetail levelOfDetailWithLevel:9 resolution:305.7481131405576 scale:1155581.108577],
             [AGSLevelOfDetail levelOfDetailWithLevel:10 resolution:152.8740565704111 scale:577790.554289],
             [AGSLevelOfDetail levelOfDetailWithLevel:11 resolution:76.43702828507324 scale:288895.277144],
             [AGSLevelOfDetail levelOfDetailWithLevel:12 resolution:38.21851414253662 scale:144447.638572],
             [AGSLevelOfDetail levelOfDetailWithLevel:13 resolution:19.10925707126831 scale:72223.819286],
             [AGSLevelOfDetail levelOfDetailWithLevel:14 resolution:9.554628535634155 scale:36111.909643],
             [AGSLevelOfDetail levelOfDetailWithLevel:15 resolution:4.77731426794937 scale:18055.954822],
             [AGSLevelOfDetail levelOfDetailWithLevel:16 resolution:2.388657133974685 scale:9027.977411],
             [AGSLevelOfDetail levelOfDetailWithLevel:17 resolution:1.19432856685505 scale:4513.988705],
             [AGSLevelOfDetail levelOfDetailWithLevel:18 resolution:0.5971642835598172 scale:2256.994353],
             [AGSLevelOfDetail levelOfDetailWithLevel:19 resolution:0.2985821417799086 scale:1128.497175],
             [AGSLevelOfDetail levelOfDetailWithLevel:20 resolution:0.2985821417799086 scale:1128.497175]
             ]
             */

//            NSString *base;
//            NSString *scheme;
//
//            if (self.currentMapType == SPMMapTypeStreet)
//            {
//                base = @"https://{subDomain}.base.maps.cit.api.here.com";
//                scheme = @"normal.day.mobile";
//            }
//            else
//            {
//                base = @"https://{subDomain}.aerial.maps.cit.api.here.com";
//                scheme = @"hybrid.day.mobile";
//            }
//
//            NSString *template = [NSString stringWithFormat:@"%@/maptile/2.1/labeltile/newest/%@/{level}/{col}/{row}/256/png?app_id=%@&app_code=%@&ppi=250&lg=eng", base, scheme, SPMExternalAPIHereAppID, SPMExternalAPIHereAppCode];
//
//            AGSSpatialReference *spatialReference = [AGSSpatialReference webMercator];
//            AGSPoint *origin = [AGSPoint pointWithX:-20037508.342789
//                                                  y:20037508.368847
//                                   spatialReference:spatialReference];
//            AGSTileInfo *tileInfo = [AGSTileInfo tileInfoWithDPI:250
//                                                          format:AGSTileImageFormatPNG
//                                                  levelsOfDetail:[[((AGSWebTiledLayer *)[[[AGSBasemap openStreetMapBasemap] baseLayers] firstObject]) tileInfo] levelsOfDetail]
//                                                          origin:origin
//                                                spatialReference:spatialReference
//                                                      tileHeight:256
//                                                       tileWidth:256];
//
//            AGSEnvelope *fullExtent = [AGSEnvelope envelopeWithXMin:-20037508.342789
//                                                             yMin:-20037471.205137
//                                                             xMax:20037285.703808
//                                                             yMax:20037471.205137
//                                                 spatialReference:spatialReference];
//
//            self.SDOTStreetLabelsLayer = [[AGSWebTiledLayer alloc] initWithURLTemplate:template
//                                                                            subDomains:@[@"1", @"2", @"3", @"4"]
//                                                                              tileInfo:tileInfo
//                                                                            fullExtent:fullExtent];
//            self.SDOTStreetLabelsLayer.name = NSLocalizedString(@"Street Labels (HERE Maps)", nil);


            // ArcGIS vector road labels. Style can be customized online
            // Street https://www.arcgis.com/home/item.html?id=1768e8369a214dfab4e2167d5c5f2454
            // My version of Street https://www.arcgis.com/home/item.html?id=d2f77489c77b480c9b4a284bb640d966
            // Hybrid https://www.arcgis.com/home/item.html?id=30d6b8271e1849cd9c3042060001f425
            // My version of Hybrid https://www.arcgis.com/home/item.html?id=ef53af9052774f56a4bf9ab5a32db51a

            NSURL *vectorReferenceURL;
            if (self.currentMapType == SPMMapTypeStreet)
            {
                vectorReferenceURL = [NSURL URLWithString:@"https://www.arcgis.com/home/item.html?id=d2f77489c77b480c9b4a284bb640d966"];
            }
            else
            {
                vectorReferenceURL = [NSURL URLWithString:@"https://www.arcgis.com/home/item.html?id=ef53af9052774f56a4bf9ab5a32db51a"];
            }

            AGSArcGISVectorTiledLayer *vectorReferenceLayer = [[AGSArcGISVectorTiledLayer alloc] initWithURL:vectorReferenceURL];
            basemap = [AGSBasemap basemapWithBaseLayers:@[baseLayer]
                                        referenceLayers:@[self.SDOTParkingLinesLayer, vectorReferenceLayer]];
        }
        else
        {
            basemap = [AGSBasemap basemapWithBaseLayers:@[baseLayer]
                                        referenceLayers:@[self.SDOTParkingLinesLayer]];
        }
    }

    return basemap;
}

- (void)addBasemapObservers:(AGSBasemap *)basemap
{
    for (AGSLayer *layer in basemap.baseLayers)
    {
        [layer addObserver:self
                forKeyPath:@"loadStatus"
                   options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld)
                   context:ARCGISContext];
    }

    for (AGSLayer *layer in basemap.referenceLayers)
    {
        [layer addObserver:self
                forKeyPath:@"loadStatus"
                   options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld)
                   context:ARCGISContext];
    }

}

- (void)removeBasemapObservers:(AGSBasemap *)basemap
{
    for (AGSLayer *layer in basemap.baseLayers)
    {
        [layer removeObserver:self
                   forKeyPath:@"loadStatus"];
    }

    for (AGSLayer *layer in basemap.referenceLayers)
    {
        [layer removeObserver:self
                   forKeyPath:@"loadStatus"];
    }
}

- (void)loadMapView
{
    if (self.mapView.locationDisplay.started)
    {
        [self.mapView.locationDisplay stop];
    }
    
    self.loadedAllMapLayers = NO;
    
    // Hide it while loading
    [self.legendsButton setTitle:NSLocalizedString(@"Loading…", nil)
                        forState:UIControlStateNormal];
    self.legendsButton.userInteractionEnabled = NO;
    [self setLegendHidden:YES
              temporarily:YES];

    self.currentMapProvider = [NSUserDefaults.standardUserDefaults integerForKey:SPMDefaultsSelectedMapProvider];
    self.currentMapType = [NSUserDefaults.standardUserDefaults integerForKey:SPMDefaultsSelectedMapType];

    self.mapView.touchDelegate = self;
    self.mapView.callout.delegate = self;

    // Basemap
    if (self.mapView.map.basemap != nil)
    {
        [self removeBasemapObservers:self.mapView.map.basemap];
    }

    AGSBasemap *basemap = [self basemap];
    [self addBasemapObservers:basemap];

    self.mapView.map = [[AGSMap alloc] initWithSpatialReference:[AGSSpatialReference webMercator]];
    self.mapView.map.basemap = basemap;

    NSUInteger graphicsOverlayCount = self.mapView.graphicsOverlays.count;
    
    NSAssert(graphicsOverlayCount <= 1, @"Too many graphic overlays");
    
    if (graphicsOverlayCount > 1)
    {
        [self.mapView.graphicsOverlays removeAllObjects];
        graphicsOverlayCount = self.mapView.graphicsOverlays.count;
    }
    
    if (graphicsOverlayCount)
    {
        AGSGraphicsOverlay *overlay = self.mapView.graphicsOverlays.firstObject;
        if ([overlay isKindOfClass:AGSGraphicsOverlay.class])
        {
            self.parkingSpotGraphicsLayer = overlay;
        }
    }
    else
    {
        self.parkingSpotGraphicsLayer = [AGSGraphicsOverlay graphicsOverlay];
        [self.mapView.graphicsOverlays addObject:self.parkingSpotGraphicsLayer];
    }
}

- (void)refreshMapSettingsIfNeeded
{
    // Settings re entry
    SPMMapProvider newMapProvider = [[NSUserDefaults standardUserDefaults] integerForKey:SPMDefaultsSelectedMapProvider];
    if (self.currentMapProvider != newMapProvider)
    {
        self.currentMapProvider = newMapProvider;
        [self loadMapView];
    }

    SPMMapType newMapType = [[NSUserDefaults standardUserDefaults] integerForKey:SPMDefaultsSelectedMapType];
    if (self.currentMapType != newMapType)
    {
        self.currentMapType = newMapType;
        [self removeBasemapObservers:self.mapView.map.basemap];
        AGSBasemap *basemap = [self basemap];
        [self addBasemapObservers:basemap];
        self.mapView.map.basemap = basemap;

        [UIView animateWithDuration:.3
                         animations:^{
                             [self setNeedsStatusBarAppearanceUpdate];

                             if (self.currentMapType == SPMMapTypeAerial)
                             {
                                 self.gradientLayer.opacity = 1;
                             }
                             else
                             {
                                 self.gradientLayer.opacity = 0;
                             }
                         }];
    }
}


#pragma mark - Interface Actions

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    [super prepareForSegue:segue sender:segue];
    
    UINavigationController *navigationController = segue.destinationViewController;
    if ([navigationController isKindOfClass:[UINavigationController class]])
    {
        navigationController.delegate = self;
    }
    
    if ([segue.identifier isEqualToString:@"PresentTimeLimit"])
    {
        if ([navigationController isKindOfClass:[UINavigationController class]])
        {
            TimeLimitViewController *viewController = (TimeLimitViewController *)[[navigationController viewControllers] firstObject];
            if ([viewController isKindOfClass:[TimeLimitViewController class]])
            {
                viewController.delegate = self;
            }
        }
    }
    else if ([segue.identifier isEqualToString:@"PresentNeighborhoods"])
    {
        NeighborhoodsViewController *viewController = (NeighborhoodsViewController *)segue.destinationViewController;
        viewController.neighborhoodDataSource = self.neighborhoodDataSource;
        viewController.modalPresentationCapturesStatusBarAppearance = YES;
    }
}

- (IBAction)unwindFromInformationViewController:(UIStoryboardSegue *)segue
{
}

- (IBAction)unwindFromReminderViewController:(UIStoryboardSegue *)segue
{
}

- (IBAction)unwindFromNeighborhoodsViewController:(UIStoryboardSegue *)segue
{
    self.cachedHoodEnvelope = nil;
    [self centerOnSelectedNeighborhood];
}

- (AGSEnvelope *)cachedHoodEnvelope
{
    if (!_cachedHoodEnvelope)
    {
        AGSEnvelope *hoodEnvelope = self.neighborhoodDataSource.selectedNeighborhood.envelope;

        if (![hoodEnvelope.spatialReference isEqualToSpatialReference:self.mapView.visibleArea.spatialReference])
        {
            hoodEnvelope = (AGSEnvelope *)[AGSGeometryEngine projectGeometry:hoodEnvelope
                                                          toSpatialReference:self.mapView.visibleArea.spatialReference];
        }

        _cachedHoodEnvelope = hoodEnvelope;
    }

    return _cachedHoodEnvelope;
}

- (void)centerOnSelectedNeighborhood
{
    if (!self.neighborhoodDataSource.selectedNeighborhood)
    {
        self.cachedHoodEnvelope = nil;
        return;
    }

    [self updateNeighborhoodsButtonAnimated:YES
                                 completion:nil];

    self.mapView.viewpointChangedHandler = nil;

    [self.mapView setViewpointRotation:0
                            completion:^(BOOL isFfinished) {
                                [self.mapView setViewpointGeometry:self.cachedHoodEnvelope
                                                        completion:^(BOOL finished) {
                                                            self.mapView.viewpointChangedHandler = ^{
                                                                if (self.neighborhoodDataSource.selectedNeighborhood)
                                                                {
                                                                    NSAssert(self.cachedHoodEnvelope != nil, @"We must have a cached hood envelope");
                                                                    if (![AGSGeometryEngine geometry:self.mapView.visibleArea containsGeometry:self.cachedHoodEnvelope])
                                                                    {
                                                                        self.neighborhoodDataSource.selectedNeighborhood = nil;
                                                                        self.cachedHoodEnvelope = nil;
                                                                        [self updateNeighborhoodsButtonAnimated:YES
                                                                                                     completion:nil];
                                                                        self.mapView.viewpointChangedHandler = nil;
                                                                    }
                                                                }
                                                            };
                                                        }];
                            }];
}

- (IBAction)legendsTouched:(UIButton *)sender
{
    [self setLegendHidden:NO
                 animated:YES];
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
        if (version.majorVersion == 8)
        {
            [self reloadLegendTableView];
        }
    });
}

- (IBAction)neighborhoodsTouched:(UIButton *)sender
{
    if (self.neighborhoodDataSource.state == SPMStateFailedToLoad)
    {
        [self.neighborhoodsButton setTitle:NSLocalizedString(@"Loading…", nil)
                                  forState:UIControlStateNormal];
        self.neighborhoodsButton.enabled = NO;

        [self.neighborhoodDataSource loadNeighboorhoodsWithCompletionHandler:^(BOOL success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updateNeighborhoodsButtonAnimated:YES
                                             completion:^(BOOL finished) {
                                                 if (success)
                                                 {
                                                     [self performSegueWithIdentifier:@"PresentNeighborhoods"
                                                                               sender:nil];
                                                 }
                                             }];
            });
        }];
    }
    else
    {
        [self performSegueWithIdentifier:@"PresentNeighborhoods"
                                  sender:nil];
    }
}

- (IBAction)guideContainerTapped:(UITapGestureRecognizer *)recognizer
{
    [self setLegendHidden:YES
                 animated:YES];
}

- (void)setLegendHidden:(BOOL)hidden
               animated:(BOOL)animated
{
    [UIView animateWithDuration:.3
                     animations:^{
                         [self setLegendHidden:hidden];
                     }
                     completion:^(BOOL finished) {
                         [self updateLegendTableViewBounce];
                     }];
}

- (void)setLegendHidden:(BOOL)hidden
{
    [self setLegendHidden:hidden
              temporarily:NO];
}

- (void)setLegendHidden:(BOOL)hidden
            temporarily:(BOOL)temporarily
{
    self.gestureRecognizerGuideContainer.enabled = !hidden;
    
    if (!temporarily)
    {
        [[NSUserDefaults standardUserDefaults] setBool:hidden
                                                forKey:SPMDefaultsLegendHidden];
    }
    
    if (hidden)
    {
        self.legendsContainerCollapsedHeightConstraint.priority = UILayoutPriorityDefaultHigh + 1;
        self.legendContainerCollapsedWidthConstraint.priority = UILayoutPriorityDefaultHigh + 1;
        
        // Loading text is always bright
        if (!self.loadedAllMapLayers)
        {
            self.legendsButton.alpha = 1;
            self.legendContainerCollapsedWidthConstraint.constant = 100;
        }
        else
        {
            self.legendContainerCollapsedWidthConstraint.constant = 75;
            
            CGFloat adjustedValue = self.legendSlider.value + .5;
            if (adjustedValue > 1)
            {
                adjustedValue = 1;
            }
            self.legendsButton.alpha = adjustedValue;
        }
        
        self.legendTableView.alpha = 0;
        self.legendSlider.alpha = 0;
        
        //                         CGRect bounds = self.legendContainerView.bounds;
        //                         bounds.size.height = self.legendsContainerHeightConstraint.constant;
        //                         self.legendContainerView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:bounds cornerRadius:self.legendContainerView.layer.cornerRadius].CGPath;
        [self.view layoutIfNeeded];
    }
    else
    {
        self.legendsContainerCollapsedHeightConstraint.priority = UILayoutPriorityDefaultLow;
        self.legendContainerCollapsedWidthConstraint.priority = UILayoutPriorityDefaultLow;
        
        self.legendsButton.alpha = 0;
        
        CGFloat adjustedValue = self.legendSlider.value + .5;
        if (adjustedValue > 1)
        {
            adjustedValue = 1;
        }
        
        self.legendTableView.alpha = adjustedValue;
        self.legendSlider.alpha = adjustedValue;
        
        //                         CGRect bounds = self.legendContainerView.bounds;
        //                         bounds.size.height = self.legendsContainerHeightConstraint.constant;
        //                         self.legendContainerView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:bounds cornerRadius:self.legendContainerView.layer.cornerRadius].CGPath;
        [self.view layoutIfNeeded];
    }
}

- (IBAction)parkingTouched:(id)sender
{
    if (self.parkingSpotGraphicsLayer.graphics.count)
    {
        if ([ParkingManager sharedManager].currentSpot)
        {
            [self centerOnParkingSpot];
            return;
        }
        else
        {
            NSAssert(NO, @"We must have a graphic visible if we have a parking spot");
        }
    }
    
    
    [self setParkingSpotInCurrentLocationFromSource:SPMParkingSpotActionSourceApplication
                                              error:nil];
}

- (IBAction)opacitySliderChanged:(UISlider *)sender
{
    [[NSUserDefaults standardUserDefaults] setFloat:sender.value forKey:SPMDefaultsLegendOpacity];

    self.SDOTParkingLinesLayer.opacity = sender.value;
    
    CGFloat adjustedValue = sender.value + .5;
    if (adjustedValue > 1)
    {
        adjustedValue = 1;
    }
    
    self.legendTableView.alpha = adjustedValue;
    self.legendSlider.alpha = adjustedValue;
}

- (IBAction)updateLocationTouched:(UIBarButtonItem *)sender
{
    [self centerOnBestSpotWithLocationAuthorizationWarning:YES
                                                  animated:YES];
}

#pragma mark - Focus Actions

- (void)centerOnParkingSpot
{
    AGSGraphic *parkingGraphic = [self.parkingSpotGraphicsLayer.graphics firstObject];
    
    [self centerOnParkingGraphic:parkingGraphic
            attemptEnvelopeUnion:YES
                        animated:YES];
}

// attemptEnvelopeUnion is because we don't have proper heuristics when the current location is next to the parking spot, we will zoom too much.
- (void)centerOnParkingGraphic:(nonnull AGSGraphic *)parkingGraphic
          attemptEnvelopeUnion:(BOOL)attemptEnvelopeUnion
                      animated:(BOOL)animated
{
    NSAssert(parkingGraphic != nil, @"Must have graphic");
    if (!parkingGraphic)
    {
        return;
    }
    //    if ([self.mapView.callout.representedFeature isEqual:parkingGraphic])
    //    {
    //        //            if (![self.mapView isHidden])
    //        //            {
    //        return;
    //        //            }
    //    }
    
    AGSPoint *parkingPoint = (AGSPoint *)parkingGraphic.geometry;
    
    NSAssert([parkingPoint isKindOfClass:[AGSPoint class]], @"Unexpected");
    if ([parkingPoint isKindOfClass:[AGSPoint class]])
    {
        AGSPoint *currentLocation = self.mapView.locationDisplay.mapLocation;
        if (![currentLocation.spatialReference isEqualToSpatialReference:[self availableMapDataEnvelope].spatialReference])
        {
            currentLocation = (AGSPoint *)[AGSGeometryEngine projectGeometry:currentLocation
                                                          toSpatialReference:[self availableMapDataEnvelope].spatialReference];
        }
        
        if (![parkingPoint.spatialReference isEqualToSpatialReference:[self availableMapDataEnvelope].spatialReference])
        {
            parkingPoint = (AGSPoint *)[AGSGeometryEngine projectGeometry:parkingPoint
                                                       toSpatialReference:[self availableMapDataEnvelope].spatialReference];
        }
        
        // Try to union both envelopes (current location if it is on the map and the location of the parking spot)
        // Only do it if the current location is in our service area
        if (attemptEnvelopeUnion &&
            self.mapView.locationDisplay.mapLocation &&
            [AGSGeometryEngine geometry:[self availableMapDataEnvelope] containsGeometry:currentLocation])
        {
            AGSEnvelope *locationEnvelope = [AGSEnvelope envelopeWithCenter:currentLocation
                                                                      width:400
                                                                     height:400];
            AGSEnvelopeBuilder *builder = [AGSEnvelopeBuilder envelopeBuilderWithEnvelope:locationEnvelope];
            AGSEnvelope *parkingEnvelope = [AGSEnvelope envelopeWithCenter:parkingPoint
                                                                     width:400
                                                                    height:400];
            [builder unionWithEnvelope:parkingEnvelope];
            
            AGSEnvelope *wideEnvelope = [builder toGeometry];
            
            if (![wideEnvelope.spatialReference isEqualToSpatialReference:self.mapView.spatialReference])
            {
                wideEnvelope = (AGSEnvelope *)[AGSGeometryEngine projectGeometry:wideEnvelope
                                                              toSpatialReference:self.mapView.spatialReference];
            }
            
            if (![AGSGeometryEngine geometry:self.mapView.visibleArea.extent containsGeometry:wideEnvelope])
            {
                // Use this API instead of expanding the envelope, otherwise if you are very near the parking spot it will zoom in too much
                [self.mapView setViewpointGeometry:wideEnvelope
                                           padding:400
                                        completion:nil];
            }
            else
            {
                [self.mapView setViewpointCenter:wideEnvelope.center
                                      completion:nil];
            }
            
            // Expand the envelope so that both points are not at the edges.
            // [wideEnvelope expandByFactor:1.3];
            // [self.mapView zoomToEnvelope:wideEnvelope animated:YES];
        }
        else
        {
            // Otherwise just center at the point if we don't have the current location
            [self.mapView setViewpointCenter:parkingPoint
                                       scale:10000
                                  completion:nil];
        }
        
        if (self.mapView.callout.isHidden)
        {
            [self.mapView.callout showCalloutForGraphic:parkingGraphic
                                            tapLocation:parkingPoint
                                               animated:animated];
        }
        
        //    NSLog(@"Current location %@, point %@", self.mapView.locationDisplay.mapLocation, self.mapView.locationDisplay.location.point);
    }
}

//- (void)mapView:(AGSMapView *)mapView AGSMapView:(CGPoint)screen mapPoint:(AGSPoint *)mappoint features:(NSDictionary *)features;
//{
//    NSLog(@"Clicked features: %@", features);
//}

- (void)centerOnSDOTEnvelopeAnimated:(BOOL)animated
{
    [self.mapView setViewpointGeometry:[self SDOTEnvelope]
                            completion:nil];
}

- (void)centerOnBestSpotWithLocationAuthorizationWarning:(BOOL)authorizationWarning
                                                animated:(BOOL)animated
{
    CLAuthorizationStatus authorizationStatus = [CLLocationManager authorizationStatus];
    if (authorizationWarning == YES &&
        authorizationStatus != kCLAuthorizationStatusAuthorizedAlways &&
        authorizationStatus != kCLAuthorizationStatusAuthorizedWhenInUse &&
        authorizationStatus != kCLAuthorizationStatusNotDetermined)
    {
        [self presentLocationSettingsAlertForAlwaysAuthorization:NO
                                                      completion:nil];
    }
    else
    {
        if (self.neighborhoodDataSource.selectedNeighborhood)
        {
            [self centerOnSelectedNeighborhood];
            return;
        }
        
        if (self.mapView.locationDisplay.started)
        {
            AGSPoint *currentLocation = self.mapView.locationDisplay.mapLocation;
            AGSEnvelope *currentEnvelope = [self availableMapDataEnvelope];
            
            if (currentLocation && currentEnvelope && ![currentLocation.spatialReference isEqualToSpatialReference:[self availableMapDataEnvelope].spatialReference])
            {
                currentLocation = (AGSPoint *)[AGSGeometryEngine projectGeometry:currentLocation
                                                              toSpatialReference:currentEnvelope.spatialReference];
            }
            
            if (currentLocation && currentEnvelope &&[AGSGeometryEngine geometry:currentEnvelope
                                                                containsGeometry:currentLocation])
            {
                //    NSLog(@"Current location %@, point %@", self.mapView.locationDisplay.mapLocation, self.mapView.locationDisplay.location.point);
                [self.mapView setViewpointCenter:currentLocation
                                           scale:4500
                                      completion:nil];
                
                //    [self.mapView centerAtPoint:self.mapView.locationDisplay.mapLocation animated:YES];
                
                // If they had panned, it is automatically off, reset it!
                self.mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeRecenter;
                
                // Restore rotation
                if (self.mapView.rotation != 0)
                {
                    [self.mapView setViewpointRotation:0
                                            completion:nil];
                }
                return;
            }
            else
            {
                // Don't warn them if there is a modal
                if (![self presentedViewController])
                {
                    [Analytics logError:@"Location_OutOfArea"
                                message:@"User has tried to center on a location outside the service area"
                                  error:nil];
                    
                    UIAlertController *controller = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"No Parking Data Available For Your Location", nil)
                                                                                        message:NSLocalizedString(@"Your current location is outside the Seattle Department of Transportation's service area.", nil)
                                                                                 preferredStyle:UIAlertControllerStyleAlert];
                    [controller addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                                   style:UIAlertActionStyleCancel
                                                                 handler:nil]];
                    
                    [self SPMPresentAlertController:controller
                                           animated:YES
                                         completion:nil];
                }
            }
        }
        else
        {
            self.needsCenteringOnCurentLocation = YES;
            [self beginObservingLocationUpdates];
        }
        
        // Attempt to center on something
        if ([ParkingManager sharedManager].currentSpot)
        {
            [self centerOnParkingSpot];
        }
        else
        {
            [self centerOnSDOTEnvelopeAnimated:animated];
        }
    }
}

#pragma mark - Parking Spot

/// Returns current parking spot object or nil
- (AGSGeometry *)currentParkingSpot
{
    if (self.parkingSpotGraphicsLayer.graphics.count)
    {
        AGSGraphic *parkingGraphic = [self.parkingSpotGraphicsLayer.graphics firstObject];
        
        AGSGeometry *geometry = parkingGraphic.geometry;
        
        if ([geometry isKindOfClass:[AGSPoint class]])
        {
            return geometry;
        }
    }
    
    return nil;
}

- (void)synchronizeParkingSpotDisplayFromDataStore
{
    if ([ParkingManager sharedManager].currentSpot &&
        ![self isParkingSpotShownOnMap])
    {
        [self restoreParkingSpotMarker];
    }
    else if (![ParkingManager sharedManager].currentSpot &&
             [self isParkingSpotShownOnMap])
    {
        [self removeParkingSpotFromSource:SPMParkingSpotActionSourceWatch];
    }
}

- (void)removeParkingSpotFromSource:(SPMParkingSpotActionSource)source
{
    [self didClickAccessoryButtonForCallout:self.mapView.callout
                                 fromSource:source];
}

- (BOOL)setParkingSpotInCurrentLocationFromSource:(SPMParkingSpotActionSource)source
                                            error:(NSError **)error
{
    return [self setParkingSpotInCurrentLocationFromSource:source
                                                 timeLimit:nil
                                                     error:error];
}

- (BOOL)setParkingSpotInCurrentLocationFromSource:(SPMParkingSpotActionSource)source
                                        timeLimit:(nullable ParkingTimeLimit *)timeLimit
                                            error:(NSError **)error
{
    if (source == SPMParkingSpotActionSourceWatch)
    {
        CLAuthorizationStatus authorizationStatus = [CLLocationManager authorizationStatus];
        if (authorizationStatus != kCLAuthorizationStatusAuthorizedAlways &&
            authorizationStatus != kCLAuthorizationStatusAuthorizedWhenInUse)
        {
            [self presentLocationSettingsAlertForAlwaysAuthorization:NO
                                                          completion:nil];
            if (error != NULL)
            {
                *error = [NSError errorWithDomain:SPMErrorDomain
                                             code:SPMErrorCodeLocationAuthorization
                                         userInfo:@{NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"Please Enable Location Services on your iPhone", nil)}];
            }
            return NO;
        }
        // No need to warn them if the app is open, they will be warned when done in the background
        //        else if (authorizationStatus == kCLAuthorizationStatusAuthorizedWhenInUse)
        //        {
        //            [self presentLocationSettingsAlertForAlwaysAuthorization:YES
        //                                                          completion:nil];
        //            if (error != NULL)
        //            {
        //                *error = [NSError errorWithDomain:SPMErrorDomain
        //                                             code:SPMErrorCodeLocationBackgroundAuthorization
        //                                         userInfo:@{NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"Open the App on iPhone to Enable Watch Location Support", nil)}];
        //            }
        //            return NO;
        //        }
    }
    
    if (!self.loadedAllMapLayers || !self.mapView.locationDisplay.started || !self.isObservingLocationUpdates)
    {
        // We need to attempt to set it
        if (source == SPMParkingSpotActionSourceQuickAction)
        {
            NSLog(@"Could not find current location, will begin observing for location updates");
            self.needsToSetParkingSpotOnLoad = YES;
            return NO;
        }
    }
    
    AGSPoint *parkingPoint = self.mapView.locationDisplay.mapLocation;
    
    AGSEnvelope *currentEnvelope = [self availableMapDataEnvelope];
    if (parkingPoint.spatialReference.WKID != currentEnvelope.spatialReference.WKID) {
        parkingPoint = (AGSPoint *)[AGSGeometryEngine projectGeometry:parkingPoint toSpatialReference:currentEnvelope.spatialReference];
    }
    
    if ([AGSGeometryEngine geometry:currentEnvelope containsGeometry:parkingPoint])
    {
        if (source == SPMParkingSpotActionSourceWatch)
        {
            [Analytics logEvent:@"ParkingSpot_SetFromWatch_Success"];
        }
        else if (source == SPMParkingSpotActionSourceQuickAction)
        {
            [Analytics logEvent:@"ParkingSpot_SetFromQuickAction_Success"];
        }
        else
        {
            [Analytics logEvent:@"ParkingSpot_Set_Success"];
        }
        
        NSDate *parkDate;
        
        // Make sure that we use the date a watch passes to us, for example
        if (timeLimit.startDate)
        {
            parkDate = timeLimit.startDate;
        }
        else
        {
            parkDate = [NSDate date];
        }
        
        CLLocation *location = [[ParkingManager sharedManager] locationFromAGSPoint:parkingPoint];
        ParkingSpot *parkingSpot = [[ParkingSpot alloc] initWithLocation:location
                                                                    date:parkDate];
        parkingSpot.timeLimit = timeLimit;
        
        [ParkingManager sharedManager].currentSpot = parkingSpot;
        
        [self addAndShowParkingSpotMarkerWithPoint:parkingPoint
                                              date:parkDate];
        
        // Notify the watch
        if (source != SPMParkingSpotActionSourceWatch)
        {
            NSDictionary *watchSpot = [[ParkingManager sharedManager].currentSpot watchConnectivityDictionaryRepresentation];
            
            NSDictionary *message = @{SPMWatchAction: SPMWatchActionSetParkingSpot,
                                      SPMWatchResponseStatus: SPMWatchResponseSuccess,
                                      SPMWatchNeedsComplicationUpdate: @YES,
                                      SPMWatchObjectParkingSpot: watchSpot};
            [WCSession.defaultSession SPMSendMessage:message];
        }
        
        return YES;
    }
    else
    {
        NSString *errorMessage;
        
        if (source == SPMParkingSpotActionSourceWatch)
        {
            errorMessage = @"ParkingSpot_SetFromWatch_Failure";
        }
        else if (source == SPMParkingSpotActionSourceQuickAction)
        {
            errorMessage = @"ParkingSpot_SetFromQuickAction_Failure";
        }
        else
        {
            errorMessage = @"ParkingSpot_Set_Failure";
        }
        
        [Analytics logError:errorMessage
                    message:@"Outside of service area"
                      error:nil];
        
        UIAlertController *controller = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Could Not Set a Parking Spot", nil)
                                                                            message:NSLocalizedString(@"Your current location is outside the Seattle Department of Transportation's service area.", nil)
                                                                     preferredStyle:UIAlertControllerStyleAlert];
        [controller addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                       style:UIAlertActionStyleCancel
                                                     handler:nil]];
        
        [self SPMPresentAlertController:controller
                               animated:YES
                             completion:nil];
        
        if (error != NULL)
        {
            *error = [NSError errorWithDomain:SPMErrorDomain
                                         code:SPMErrorCodeLocationServiceArea
                                     userInfo:@{NSLocalizedFailureReasonErrorKey: @"Outside of SDOT Service Area"}];
        }
    }
    
    return NO;
}

- (BOOL)isParkingSpotShownOnMap
{
    if (self.parkingSpotGraphicsLayer.graphics.count)
    {
        return YES;
    }
    
    return NO;
}

- (void)restoreParkingSpotMarker
{
    AGSPoint *parkingPoint = [[ParkingManager sharedManager] pointFromLocation:[ParkingManager sharedManager].currentSpot.location];
    if (!parkingPoint)
    {
        return;
    }
    
    // This does not convert, might as well use the convenience method
    //        AGSPoint *parkingPoint = [[AGSPoint alloc] initWithJSON:lastParkingPoint
    //                                               spatialReference:self.mapView.spatialReference];
    
    // This is for a bug introduced during the watch app's development
    //        NSAssert([parkingPoint.spatialReference isEqualToSpatialReference:self.mapView.spatialReference], @"Mismatched spatial references");
    
    NSParameterAssert([self availableMapDataEnvelope]);
    
    if (![self availableMapDataEnvelope])
    {
        NSLog(@"Warning, attempting to restore park marker when map hasn't been loaded yet!");
        return;
    }
    
    if (![parkingPoint.spatialReference isEqualToSpatialReference:[self availableMapDataEnvelope].spatialReference])
    {
        parkingPoint = (AGSPoint *)[AGSGeometryEngine projectGeometry:parkingPoint
                                                   toSpatialReference:[self availableMapDataEnvelope].spatialReference];
    }
    
    if ([AGSGeometryEngine geometry:[self availableMapDataEnvelope] containsGeometry:parkingPoint])
    {
        [self addAndShowParkingSpotMarkerWithPoint:parkingPoint
                                              date:[ParkingManager sharedManager].currentSpot.date];
    }
    else
    {
        UIAlertController *controller = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Could Not Restore Your Parking Spot", nil)
                                                                            message:NSLocalizedString(@"Your current location is outside the Seattle Department of Transportation's service area. Your stored parking spot will now be removed.", nil)
                                                                     preferredStyle:UIAlertControllerStyleAlert];
        [controller addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                       style:UIAlertActionStyleCancel
                                                     handler:nil]];
        
        [self SPMPresentAlertController:controller
                               animated:YES
                             completion:nil];
        [Analytics logError:@"ParkingSpot_Restore_Failure"
                    message:@"Outside of service area"
                      error:nil];
        
        [ParkingManager sharedManager].currentSpot = nil;
        
        NSDictionary *message = @{SPMWatchAction: SPMWatchActionRemoveParkingSpot,
                                  SPMWatchNeedsComplicationUpdate: @YES,
                                  SPMWatchResponseStatus: SPMWatchResponseSuccess};
        [WCSession.defaultSession SPMSendMessage:message];
    }
}

- (void)addAndShowParkingSpotMarkerWithPoint:(nonnull AGSPoint *)parkingPoint
                                        date:(nullable NSDate *)date
{
    NSAssert(parkingPoint != nil, @"Must have a parking spot");
    if (!parkingPoint)
    {
        return;
    }
    
    NSUInteger graphicsOverlayCount = self.mapView.graphicsOverlays.count;
    
    NSAssert(graphicsOverlayCount <= 1, @"Too many graphic overlays");
    
    if (graphicsOverlayCount > 1)
    {
        [self.mapView.graphicsOverlays removeAllObjects];
        graphicsOverlayCount = self.mapView.graphicsOverlays.count;
    }
    
    AGSGraphic *parkingGraphic;
    
    if (graphicsOverlayCount)
    {
        AGSGraphicsOverlay *overlay = self.mapView.graphicsOverlays.firstObject;
        if ([overlay isKindOfClass:AGSGraphicsOverlay.class])
        {
            NSUInteger graphicsCount = overlay.graphics.count;
            
            NSAssert(graphicsCount <= 1, @"Too many graphics");
            
            if (graphicsCount > 1)
            {
                [overlay.graphics removeAllObjects];
            }
            
            parkingGraphic = overlay.graphics.firstObject;
        }
    }
    
    if (!parkingGraphic)
    {
        NSString *dateString;
        
        if (!date)
        {
            dateString = NSLocalizedString(@"Unknown Date", nil);
        }
        else
        {
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            dateFormatter.dateStyle = NSDateFormatterShortStyle;
            dateFormatter.timeStyle = NSDateFormatterShortStyle;
            dateString = [dateFormatter stringFromDate:date];
        }
        
        //    AGSSimpleMarkerSymbol *parkingSymbol = [AGSSimpleMarkerSymbol simpleMarkerSymbol];
        //    parkingSymbol.color = [UIColor redColor];
        //    parkingSymbol.style = AGSSimpleMarkerSymbolStyleX;
        //    parkingSymbol.outline.color = [[UIColor redColor] colorWithAlphaComponent:.85];
        //    parkingSymbol.outline.width = 2.5;
        //    parkingSymbol.size = CGSizeMake(20, 20);
        
        AGSPictureMarkerSymbol *pictureSymbol = [[AGSPictureMarkerSymbol alloc] initWithImage:[AGSImage imageNamed:@"Car"]];
        pictureSymbol.width = 40;
        pictureSymbol.height = 40;
        
        //    AGSTextSymbol *textSymbol = [AGSTextSymbol textSymbolWithText:@"🚗" color:[UIColor redColor]];
        //    textSymbol.fontFamily = @"Apple Color Emoji";
        //    textSymbol.fontSize = 40;
        
        parkingGraphic = [AGSGraphic graphicWithGeometry:parkingPoint
                                                  symbol:pictureSymbol
                                              attributes:@{@"title": NSLocalizedString(@"Parked Here", nil), @"date" : dateString}];
        
        [self.parkingSpotGraphicsLayer.graphics addObject:parkingGraphic];
    }
    
    [self centerOnParkingGraphic:parkingGraphic
            attemptEnvelopeUnion:NO
                        animated:YES];
    
    [UIView transitionWithView:self.parkingButton
                      duration:.3
                       options:UIViewAnimationOptionCurveEaseInOut
                    animations:^{
                        self.parkingButton.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:.65];
                        self.parkingButton.layer.shadowColor = [[UIColor redColor] colorWithAlphaComponent:1].CGColor;
                        self.parkingButton.layer.shadowRadius = 10;
                        self.parkingButton.layer.shadowOpacity = .7;
                        self.parkingButton.layer.shadowOffset = CGSizeZero;
                        self.parkingButton.layer.masksToBounds = NO;
                        self.parkingButton.clipsToBounds = NO;
                        self.parkingButton.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.parkingButton.bounds
                                                                                         cornerRadius:self.parkingButton.layer.cornerRadius].CGPath;
                    }
                    completion:nil];
}

#pragma mark - Parking Reminder

- (void)setParkingReminderWithLength:(nonnull NSNumber *)length
                   reminderThreshold:(nullable NSNumber *)reminderThreshold
                  fromViewController:(nullable UIViewController *)viewController
{
    NSDate *parkDate = [ParkingManager sharedManager].currentSpot.date;
    NSAssert(parkDate != nil, @"We must have a park date");
    
    if (viewController != self)
    {
        [viewController dismissViewControllerAnimated:YES
                                           completion:^{
                                               [self setParkingReminderWithLength:length
                                                                reminderThreshold:reminderThreshold
                                                               fromViewController:self];
                                           }];
        return;
    }
    
    void (^setParkingReminder)(NSDate *) = ^(NSDate *limitStartDate) {
        ParkingTimeLimit *timeLimit = [[ParkingTimeLimit alloc] initWithStartDate:limitStartDate
                                                                           length:length
                                                                reminderThreshold:reminderThreshold];
        
        [ParkingManager sharedManager].currentSpot.timeLimit = timeLimit;
        
        [Analytics logEvent:@"ParkingTimeLimit_Set_Success"
             withParameters:@{@"length": timeLimit.length,
                              @"reminderThreshold": timeLimit.reminderThreshold}];
        
        [WCSession.defaultSession SPMSendMessage:@{SPMWatchAction: SPMWatchActionSetParkingTimeLimit,
                                                   SPMWatchResponseStatus: SPMWatchResponseSuccess,
                                                   SPMWatchNeedsComplicationUpdate: @YES,
                                                   SPMWatchObjectParkingTimeLimit: [timeLimit watchConnectivityDictionaryRepresentation]}];
    };
    
    [ParkingTimeLimit creationActionPathForParkDate:parkDate
                                    timeLimitLength:length
                                            handler:^(SPMParkingTimeLimitSetActionPath actionPath, NSString * _Nullable alertTitle, NSString * _Nullable alertMessage) {
                                                if (actionPath == SPMParkingTimeLimitSetActionPathSet)
                                                {
                                                    setParkingReminder(parkDate);
                                                }
                                                else
                                                {
                                                    UIAlertController *controller = [UIAlertController alertControllerWithTitle:alertTitle
                                                                                                                        message:alertMessage
                                                                                                                 preferredStyle:UIAlertControllerStyleAlert];
                                                    
                                                    if (actionPath == SPMParkingTimeLimitSetActionPathWarn)
                                                    {
                                                        [controller addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                                                                       style:UIAlertActionStyleDefault
                                                                                                     handler:^(UIAlertAction * _Nonnull action) {
                                                                                                         setParkingReminder([NSDate date]);
                                                                                                     }]];
                                                    }
                                                    else if (actionPath == SPMParkingTimeLimitSetActionPathAsk)
                                                    {
                                                        [controller addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Initial Parking Time", nil)
                                                                                                       style:UIAlertActionStyleDefault
                                                                                                     handler:^(UIAlertAction * _Nonnull action) {
                                                                                                         setParkingReminder(parkDate);
                                                                                                     }]];
                                                        [controller addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Now", nil)
                                                                                                       style:UIAlertActionStyleDestructive
                                                                                                     handler:^(UIAlertAction * _Nonnull action) {
                                                                                                         setParkingReminder([NSDate date]);
                                                                                                     }]];
                                                    }
                                                    
                                                    [controller addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                                                                   style:UIAlertActionStyleCancel
                                                                                                 handler:nil]];
                                                    [self SPMPresentAlertController:controller
                                                                           animated:YES
                                                                         completion:nil];
                                                }
                                            }];
}

#pragma mark - Location

- (void)beginLocationUpdates
{
    // Don't automatically pan if we have a parking spot. This will be reset when the user taps the current location update, or dismisses the parking spot.
    // Test case: launch with a parking spot away from your current location.
    if (![ParkingManager sharedManager].currentSpot)
    {
        self.mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeRecenter;
    }
    
    //    self.mapView.locationDisplay.wanderExtentFactor = 1;
    
    //    self.mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeCompassNavigation;
    BOOL showsPing = YES;

#ifdef DEBUG
    if ([NSUserDefaults.standardUserDefaults boolForKey:@"FASTLANE_SNAPSHOT"])
    {
        showsPing = NO;
    }
#endif

    self.mapView.locationDisplay.showPingAnimationSymbol = showsPing;
    
    if (![[NSUserDefaults standardUserDefaults] boolForKey:SPMDefaultsNeedsBackgroundLocationWarning])
    {
        if ([WCSession isSupported])
        {
            if ([WCSession defaultSession].isWatchAppInstalled)
            {
                CLAuthorizationStatus authorizationStatus = [CLLocationManager authorizationStatus];
                if (authorizationStatus != kCLAuthorizationStatusAuthorizedAlways)
                {
                    self.locationManager = [[CLLocationManager alloc] init];
                    self.locationManager.delegate = self;
                    [self.locationManager requestAlwaysAuthorization];
                    return;
                }
            }
        }
    }
    
    if (self.mapView.locationDisplay.started)
    {
        return;
    }
    
    [self.mapView.locationDisplay startWithCompletion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"locationDisplay startWithCompletion %@", error);
        }
    }];
}

- (void)beginObservingLocationUpdates
{
    if (self.isObservingLocationUpdates)
    {
        return;
    }
    
    if (!self.mapView)
    {
        return;
    }
    
    // It is either this or subclassing the locationDisplay
    [self.mapView addObserver:self
                   forKeyPath:@"locationDisplay.location"
                      options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld)
                      context:RootViewControllerContext];
    
    self.isObservingLocationUpdates = YES;
}

- (void)stopObservingLocationUpdates
{
    if (!self.isObservingLocationUpdates)
    {
        return;
    }
    
    [self.mapView removeObserver:self
                      forKeyPath:@"locationDisplay.location"
                         context:RootViewControllerContext];
    
    self.isObservingLocationUpdates = NO;
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if (status != kCLAuthorizationStatusNotDetermined)
    {
        [self.mapView.locationDisplay startWithCompletion:^(NSError * _Nullable error) {
            if (error)
            {
                NSLog(@"Could not start location data source! %@. CLAuthorizationStatus: %lu", error, (unsigned long)status);
            }
        }];
        self.locationManager.delegate = nil;
        self.locationManager = nil;
    }
}


#pragma mark - Layer Loading

- (void)layerDidLoad:(AGSLayer *)layer
{
    SPMLog(@"Loaded layer name '%@' (%p)", layer.name, layer);
    
    if (!self.loadedAllMapLayers)
    {
        BOOL allLayersLoaded = YES;

        for (AGSLayer *mapLayer in self.mapView.map.basemap.baseLayers)
        {
            //        NSLog(@"Checking %@ is loaded %i", layer.name, [layer loaded]);
            if (mapLayer.loadStatus != AGSLoadStatusLoaded)
            {
                //            NSLog(@"Waiting for %@ to load", layer.name);
                allLayersLoaded = NO;
                break;
            }
        }

        for (AGSLayer *mapLayer in self.mapView.map.basemap.referenceLayers)
        {
            //        NSLog(@"Checking %@ is loaded %i", layer.name, [layer loaded]);
            if (mapLayer.loadStatus != AGSLoadStatusLoaded)
            {
                //            NSLog(@"Waiting for %@ to load", layer.name);
                allLayersLoaded = NO;
                break;
            }
        }
        
        if (allLayersLoaded)
        {
            SPMLog(@"All map layers have loaded!");
            
            self.loadedAllMapLayers = YES;
            
            self.locationButton.layer.borderColor = [UIColor whiteColor].CGColor;
            self.parkingButton.layer.borderColor = [UIColor whiteColor].CGColor;
            [self updateNeighborhoodsButtonAnimated:NO
                                         completion:nil];
            self.locationButton.enabled = YES;
            self.parkingButton.enabled = YES;
            self.legendSlider.enabled = YES;
            
            if ([ParkingManager sharedManager].currentSpot)
            {
                [self restoreParkingSpotMarker];
            }
            else
            {
                [self centerOnBestSpotWithLocationAuthorizationWarning:NO
                                                              animated:NO];
            }
            
            if (self.needsToSetParkingSpotOnLoad)
            {
                [self beginObservingLocationUpdates];
            }
            
            [self presentInitialAlertsIfNeededWithCompletion:^{
                if ([ParkingManager sharedManager].currentSpot)
                {
                    // This is needed or we have centering issues
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [self beginLocationUpdates];
                    });
                }
                else
                {
                    [self beginLocationUpdates];
                }
            }];
            [self enableLegendButtonIfPossible];
        }
    }
    
    /*
     SDOT Web UI Defaults are 1,7,5,6,8,9
     
     Parking in Seattle (0)
     Garages and Lots (1)
     With > 350 Stalls (2)
     With > 100 Stalls (3)
     All Facilities (4)
     Street Parking Signs (5)
     Temporary No Parking (6) (overlay, not part of category, do not confuse with carpool color. This is rounded purple overlay)
     Street Parking by Category (7)
     Peak Hour No Parking (8)
     One-Way Streets (9) (shows arrows in streets)
     Addresses Eligible for RPZ Permits (10) (overlayed on top of normal RPZ category and other categories as well, rounded yellow overlay)
     */
    
    // Fetch legends and show/hide the layers we need
    if (layer == self.SDOTParkingLinesLayer)
    {
        AGSArcGISMapImageSublayer *firstLayer = (AGSArcGISMapImageSublayer *)self.SDOTParkingLinesLayer.subLayerContents.firstObject;
        if ([firstLayer isKindOfClass:[AGSArcGISMapImageSublayer class]])
        {
            __block BOOL loadedLayer6 = NO;
            __block BOOL loadedLayer7 = NO;
            
            for (AGSArcGISMapImageSublayer *sublayer in firstLayer.subLayerContents)
            {
                // Set the layers we need to set visible
                if (sublayer.sublayerID == 1 || sublayer.sublayerID == 6 || sublayer.sublayerID == 7)
                {
                    sublayer.visible = YES;
                }
                else
                {
                    sublayer.visible = NO;
                }
                
                // Fetch Legends
                if (sublayer.sublayerID == 6 || sublayer.sublayerID == 7)
                {
                    if (!self.loadedGuide)
                    {
                        [sublayer fetchLegendInfosWithCompletion:^(NSArray<AGSLegendInfo *> * _Nullable legendInfos, NSError * _Nullable error) {
                            if (error) {
                                NSLog(@"Failed to load legend info for sublayer %@ with error %@", sublayer, error);
                                
                                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                                    [self.legendDataSource synthesizeDefaultLegends];
                                    self.loadedGuide = YES;
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        [self reloadLegendsAndUpdateButton];
                                    });
                                });
                            }
                            else
                            {
                                NSUInteger count = legendInfos.count;
                                for (NSUInteger i = 0; i < count; i++)
                                {
                                    AGSLegendInfo *legendInfo = legendInfos[i];
                                    
                                    Legend *legend = [[Legend alloc] init];
                                    legend.name = legendInfo.name;
                                    
                                    // Hapens for "Temporary No Parking"
                                    if (![legend.name length])
                                    {
                                        legend.name = sublayer.name;
                                    }
                                    
                                    legend.index = i;
                                    
                                    [self.legendDataSource addLegend:legend];
                                    
                                    if (sublayer.sublayerID == 6)
                                    {
                                        loadedLayer6 = YES;
                                    }
                                    else if (sublayer.sublayerID == 7)
                                    {
                                        loadedLayer7 = YES;
                                    }
                                }
                                
                                if (loadedLayer6 && loadedLayer7) {
                                    [self.legendDataSource sortLegends];
                                    self.loadedGuide = YES;
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        [self reloadLegendsAndUpdateButton];
                                    });
                                }
                            }
                        }];
                    }
                }
            }
        }
    }
}

- (void)layer:(AGSLayer *)layer didFailToLoadWithError:(NSError *)error
{
    NSLog(@"Failed to load layer %@\n%@", layer.name, error);
    
    NSString *errorTitle;
    
    if ([[NSUserDefaults standardUserDefaults] integerForKey:SPMDefaultsSelectedMapProvider] == SPMMapProviderSDOT)
    {
        errorTitle = [NSString stringWithFormat:NSLocalizedString(@"Could Not Load SDOT Data for %@ Map", nil), layer.name];
    }
    else
    {
        errorTitle = [NSString stringWithFormat:NSLocalizedString(@"Could Not Load %@ Map", nil), layer.name];
    }
    
    UIAlertController *controller = [UIAlertController alertControllerWithTitle:errorTitle
                                                                        message:[NSString stringWithFormat:NSLocalizedString(@"This may be a temporary error in SDOT's servers. Please try again later. (%@ %@)", nil),  error.localizedDescription, error.localizedFailureReason]
                                                                 preferredStyle:UIAlertControllerStyleAlert];
    [controller addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Try Again", nil)
                                                   style:UIAlertActionStyleCancel
                                                 handler:^(UIAlertAction * _Nonnull action) {
                                                     if ([layer respondsToSelector:@selector(retryLoadWithCompletion:)])
                                                     {
                                                         [layer retryLoadWithCompletion:nil];
                                                     }
                                                 }]];
    
    [self SPMPresentAlertController:controller
                           animated:YES
                         completion:nil];
    
    [Analytics logError:@"Map_LayerFailedToLoad"
                message:errorTitle
                  error:error];
}

#pragma mark - AGSGeoViewTouchDelegate

- (void)geoView:(AGSGeoView *)geoView didTapAtScreenPoint:(CGPoint)screenPoint mapPoint:(AGSPoint *)mapPoint
{
    [geoView identifyGraphicsOverlaysAtScreenPoint:screenPoint
                                         tolerance:22
                                  returnPopupsOnly:NO
                                        completion:^(NSArray<AGSIdentifyGraphicsOverlayResult *> * _Nullable identifyResults, NSError * _Nullable error) {
                                            if (error)
                                            {
                                                NSLog(@"didTapAtScreenPoint error %@", error);
                                            }
                                            else
                                            {
                                                dispatch_async(dispatch_get_main_queue(), ^{
                                                    AGSIdentifyGraphicsOverlayResult *result = identifyResults.firstObject;
                                                    AGSGraphic *graphic = result.graphics.firstObject;
                                                    if (graphic == nil)
                                                    {
                                                        if (!self.mapView.callout.isHidden)
                                                        {
                                                            [self.mapView.callout dismiss];
                                                        }
                                                    }
                                                    else if (graphic == self.parkingSpotGraphicsLayer.graphics.firstObject)
                                                    {
                                                        [self.mapView.callout showCalloutForGraphic:graphic
                                                                                        tapLocation:mapPoint
                                                                                           animated:YES];
                                                    }
                                                });
                                            }
                                        }];
}

#pragma mark - AGSCalloutDelegate

- (BOOL)callout:(AGSCallout *)callout willShowAtMapPoint:(AGSPoint *)mapPoint;
{
    // At this point the user does not care anymore about the legend or overlays, just getting there.
    [self.legendSlider setValue:0
                       animated:YES];
    
    [UIView animateWithDuration:.3
                     animations:^{
                         self.SDOTParkingLinesLayer.opacity = 0;
                         [self setLegendHidden:YES
                                   temporarily:YES];
                     }];
    
    NSArray *topLevelObjects = [[UINib nibWithNibName:@"CalloutView" bundle:nil] instantiateWithOwner:nil
                                                                                              options:nil];
    
    NSAssert([topLevelObjects count] > 0, @"Can not load nib");
    
    if ([topLevelObjects count])
    {
        ParkingSpotCalloutView *calloutView = [topLevelObjects firstObject];
        
        NSDate *parkDate = [ParkingManager sharedManager].currentSpot.date;
        NSAssert(parkDate != nil, @"We must have a park date");
        
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.doesRelativeDateFormatting = YES;
        dateFormatter.locale = [NSLocale currentLocale];
        
        dateFormatter.dateStyle = NSDateFormatterShortStyle;
        calloutView.labelTitle.text = [dateFormatter stringFromDate:parkDate];
        
        dateFormatter.dateStyle = NSDateFormatterNoStyle;
        dateFormatter.timeStyle = NSDateFormatterShortStyle;
        calloutView.labelSubtitle.text = [dateFormatter stringFromDate:parkDate];
        
        __weak typeof(calloutView) weakCalloutView = calloutView;
        
        calloutView.timeBlock = ^{
            if ([ParkingManager sharedManager].currentSpot.timeLimit)
            {
                void (^removeParkingTimeLimitBlock)(void) = ^{
                    [Analytics logEvent:@"ParkingTimeLimit_Remove"];
                    [ParkingManager sharedManager].currentSpot.timeLimit = nil;
                    self.timeLimitAlertController = nil;
                    
                    NSDictionary *message = @{SPMWatchAction: SPMWatchActionRemoveParkingTimeLimit,
                                              SPMWatchNeedsComplicationUpdate: @YES,
                                              SPMWatchResponseStatus: SPMWatchResponseSuccess};
                    [WCSession.defaultSession SPMSendMessage:message];
                };
                
                NSString *message;
                if ([[ParkingManager sharedManager].currentSpot.timeLimit isExpired])
                {
                    message = [NSString stringWithFormat:NSLocalizedString(@"The time limit of %@ expired %@ ago", nil),
                               [[ParkingManager sharedManager].currentSpot.timeLimit localizedLengthString],
                               [[ParkingManager sharedManager].currentSpot.timeLimit localizedExpiredAgoString]];
                    self.timeLimitAlertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Time Limit Expired", nil)
                                                                                        message:message
                                                                                 preferredStyle:UIAlertControllerStyleAlert];
                    [self.timeLimitAlertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Remove", nil)
                                                                                      style:UIAlertActionStyleDestructive
                                                                                    handler:^(UIAlertAction * _Nonnull action) {
                                                                                        removeParkingTimeLimitBlock();
                                                                                    }]];
                }
                else
                {
                    NSString *expireDateString = [[ParkingManager sharedManager].currentSpot.timeLimit localizedEndDateString];
                    
                    message = [NSString stringWithFormat:NSLocalizedString(@"Expires %@", nil), expireDateString];
                    
                    NSString *title = [NSString stringWithFormat:NSLocalizedString(@"%@ Time Limit", nil),
                                       [[[ParkingManager sharedManager].currentSpot.timeLimit localizedLengthString] capitalizedString]];
                    
                    self.timeLimitAlertController = [UIAlertController alertControllerWithTitle:title
                                                                                        message:message
                                                                                 preferredStyle:UIAlertControllerStyleAlert];
                    [self.timeLimitAlertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Keep", nil)
                                                                                      style:UIAlertActionStyleCancel
                                                                                    handler:^(UIAlertAction * _Nonnull action) {
                                                                                        self.timeLimitAlertController = nil;
                                                                                    }]];
                    [self.timeLimitAlertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Remove", nil)
                                                                                      style:UIAlertActionStyleDestructive
                                                                                    handler:^(UIAlertAction * _Nonnull action) {
                                                                                        removeParkingTimeLimitBlock();
                                                                                    }]];
                }
                
                [self SPMPresentAlertController:self.timeLimitAlertController
                                       animated:YES
                                     completion:nil];
                return;
            }
            
            UIAlertController *controller = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Set Parking Time Limit", nil)
                                                                                message:NSLocalizedString(@"You will be notified 10 minutes before your time is up", nil)
                                                                         preferredStyle:UIAlertControllerStyleActionSheet];
            
            NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
            formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
            formatter.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorDropAll;
            
            NSOrderedSet *predefinedIntervals = [ParkingTimeLimit defaultLengthTimeIntervals];
            if ([ParkingManager sharedManager].userDefinedParkingTimeLimit)
            {
                NSMutableOrderedSet *mutablePredefinedIntervals = [predefinedIntervals mutableCopy];
                [mutablePredefinedIntervals addObject:[ParkingManager sharedManager].userDefinedParkingTimeLimit];
                
                NSSortDescriptor *lowestToHighest = [NSSortDescriptor sortDescriptorWithKey:@"self"
                                                                                  ascending:YES];
                [mutablePredefinedIntervals sortUsingDescriptors:@[lowestToHighest]];
                
                predefinedIntervals = mutablePredefinedIntervals;
            }
            
            for (NSNumber *secondsNumber in predefinedIntervals)
            {
                NSTimeInterval timeInterval = [secondsNumber doubleValue];
                [controller addAction:[UIAlertAction actionWithTitle:[formatter stringFromTimeInterval:timeInterval]
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction * _Nonnull action) {
                                                                 [self setParkingReminderWithLength:@(timeInterval)
                                                                                  reminderThreshold:nil
                                                                                 fromViewController:self];
                                                             }]];
            }
            
            [controller addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Custom", nil)
                                                           style:UIAlertActionStyleDestructive
                                                         handler:^(UIAlertAction * _Nonnull action) {
                                                             [self performSegueWithIdentifier:@"PresentTimeLimit"
                                                                                       sender:self];
                                                         }]];
            [controller addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil]];
            
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
            {
                controller.popoverPresentationController.sourceView = weakCalloutView.popoverSourceView;
                controller.popoverPresentationController.sourceRect = weakCalloutView.popoverSourceView.frame;
            }
            
            [self presentViewController:controller
                               animated:YES
                             completion:nil];
        };
        
        calloutView.dismissBlock = ^{
            [self didClickAccessoryButtonForCallout];
        };
        
        callout.clipsToBounds = YES;
        callout.margin = CGSizeZero;
        callout.cornerRadius = 5;
        callout.color = [UIColor colorWithWhite:0 alpha:.8];
        callout.customView = calloutView;
    }
    
    return YES;
}

- (void)calloutDidDismiss:(AGSCallout *)callout
{
    [self.legendSlider setValue:[[NSUserDefaults standardUserDefaults] floatForKey:SPMDefaultsLegendOpacity]
                       animated:YES];
    
    [UIView animateWithDuration:.3
                     animations:^{
                         self.SDOTParkingLinesLayer.opacity = self.legendSlider.value;
                         [self setLegendHidden:[[NSUserDefaults standardUserDefaults] boolForKey:SPMDefaultsLegendHidden]];
                     }
                     completion:^(BOOL finished) {
                         [self updateLegendTableViewBounce];
                     }];
}

- (void)didClickAccessoryButtonForCallout
{
    [self didClickAccessoryButtonForCallout:self.mapView.callout];
    
}

- (void)didClickAccessoryButtonForCallout:(AGSCallout *)callout
{
    [self didClickAccessoryButtonForCallout:callout
                                 fromSource:SPMParkingSpotActionSourceApplication];
}

- (void)didClickAccessoryButtonForCallout:(AGSCallout *)callout
                               fromSource:(SPMParkingSpotActionSource)source
{
    switch (source)
    {
        case SPMParkingSpotActionSourceApplication:
            [Analytics logEvent:@"ParkingSpot_Remove"];
            break;
        case SPMParkingSpotActionSourceWatch:
            [Analytics logEvent:@"ParkingSpot_RemoveFromWatch"];
            break;
        case SPMParkingSpotActionSourceNotification:
            [Analytics logEvent:@"ParkingSpot_RemoveFromNotification"];
            break;
        case SPMParkingSpotActionSourceQuickAction:
            [Analytics logEvent:@"ParkingSpot_RemoveFromQuickAction"];
            break;
            
        default:
            break;
    }
    
    // Happens when removing parking spot with hidden callout
    AGSGraphic *parkingSpotGraphic = (AGSGraphic *)callout.representedObject;
    
    if (!parkingSpotGraphic)
    {
        [self.parkingSpotGraphicsLayer.graphics removeAllObjects];
    }
    else
    {
        [self.parkingSpotGraphicsLayer.graphics removeObject:parkingSpotGraphic];
    }
    
    [ParkingManager sharedManager].currentSpot = nil;
    
    if (source != SPMParkingSpotActionSourceWatch)
    {
        NSDictionary *message = @{SPMWatchAction: SPMWatchActionRemoveParkingSpot,
                                  SPMWatchNeedsComplicationUpdate: @YES,
                                  SPMWatchResponseStatus: SPMWatchResponseSuccess};
        [WCSession.defaultSession SPMSendMessage:message];
    }
    
    [callout dismiss];
    
    [UIView transitionWithView:self.parkingButton
                      duration:.3
                       options:UIViewAnimationOptionCurveEaseInOut
                    animations:^{
                        self.parkingButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:.65];
                        self.parkingButton.layer.shadowColor = [UIColor blackColor].CGColor;
                        self.parkingButton.layer.shadowRadius = 0;
                        self.parkingButton.layer.shadowOpacity = 0;
                    }
                    completion:^(BOOL finished) {
                        self.mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeRecenter;
                    }];
}

/// Where parking data is available
- (AGSEnvelope *)SDOTEnvelope
{
    // This was obtained by zooming out to the limits of the city of Seattle and inspecting the ArcGIS map view's properties.
    // NAD_1983_HARN_StatePlane_Washington_North_FIPS_4601_Feet
    AGSSpatialReference *reference = [AGSSpatialReference spatialReferenceWithWKID:SPMSpatialReferenceWKIDSDOT];
    AGSEnvelope *envelope = [AGSEnvelope envelopeWithXMin:1252147
                                                     yMin:212886
                                                     xMax:1286214
                                                     yMax:238886
                                         spatialReference:reference];

// Full Extent from the site
//    "xmin": 1202147,
//    "ymin": 180886,
//    "xmax": 1329214,
//    "ymax": 274486,
//    "spatialReference": {
//        "wkid": 2926
//    }
    return envelope;
}

#pragma mark - Map Loading

/// Essentially the state of WA, where there is data, you can still set a parking spot there
- (AGSEnvelope *)availableMapDataEnvelope
{
    return self.SDOTParkingLinesLayer.mapServiceInfo.fullExtent;
}

#pragma mark - Alerts

- (void)SPMPresentAlertController:(nonnull UIAlertController *)alertController
                         animated:(BOOL)animated
                       completion:(void (^ __nullable)(void))completion
{
    UIViewController *presentingViewController = self;
    
    while ([presentingViewController presentedViewController] != nil)
    {
        presentingViewController = [presentingViewController presentedViewController];
    }
    
    [presentingViewController presentViewController:alertController
                                           animated:animated
                                         completion:completion];
}

// Handles the chaining of initial alerts to avoid conflicts with location prompt alerts we may not control and UIAlertController's lack of multiple display logic
- (void)presentInitialAlertsIfNeededWithCompletion:(dispatch_block_t)completion
{
    if ([self needsToPresentInitialWarningAlert])
    {
        [self presentInitialWarningAlertWithCompletion:^(UIAlertAction *action) {
            [self presentInitialAlertsIfNeededWithCompletion:completion];
        }];
    }
    else if ([self needsToPresentSDOTMaintenanceAlert])
    {
        [self presentSDOTMaintenanceWarningWithCompletion:^(UIAlertAction *action) {
            [self presentInitialAlertsIfNeededWithCompletion:completion];
        }];
    }
    else if ([self needsToPresentBackgroundLocationAlert])
    {
        [self presentBackgroundLocationAlertWithCompletion:^(UIAlertAction *action) {
            [self presentInitialAlertsIfNeededWithCompletion:completion];
        }];
    }
    else
    {
        if (completion)
        {
            completion();
        }
    }
}

- (BOOL)needsToPresentBackgroundLocationAlert
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SPMDefaultsNeedsBackgroundLocationWarning])
    {
        return YES;
    }
    
    return NO;
}

- (void)presentBackgroundLocationAlertWithCompletion:(void (^ __nullable)(UIAlertAction *action))completion
{
    [self presentLocationSettingsAlertForAlwaysAuthorization:YES
                                                  completion:completion];
    [[NSUserDefaults standardUserDefaults] setBool:NO
                                            forKey:SPMDefaultsNeedsBackgroundLocationWarning];
}

- (BOOL)needsToPresentInitialWarningAlert
{
    if (![[NSUserDefaults standardUserDefaults] boolForKey:SPMDefaultsShownInitialWarning])
    {
        return YES;
    }
    
    return NO;
}

- (void)presentInitialWarningAlertWithCompletion:(void (^ __nullable)(UIAlertAction *action))completion
{
#ifdef DEBUG
    if ([NSUserDefaults.standardUserDefaults boolForKey:@"FASTLANE_SNAPSHOT"])
    {
        return;
    }
#endif

    // Official SDOT Wording: There may be a time lag between sign installation and record data entry; consequently, the map may not reflect on- the-ground reality. Always comply with city parking rules and regulations
    UIAlertController *controller = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Welcome", nil)
                                                                        message:NSLocalizedString(@"This map may not always reflect on-the-ground reality. There may be delays between on-street changes and the map being updated.\n\nAlways double check before parking and comply with city regulations and signs posted on the street.", nil)
                                                                 preferredStyle:UIAlertControllerStyleAlert];
    [controller addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                   style:UIAlertActionStyleCancel
                                                 handler:completion]];
    
    [self SPMPresentAlertController:controller
                           animated:YES
                         completion:nil];
    
    [[NSUserDefaults standardUserDefaults] setBool:YES
                                            forKey:SPMDefaultsShownInitialWarning];
}

- (BOOL)needsToPresentSDOTMaintenanceAlert
{
    // We could check against our server for a true datetime, but I don't think it is that critical for this app and our audience.
    NSDate *currentDate = [NSDate date];
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [calendar components:(NSCalendarUnitHour | NSCalendarUnitDay) fromDate:currentDate];
    NSInteger hour = [components hour];
    if (hour >= 0 && hour < 3)
    {
        // Have we shown this already?
        NSDate *lastShownDate = [[NSUserDefaults standardUserDefaults] objectForKey:SPMDefaultsShownMaintenanceWarningDate];
        if (!lastShownDate || ![calendar isDate:lastShownDate inSameDayAsDate:currentDate])
        {
            return YES;
        }
    }
    
    return NO;
}

- (void)presentSDOTMaintenanceWarningWithCompletion:(void (^ __nullable)(UIAlertAction *action))completion
{
    UIAlertController *controller = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Maintenance Warning", nil)
                                                                        message:NSLocalizedString(@"SDOT performs daily maintenance on the map overnight from 12 midnight to 3 AM. There may be performance issues and missing data during this time period.", nil)
                                                                 preferredStyle:UIAlertControllerStyleAlert];
    [controller addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                   style:UIAlertActionStyleCancel
                                                 handler:^(UIAlertAction * _Nonnull action) {
                                                     [[NSUserDefaults standardUserDefaults] setObject:[NSDate date]
                                                                                               forKey:SPMDefaultsShownMaintenanceWarningDate];
                                                     if (completion)
                                                     {
                                                         completion(action);
                                                     }
                                                 }]];
    
    [self SPMPresentAlertController:controller
                           animated:YES
                         completion:nil];
}

- (void)presentLocationSettingsAlertForAlwaysAuthorization:(BOOL)alwaysAuthorization
                                                completion:(void (^ __nullable)(UIAlertAction *action))completion
{
    NSString *title;
    NSString *message;
    
    if (alwaysAuthorization)
    {
        title = NSLocalizedString(@"Not Authorized to Use Background Location Services", nil);
        message = NSLocalizedString(@"To use the Apple Watch application, please go into the privacy settings and allow 'Always' location access.", nil);
    }
    else
    {
        title = NSLocalizedString(@"Not Authorized to Use Location Services", nil);
        message = NSLocalizedString(@"Please go into your privacy settings and allow access to location services for this application.", nil);
    }
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *settingsAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Open Settings", nil)
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * _Nonnull action) {
                                                               if (completion)
                                                               {
                                                                   completion(action);
                                                               }
                                                               
                                                               // I don't see the need for canOpenURL here and dependent UIAlertActions
                                                               NSURL *settingsURL = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                                                               [UIApplication.sharedApplication openURL:settingsURL
                                                                                                options:@{}
                                                                                      completionHandler:nil];
                                                           }];
    
    UIAlertAction *laterAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Later", nil)
                                                          style:UIAlertActionStyleCancel
                                                        handler:completion];
    
    [alertController addAction:settingsAction];
    [alertController addAction:laterAction];
    
    [self SPMPresentAlertController:alertController
                           animated:YES
                         completion:nil];
    
    if (alwaysAuthorization)
    {
        [Analytics logError:@"Location_Disabled_Always"
                    message:@"User has disabled background location"
                      error:nil];
    }
    else
    {
        [Analytics logError:@"Location_Disabled"
                    message:@"User has disabled location"
                      error:nil];
    }
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == self.legendTableView)
    {
        return UITableViewAutomaticDimension;
    }
    
    return tableView.rowHeight;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(nonnull UITableViewCell *)cell forRowAtIndexPath:(nonnull NSIndexPath *)indexPath
{
    if (tableView == self.legendTableView)
    {
        cell.backgroundColor = [UIColor clearColor];
        cell.contentView.backgroundColor = [UIColor clearColor];
        
        LegendTableViewCell *legendCell = (LegendTableViewCell *)cell;
        UIFontDescriptor *descriptor = legendCell.legendLabel.font.fontDescriptor;
        
        if (legendCell.legend.isBold)
        {
            if (!(legendCell.legendLabel.font.fontDescriptor.symbolicTraits & UIFontDescriptorTraitBold))
            {
                UIFontDescriptor *newDescriptor = [descriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold];
                
                legendCell.legendLabel.font = [UIFont fontWithDescriptor:newDescriptor
                                                                    size:legendCell.legendLabel.font.pointSize];
            }
        }
        else
        {
            if (legendCell.legendLabel.font.fontDescriptor.symbolicTraits & UIFontDescriptorTraitBold)
            {
                UIFontDescriptor *newDescriptor = [descriptor fontDescriptorWithSymbolicTraits:descriptor.symbolicTraits & ~UIFontDescriptorTraitBold];
                legendCell.legendLabel.font = [UIFont fontWithDescriptor:newDescriptor
                                                                    size:legendCell.legendLabel.font.pointSize];
            }
        }
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (tableView == self.legendTableView)
    {
        if (section == 0)
        {
            return 0;
        }
    }
    
    return tableView.sectionHeaderHeight;
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section
{
    if (tableView == self.legendTableView)
    {
        UITableViewHeaderFooterView *headerView = (UITableViewHeaderFooterView *)view;
        headerView.backgroundView.opaque = NO;
        headerView.backgroundView.backgroundColor = [UIColor clearColor];
    }
}

- (void)reloadLegendsAndUpdateButton
{
    [self reloadLegendTableView];
    [self enableLegendButtonIfPossible];
}

- (void)enableLegendButtonIfPossible
{
    if (!self.loadedAllMapLayers || !self.loadedGuide || self.legendsButton.userInteractionEnabled == YES)
    {
        return;
    }
    
    [UIView animateWithDuration:.3
                     animations:^{
                         [self.legendsButton setTitle:NSLocalizedString(@"Guide", nil)
                                             forState:UIControlStateNormal];
                         self.legendsButton.userInteractionEnabled = YES;
                         
                         // Otherwise the callout (willShowForFeature) will override this for us
                         if (![ParkingManager sharedManager].currentSpot)
                         {
                             [self setLegendHidden:[[NSUserDefaults standardUserDefaults] boolForKey:SPMDefaultsLegendHidden]
                                       temporarily:YES];
                         }
                         else
                         {
                             // willShowForFeature should call this, but just in case call it again now that we are finished loading
                             [self setLegendHidden:YES
                                       temporarily:YES];
                         }
                     }
                     completion:^(BOOL finished) {
                         [self updateLegendTableViewBounce];
                     }];
}

#pragma mark - Neighborhood

- (NeighborhoodDataSource *)neighborhoodDataSource
{
    if (!_neighborhoodDataSource)
    {
        _neighborhoodDataSource = [[NeighborhoodDataSource alloc] init];
    }

    return _neighborhoodDataSource;
}

#pragma mark - Legend Table View

- (void)reloadLegendTableView
{
    [self.legendTableView reloadData];

    [self updateLegendTableViewBounce];
}

- (void)updateLegendTableViewBounce
{
    if (self.legendTableView.contentSize.height > CGRectGetHeight(self.legendTableView.bounds))
    {
        self.legendTableView.bounces = YES;
        self.legendTableView.alwaysBounceVertical = YES;
    }
    else
    {
        self.legendTableView.bounces = NO;
        self.legendTableView.alwaysBounceVertical = NO;
    }
}

#pragma mark - UINavigationControllerDelegate

- (UIInterfaceOrientationMask)navigationControllerSupportedInterfaceOrientations:(UINavigationController *)navigationController
{
    return [navigationController viewControllers][0].supportedInterfaceOrientations;
}

@end
