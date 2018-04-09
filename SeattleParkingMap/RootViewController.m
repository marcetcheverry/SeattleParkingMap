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

#import "SettingsTableViewController.h"
#import "TimeLimitViewController.h"

#import "ParkingSpotCalloutView.h"

//#import "SPMMapActivityProvider.h"

static void *RootViewControllerContext = &RootViewControllerContext;

// Street
#define kMapTiledRoadURL @"http://gisrevprxy.seattle.gov/ArcGIS/rest/services/ext/SP_CityBM_Roads/MapServer/"
// Aerial
#define kMapTiledAerialURL @"http://gisrevprxy.seattle.gov/ArcGIS/rest/services/ext/SP_CityBM_Ortho_2009/MapServer/"
// Street Names
#define kMapTiledLabelsURL @"http://gisrevprxy.seattle.gov/ArcGIS/rest/services/ext/SP_CityBM_Labels/MapServer/"
// Parking Data
#define kMapDynamicParkingURL @"http://gisrevprxy.seattle.gov/ArcGIS/rest/services/SDOT_EXT/sdot_parking/MapServer/"

// Virtual Earth (looks the same)
//#define kMapVETiledRoadURL @"http://gisrevprxy.seattle.gov/ArcGIS/rest/services/ext/VE_CityBM_Roads/MapServer/"
//#define kMapVETiledLabelsURL @"http://gisrevprxy.seattle.gov/ArcGIS/rest/services/ext/VE_CityBM_Labels/MapServer/"
//#define kMapVETiledAerialURL @"http://gisrevprxy.seattle.gov/ArcGIS/rest/services/ext/VE_CityBM_Orthos/MapServer/"

@interface RootViewController () <AGSMapViewLayerDelegate, AGSCalloutDelegate, AGSLayerCalloutDelegate, AGSLayerDelegate, CLLocationManagerDelegate, TimeLimitViewControllerDelegate, AGSMapServiceInfoDelegate, UITableViewDelegate, UINavigationControllerDelegate> // UISearchBarDelegate

@property (weak, nonatomic) IBOutlet AGSMapView *mapView;
@property (weak, nonatomic) IBOutlet UIButton *legendsButton;
@property (weak, nonatomic) IBOutlet UITableView *legendTableView;
@property (weak, nonatomic) IBOutlet UISegmentedControl *mapSegmentedControl;
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

//@property (nonatomic) UISearchBar *searchBar;
//@property (nonatomic) UIBarButtonItem *savedLeftBarButtonItem;
//@property (nonatomic) UIBarButtonItem *savedRightBarButtonItem;

//@property (nonatomic) CLGeocoder *currentGeocoder;

@property (nonatomic) AGSDynamicMapServiceLayer *dynamicLayer;
@property (nonatomic) AGSGraphicsLayer *parkingSpotGraphicsLayer;
//@property (nonatomic) AGSFeatureLayer *featureLayer;
@property (nonatomic) AGSMapServiceInfo *serviceInfo;

// For Aerial status bar overlay
@property (nonatomic) CAGradientLayer *gradientLayer;

@property (nonatomic) SPMMapProvider currentMapProvider;
@property (nonatomic) BOOL renderMapsAtNativeResolution;
@property (nonatomic) BOOL needsMapRefreshOnAppearance;

@property (nonatomic) CLLocationManager *locationManager;
@property (nonatomic) UIAlertController *timeLimitAlertController;

@property (nonatomic) BOOL isObservingLocationUpdates;
@property (nonatomic) BOOL needsToSetParkingSpotOnLoad;
@property (nonatomic) BOOL loadedAllMapLayers;

@property (strong, nonatomic) IBOutlet LegendDataSource *legendDataSource;

//@property (nonatomic) AGSQuery *currentQuery;
//@property (nonatomic) AGSQueryTask *currentQueryTask;

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

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.legendTableView.estimatedRowHeight = 17;
    self.legendTableView.rowHeight = UITableViewAutomaticDimension;

    //    self.mapView.touchDelegate = self;
    self.mapView.showMagnifierOnTapAndHold = YES;
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

    self.mapSegmentedControl.layer.shadowColor = [UIColor blackColor].CGColor;
    self.mapSegmentedControl.layer.shadowRadius = 5;
    self.mapSegmentedControl.layer.shadowOpacity = .5;
    self.mapSegmentedControl.layer.shadowOffset = CGSizeZero;
    self.mapSegmentedControl.layer.masksToBounds = NO;
    self.mapSegmentedControl.clipsToBounds = NO;

    //#define DEGREES_TO_RADIANS(x) (M_PI * (x) / 180.0)
    //    self.searchButton.layer.transform = CATransform3DMakeRotation(DEGREES_TO_RADIANS(45), 0, 0, 1);
    //    self.searchButton.titleLabel.transform = CGAffineTransformMakeRotation(DEGREES_TO_RADIANS(45));

    // Set up the map
    self.mapView.allowRotationByPinching = YES;
    self.mapView.layerDelegate = self;

    SPMMapType selectedMapType = [[NSUserDefaults standardUserDefaults] integerForKey:SPMDefaultsSelectedMapType];
    self.mapSegmentedControl.selectedSegmentIndex = selectedMapType;

    if ([UIApplication sharedApplication].applicationState != UIApplicationStateBackground)
    {
        [self loadMapView];
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
        case SPMMapProviderOpenStreetMap:
            mapProviderName = @"OSM";
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

    [Flurry logEvent:@"Map_viewDidAppear"
      withParameters:@{SPMDefaultsLegendHidden: [[NSUserDefaults standardUserDefaults] objectForKey:SPMDefaultsLegendHidden],
                       SPMDefaultsSelectedMapProvider: mapProviderName,
                       SPMDefaultsSelectedMapType: mapTypeName,
                       @"SPMDefaultsHasStoredParkingPoint": @([ParkingManager sharedManager].currentSpot != nil),
                       SPMDefaultsRenderMapsAtNativeResolution: @([[NSUserDefaults standardUserDefaults] boolForKey:SPMDefaultsRenderMapsAtNativeResolution]),
                       SPMDefaultsLegendOpacity: [[NSUserDefaults standardUserDefaults] objectForKey:SPMDefaultsLegendOpacity],
                       @"watchAppInstalled": @(watchAppInstalled),
                       @"watchAppReachable": @(watchAppReachable)
                       }];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    self.gradientLayer.frame = CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), self.topLayoutGuide.length * 1.25);
    [self updateLegendTableViewBounce];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll; // rotate upside down on the iPhone for car users
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    if (self.mapSegmentedControl.selectedSegmentIndex == SPMMapTypeAerial)
    {
        return UIStatusBarStyleLightContent;
    }

    return UIStatusBarStyleDefault;
}

#pragma mark - Notifications

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
    // Try Again
    if (!self.mapView.loaded)
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
            [self centerOnCurrentLocation];
        }

        // For the background location alert
        [self presentInitialAlertsIfNeededWithCompletion:nil];
    }
}

- (void)userDefaultsChanged:(NSNotification *)notification
{
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
    if (context == RootViewControllerContext)
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
            if (self.needsToSetParkingSpotOnLoad)
            {
                if ([keyPath isEqualToString:@"locationDisplay.location"])
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (self.mapView.locationDisplay.location)
                        {
                            NSLog(@"Found current location, will stop observing for location updates");
                            [self setParkingSpotInCurrentLocationFromSource:SPMParkingSpotActionSourceQuickAction
                                                                      error:nil];
                            [self stopObservingLocationUpdates];
                            self.needsToSetParkingSpotOnLoad = NO;
                        }
                    });
                }
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
                mapLayer = [[AGSTiledMapServiceLayer alloc] initWithURL:[NSURL URLWithString:kMapTiledAerialURL]];
                mapLayer.renderNativeResolution = self.renderMapsAtNativeResolution;
                mapLayer.delegate = self;
            }
            else
            {
                // Street is the default
                mapLayer = [[AGSTiledMapServiceLayer alloc] initWithURL:[NSURL URLWithString:kMapTiledRoadURL]];
                mapLayer.renderNativeResolution = self.renderMapsAtNativeResolution;
                mapLayer.delegate = self;
            }
            break;
        }

        case SPMMapProviderOpenStreetMap:
        {
            if (mapType == SPMMapTypeAerial)
            {
                // Aerial
                mapLayer = [[AGSTiledMapServiceLayer alloc] initWithURL:[NSURL URLWithString:kMapTiledAerialURL]];
                mapLayer.renderNativeResolution = self.renderMapsAtNativeResolution;
                mapLayer.delegate = self;
            }
            else
            {
                // Street is the default
                mapLayer = [AGSOpenStreetMapLayer openStreetMapLayer];
                mapLayer.renderNativeResolution = self.renderMapsAtNativeResolution;
                mapLayer.delegate = self;
            }
            break;
        }
        case SPMMapProviderBing:
        {
            if (mapType == SPMMapTypeAerial)
            {
                // Aerial
                mapLayer = [[AGSBingMapLayer alloc] initWithAppID:SPM_API_KEY_BING_MAPS style:AGSBingMapLayerStyleAerialWithLabels];
                mapLayer.renderNativeResolution = self.renderMapsAtNativeResolution;
                mapLayer.delegate = self;
            }
            else
            {
                // Street is the default
                mapLayer = [[AGSBingMapLayer alloc] initWithAppID:SPM_API_KEY_BING_MAPS style:AGSBingMapLayerStyleRoad];
                mapLayer.renderNativeResolution = self.renderMapsAtNativeResolution;
                mapLayer.delegate = self;
            }
            break;
        }
        default:
            break;
    }

    return mapLayer;
}

- (void)loadMapView
{
    //    for (AGSLayer *layer in self.mapView.mapLayers)
    //    {
    //        [self.mapView removeMapLayer:layer];
    //    }

    [self.mapView reset];

    if (self.mapView.locationDisplay.isDataSourceStarted)
    {
        [self.mapView.locationDisplay stopDataSource];
    }

    self.loadedAllMapLayers = NO;
    // Hide it while loading
    [self.legendsButton setTitle:NSLocalizedString(@"Loading…", nil)
                        forState:UIControlStateNormal];
    self.legendsButton.userInteractionEnabled = NO;
    [self setLegendHidden:YES
              temporarily:YES];

    SPMMapType selectedMapType = [[NSUserDefaults standardUserDefaults] integerForKey:SPMDefaultsSelectedMapType];

    self.currentMapProvider = [[NSUserDefaults standardUserDefaults] integerForKey:SPMDefaultsSelectedMapProvider];

    AGSLayer *layer = [self layerForMapType:selectedMapType];

    if (selectedMapType == SPMMapTypeAerial)
    {
        [self.mapView addMapLayer:layer
                         withName:NSLocalizedString(@"Aerial", nil)];
    }
    else
    {
        [self.mapView addMapLayer:layer
                         withName:NSLocalizedString(@"Street", nil)];
    }

    // Add street labels when needed
    if (self.currentMapProvider == SPMMapProviderSDOT ||
        (self.currentMapProvider == SPMMapProviderOpenStreetMap && selectedMapType == SPMMapTypeAerial))
    {
        // Street Labels
        AGSTiledMapServiceLayer *tiledLayerLabels = [[AGSTiledMapServiceLayer alloc] initWithURL:[NSURL URLWithString:kMapTiledLabelsURL]];
        tiledLayerLabels.renderNativeResolution = NO; // self.renderLabelsAtNativeResolution;
        tiledLayerLabels.delegate = self;
        [self.mapView addMapLayer:tiledLayerLabels
                         withName:NSLocalizedString(@"Labels", nil)];
    }

    // Add parking data

    self.dynamicLayer = [[AGSDynamicMapServiceLayer alloc] initWithURL:[NSURL URLWithString:kMapDynamicParkingURL]];
    self.dynamicLayer.renderNativeResolution = self.renderMapsAtNativeResolution;
    self.dynamicLayer.delegate = self;

    // SDOT Web UI Defaults are 1,7,5,6,8,9

    /*
     SDOT Layers:

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

    // WARNING: If you change it here or SDOT changes it, change it in the legend retrieval code
    self.dynamicLayer.visibleLayers = @[@1, @6, @7];
    //    self.dynamicLayer.visibleLayers = @[@1, @7, @5, @6, @8, @9];

    // This is the name that is displayed if there was a property page, tocs, etc...
    [self.mapView addMapLayer:self.dynamicLayer
                     withName:NSLocalizedString(@"Parking", nil)];

    self.dynamicLayer.opacity = [[NSUserDefaults standardUserDefaults] floatForKey:SPMDefaultsLegendOpacity];

    //    self.featureLayer = [[AGSFeatureLayer alloc] initWithURL:[NSURL URLWithString:@"http://gisrevprxy.seattle.gov/ArcGIS/rest/services/SDOT_EXT/sdot_parking/MapServer/4"]
    //                                                        mode:AGSFeatureLayerModeOnDemand];
    //    self.featureLayer.delegate = self;
    //
    //    [self.mapView addMapLayer:self.featureLayer
    //                     withName:@"Features"];

    self.parkingSpotGraphicsLayer = [AGSGraphicsLayer graphicsLayer];
    self.parkingSpotGraphicsLayer.renderNativeResolution = YES;
    self.parkingSpotGraphicsLayer.calloutDelegate = self;
    [self.mapView addMapLayer:self.parkingSpotGraphicsLayer
                     withName:NSLocalizedString(@"Parking Spot", nil)];
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
    else
    {
        BOOL newRenderMapsAtNativeResolution = [[NSUserDefaults standardUserDefaults] boolForKey:SPMDefaultsRenderMapsAtNativeResolution];

        if (self.renderMapsAtNativeResolution != newRenderMapsAtNativeResolution)
        {
            AGSLayer *layer = [self.mapView mapLayerForName:NSLocalizedString(@"Street", nil)];
            if (!layer)
            {
                layer = [self.mapView mapLayerForName:NSLocalizedString(@"Aerial", nil)];
            }

            layer.renderNativeResolution = newRenderMapsAtNativeResolution;
            [layer refresh];

            self.renderMapsAtNativeResolution = newRenderMapsAtNativeResolution;
        }

        // SDOT Labels
        //        if (self.currentMapProvider != SPMMapProviderBing)
        //        {
        //            if (!(self.currentMapProvider == SPMMapProviderOpenStreetMap && self.mapSegmentedControl.selectedSegmentIndex == SPMMapTypeAerial))
        //            {
        //                BOOL newRenderLabelsAtNativeResolution = [[NSUserDefaults standardUserDefaults] boolForKey:SPMDefaultsRenderLabelsAtNativeResolution];
        //
        //                if (self.renderLabelsAtNativeResolution != newRenderLabelsAtNativeResolution)
        //                {
        //                    AGSLayer *layer = [self.mapView mapLayerForName:NSLocalizedString(@"Labels", nil)];
        //                    layer.renderNativeResolution = newRenderMapsAtNativeResolution;
        //                    [layer refresh];
        //
        //                    self.renderLabelsAtNativeResolution = newRenderLabelsAtNativeResolution;
        //                }
        //            }
        //        }
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
}

- (IBAction)unwindFromInformationViewController:(UIStoryboardSegue *)segue
{
}

- (IBAction)unwindFromReminderViewController:(UIStoryboardSegue *)segue
{
}

- (IBAction)mapLayerSegmentedControlValueChanged:(UISegmentedControl *)segmentedControl
{
    AGSLayer *layer = [self layerForMapType:segmentedControl.selectedSegmentIndex];

    if (segmentedControl.selectedSegmentIndex == SPMMapTypeAerial)
    {
        [self.mapView removeMapLayerWithName:NSLocalizedString(@"Street", nil)];
        [self.mapView insertMapLayer:layer
                            withName:NSLocalizedString(@"Aerial", nil)
                             atIndex:0];
    }
    else
    {
        [self.mapView removeMapLayerWithName:NSLocalizedString(@"Aerial", nil)];
        [self.mapView insertMapLayer:layer
                            withName:NSLocalizedString(@"Street", nil)
                             atIndex:0];
    }

    [[NSUserDefaults standardUserDefaults] setInteger:segmentedControl.selectedSegmentIndex
                                               forKey:SPMDefaultsSelectedMapType];

    [UIView animateWithDuration:.3
                     animations:^{
                         [self setNeedsStatusBarAppearanceUpdate];

                         if (self.mapSegmentedControl.selectedSegmentIndex == SPMMapTypeAerial)
                         {
                             self.gradientLayer.opacity = 1;
                         }
                         else
                         {
                             self.gradientLayer.opacity = 0;
                         }
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
    if (self.parkingSpotGraphicsLayer.graphicsCount)
    {
        if ([ParkingManager sharedManager].currentSpot)
        {
            [self centerOnParkingSpot];
            return;
        }
        else
        {
            NSAssert(NO, @"We must have a graphic viisble if we have a parking spot");
        }
    }


    [self setParkingSpotInCurrentLocationFromSource:SPMParkingSpotActionSourceApplication
                                              error:nil];
}

//- (void)fetchFeatures
//{
//    self.currentQueryTask = [AGSQueryTask queryTaskWithURL:[NSURL URLWithString:@"http://gisrevprxy.seattle.gov/ArcGIS/rest/services/SDOT_EXT/sdot_parking/MapServer/4"]];
//    self.currentQuery = [AGSQuery query];
//    self.currentQuery.returnGeometry = YES;
//    self.currentQuery.geometry = self.mapView.visibleAreaEnvelope;
//    self.currentQuery.outFields = @[@"OBJECTID",@"REGIONID",@"WEBNAME",@"DEA_FACILITY_ADDRESS"];
//    self.currentQuery.outSpatialReference = self.mapView.spatialReference;
//    self.currentQueryTask.delegate = self;
//    NSOperation *operation = [self.featureLayer queryFeatures:self.currentQuery];
//}

- (IBAction)opacitySliderChanged:(UISlider *)sender
{
    [[NSUserDefaults standardUserDefaults] setFloat:sender.value forKey:SPMDefaultsLegendOpacity];

    self.dynamicLayer.opacity = sender.value;

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
    [self centerOnCurrentLocation];
}

#pragma mark - Focus Actions

- (void)centerOnParkingSpot
{
    AGSGraphic *parkingGraphic = [self.parkingSpotGraphicsLayer.graphics firstObject];

    [self centerOnParkingGraphic:parkingGraphic
            attemptEnvelopeUnion:YES];
}

// attemptEnvelopeUnion is because we don't have proper heuristics when the current location is next to the parking spot, we will zoom too much.
- (void)centerOnParkingGraphic:(nonnull AGSGraphic *)parkingGraphic
          attemptEnvelopeUnion:(BOOL)attemptEnvelopeUnion
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
        // Try to union both envelopes (current location if it is on the map and the location of the parking spot)
        // Only do it if the current location is in our service area
        if (attemptEnvelopeUnion &&
            self.mapView.locationDisplay.mapLocation &&
            [[self availableMapDataEnvelope] containsPoint:self.mapView.locationDisplay.mapLocation])
        {
            AGSMutableEnvelope *wideEnvelope = [self.mapView.locationDisplay.mapLocation.envelope mutableCopy];
            [wideEnvelope unionWithEnvelope:parkingPoint.envelope];

            if (![self.mapView.visibleAreaEnvelope containsEnvelope:wideEnvelope])
            {
                // Use this API instead of expanding the envelope, otherwise if you are very near the parking spot it will zoom in too much
                [self.mapView zoomToGeometry:wideEnvelope
                                 withPadding:200
                                    animated:YES];
            }
            else
            {
                [self.mapView centerAtPoint:wideEnvelope.center
                                   animated:YES];
            }

            // Expand the envelope so that both points are not at the edges.
            // [wideEnvelope expandByFactor:1.3];
            // [self.mapView zoomToEnvelope:wideEnvelope animated:YES];
        }
        else
        {
            // Otherwise just center at the point if we don't have the current location
            [self.mapView zoomToScale:10000
                      withCenterPoint:parkingPoint
                             animated:YES];
        }

        if (self.mapView.callout.isHidden)
        {
            [self.mapView.callout showCalloutAtPoint:parkingPoint
                                          forFeature:parkingGraphic
                                               layer:self.parkingSpotGraphicsLayer
                                            animated:YES];
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
    [self.mapView zoomToEnvelope:[self SDOTEnvelope]
                        animated:animated];
}

- (void)centerOnCurrentLocation
{
    CLAuthorizationStatus authorizationStatus = [CLLocationManager authorizationStatus];
    if (authorizationStatus != kCLAuthorizationStatusAuthorizedAlways &&
        authorizationStatus != kCLAuthorizationStatusAuthorizedWhenInUse &&
        authorizationStatus != kCLAuthorizationStatusNotDetermined)
    {
        [self presentLocationSettingsAlertForAlwaysAuthorization:NO
                                                      completion:nil];
    }
    else
    {
        if ([[self availableMapDataEnvelope] containsPoint:self.mapView.locationDisplay.mapLocation])
        {
            //    NSLog(@"Current location %@, point %@", self.mapView.locationDisplay.mapLocation, self.mapView.locationDisplay.location.point);
            [self.mapView zoomToScale:4500
                      withCenterPoint:self.mapView.locationDisplay.mapLocation
                             animated:YES];
            //    [self.mapView centerAtPoint:self.mapView.locationDisplay.mapLocation animated:YES];

            // If they had panned, it is automatically off, reset it!
            self.mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeDefault;

            // Restore rotation
            if (self.mapView.rotationAngle != 0)
            {
                [self.mapView setRotationAngle:0
                                      animated:YES];
            }
        }
        else
        {
            // Don't warn them if there is a modal
            if (![self presentedViewController])
            {
                [Flurry logError:@"Location_OutOfArea"
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

            // Attempt to center on something
            if ([ParkingManager sharedManager].currentSpot)
            {
                [self centerOnParkingSpot];
            }
            else
            {
                [self centerOnSDOTEnvelopeAnimated:YES];
            }
        }
    }
}

#pragma mark - Parking Spot

/// Returns current parking spot object or nil
- (AGSGeometry *)currentParkingSpot
{
    if (self.parkingSpotGraphicsLayer.graphicsCount)
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

    AGSPoint *parkingPoint = self.mapView.locationDisplay.mapLocation;

    if ([[self availableMapDataEnvelope] containsPoint:parkingPoint])
    {
        if (source == SPMParkingSpotActionSourceWatch)
        {
            [Flurry logEvent:@"ParkingSpot_SetFromWatch_Success"];
        }
        else if (source == SPMParkingSpotActionSourceQuickAction)
        {
            [Flurry logEvent:@"ParkingSpot_SetFromQuickAction_Success"];
        }
        else
        {
            [Flurry logEvent:@"ParkingSpot_Set_Success"];
        }

        parkingPoint = [AGSPoint pointWithX:parkingPoint.x
                                          y:parkingPoint.y
                           spatialReference:self.mapView.spatialReference];

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
            if ([WCSession isSupported] && [WCSession defaultSession].isReachable)
            {
                NSDictionary *watchSpot = [[ParkingManager sharedManager].currentSpot watchConnectivityDictionaryRepresentation];

                NSDictionary *message = @{SPMWatchAction: SPMWatchActionSetParkingSpot,
                                          SPMWatchResponseStatus: SPMWatchResponseSuccess,
                                          SPMWatchObjectParkingSpot: watchSpot};
                [[WCSession defaultSession] sendMessage:message
                                           replyHandler:nil
                                           errorHandler:^(NSError * _Nonnull sessionError) {
                                               NSLog(@"Could not send message to watch: %@", sessionError);
                                           }];
            }
        }

        return YES;
    }
    else
    {
        // We need to attempt to set it
        if (source == SPMParkingSpotActionSourceQuickAction)
        {
            NSLog(@"Could not find current location, will begin observing for location updates");
            self.needsToSetParkingSpotOnLoad = YES;
            [self beginObservingLocationUpdates];
            return NO;
        }

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

        [Flurry logError:errorMessage
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
    if (self.parkingSpotGraphicsLayer.graphicsCount)
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

    if (![parkingPoint.spatialReference isEqualToSpatialReference:self.mapView.spatialReference])
    {
        parkingPoint = (AGSPoint *)[[AGSGeometryEngine defaultGeometryEngine] projectGeometry:parkingPoint
                                                                           toSpatialReference:self.mapView.spatialReference];
    }

    if ([[self availableMapDataEnvelope] containsPoint:parkingPoint])
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
        [Flurry logError:@"ParkingSpot_Restore_Failure"
                 message:@"Outside of service area"
                   error:nil];

        [ParkingManager sharedManager].currentSpot = nil;

        if ([WCSession isSupported] && [WCSession defaultSession].isReachable)
        {
            [[WCSession defaultSession] sendMessage:@{SPMWatchAction: SPMWatchActionRemoveParkingSpot,
                                                      SPMWatchResponseStatus: SPMWatchResponseSuccess}
                                       replyHandler:nil
                                       errorHandler:^(NSError * _Nonnull error) {
                                           NSLog(@"Could not send message to watch: %@", error);
                                       }];
        }
    }
}

- (void)addAndShowParkingSpotMarkerWithPoint:(nonnull AGSPoint *)parkingPoint
                                        date:(nullable NSDate *)date
{
    NSAssert(parkingPoint != nil, @"Must have a parking point");
    if (!parkingPoint)
    {
        return;
    }

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

    AGSPictureMarkerSymbol *pictureSymbol = [AGSPictureMarkerSymbol pictureMarkerSymbolWithImageNamed:@"Car"];
    pictureSymbol.size = CGSizeMake(40, 40);

    //    AGSTextSymbol *textSymbol = [AGSTextSymbol textSymbolWithText:@"🚗" color:[UIColor redColor]];
    //    textSymbol.fontFamily = @"Apple Color Emoji";
    //    textSymbol.fontSize = 40;

    AGSGraphic *parkingGraphic = [AGSGraphic graphicWithGeometry:parkingPoint
                                                          symbol:pictureSymbol
                                                      attributes:@{@"title": NSLocalizedString(@"Parked Here", nil), @"date" : dateString}];

    [self.parkingSpotGraphicsLayer addGraphic:parkingGraphic];

    [self centerOnParkingGraphic:parkingGraphic
            attemptEnvelopeUnion:NO];

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

        [Flurry logEvent:@"ParkingTimeLimit_Set_Success"
          withParameters:@{@"length": timeLimit.length,
                           @"reminderThreshold": timeLimit.reminderThreshold}];

        if ([WCSession isSupported] && [WCSession defaultSession].isReachable)
        {
            [[WCSession defaultSession] sendMessage:@{SPMWatchAction: SPMWatchActionSetParkingTimeLimit,
                                                      SPMWatchResponseStatus: SPMWatchResponseSuccess,
                                                      SPMWatchObjectParkingTimeLimit: [timeLimit watchConnectivityDictionaryRepresentation]}
                                       replyHandler:nil
                                       errorHandler:^(NSError * _Nonnull error) {
                                           NSLog(@"Could not send message to watch: %@", error);
                                       }];
        }
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
        self.mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeDefault;
    }

    //    self.mapView.locationDisplay.wanderExtentFactor = 1;

    //    self.mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeCompassNavigation;
    self.mapView.locationDisplay.showsPing = YES;

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

    [self.mapView.locationDisplay startDataSource];
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
        [self.mapView.locationDisplay startDataSource];
        self.locationManager.delegate = nil;
        self.locationManager = nil;
    }
}

#pragma mark - AGSLayerDelegate

- (void)layerDidLoad:(AGSLayer *)layer
{
    SPMLog(@"Loaded layer %@", layer.name);

    if (!self.loadedAllMapLayers)
    {
        BOOL allLayersLoaded = YES;
        for (AGSLayer *mapLayer in self.mapView.mapLayers)
        {
            //        NSLog(@"Checking %@ is loaded %i", layer.name, [layer loaded]);
            if (!mapLayer.loaded)
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

            if (!self.legendsButton.userInteractionEnabled)
            {
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
        }
    }

    // Fetch Legend
    if (layer == self.dynamicLayer)
    {
        self.dynamicLayer.mapServiceInfo.delegate = self;
        [self.dynamicLayer.mapServiceInfo retrieveLegendInfo];
    }
}

- (void)layer:(AGSLayer *)layer didFailToLoadWithError:(NSError *)error
{
    NSLog(@"Failed to load layer %@\n%@", layer.name, error);

    NSString *errorTitle;

    if ([[NSUserDefaults standardUserDefaults] integerForKey:SPMDefaultsSelectedMapProvider] == SPMMapProviderSDOT)
    {
        errorTitle = [NSString stringWithFormat:NSLocalizedString(@"Could not Load SDOT Data for %@ Map", nil),
                      layer.name];
    }
    else
    {
        errorTitle = [NSString stringWithFormat:NSLocalizedString(@"Could not Load %@ Map", nil),
                      layer.name];
    }

    UIAlertController *controller = [UIAlertController alertControllerWithTitle:errorTitle
                                                                        message:[error localizedFailureReason]
                                                                 preferredStyle:UIAlertControllerStyleAlert];
    [controller addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Try Again", nil)
                                                   style:UIAlertActionStyleCancel
                                                 handler:^(UIAlertAction * _Nonnull action) {
                                                     if ([layer respondsToSelector:@selector(resubmit)])
                                                     {
                                                         [layer performSelector:@selector(resubmit)];
                                                     }
                                                 }]];

    [self SPMPresentAlertController:controller
                           animated:YES
                         completion:nil];

    [Flurry logError:@"Map_LayerFailedToLoad"
             message:errorTitle
               error:error];
}

#pragma mark - AGSCalloutDelegate

- (void)calloutDidDismiss:(AGSCallout *)callout
{
    [self.legendSlider setValue:[[NSUserDefaults standardUserDefaults] floatForKey:SPMDefaultsLegendOpacity]
                       animated:YES];

    [UIView animateWithDuration:.3
                     animations:^{
                         self.dynamicLayer.opacity = self.legendSlider.value;
                         [self setLegendHidden:[[NSUserDefaults standardUserDefaults] boolForKey:SPMDefaultsLegendHidden]];
                     }
                     completion:^(BOOL finished) {
                         [self updateLegendTableViewBounce];
                     }];
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
            [Flurry logEvent:@"ParkingSpot_Remove"];
            break;
        case SPMParkingSpotActionSourceWatch:
            [Flurry logEvent:@"ParkingSpot_RemoveFromWatch"];
            break;
        case SPMParkingSpotActionSourceNotification:
            [Flurry logEvent:@"ParkingSpot_RemoveFromNotification"];
            break;
        case SPMParkingSpotActionSourceQuickAction:
            [Flurry logEvent:@"ParkingSpot_RemoveFromQuickAction"];
            break;

        default:
            break;
    }

    // Happens when removing parking spot with hidden callout

    AGSGraphicsLayer *layer = (AGSGraphicsLayer *)callout.representedLayer;
    AGSGraphic *feature = (AGSGraphic *)callout.representedFeature;

    if (!layer || !feature)
    {
        NSAssert([self.parkingSpotGraphicsLayer.graphics count] > 0, @"We must have a graphic!");
        [self.parkingSpotGraphicsLayer removeGraphics:self.parkingSpotGraphicsLayer.graphics];
    }
    else
    {
        [layer removeGraphic:feature];
    }

    [ParkingManager sharedManager].currentSpot = nil;

    if (source != SPMParkingSpotActionSourceWatch)
    {
        if ([WCSession isSupported] && [WCSession defaultSession].isReachable)
        {
            [[WCSession defaultSession] sendMessage:@{SPMWatchAction: SPMWatchActionRemoveParkingSpot,
                                                      SPMWatchResponseStatus: SPMWatchResponseSuccess}
                                       replyHandler:nil
                                       errorHandler:^(NSError * _Nonnull error) {
                                           NSLog(@"Could not send message to watch: %@", error);
                                       }];
        }
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
                        self.mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeDefault;
                    }];
}

#pragma mark - AGSLayerCalloutDelegate

- (BOOL)callout:(AGSCallout *)callout willShowForFeature:(id <AGSFeature>)feature layer:(AGSLayer <AGSHitTestable> *)layer mapPoint:(AGSPoint *)mapPoint
{
    // At this point the user does not care anymore about the legend or overlays, just getting there.
    [self.legendSlider setValue:0
                       animated:YES];

    [UIView animateWithDuration:.3
                     animations:^{
                         self.dynamicLayer.opacity = 0;
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
                    [Flurry logEvent:@"ParkingTimeLimit_Remove"];
                    [ParkingManager sharedManager].currentSpot.timeLimit = nil;
                    self.timeLimitAlertController = nil;

                    if ([WCSession isSupported] && [WCSession defaultSession].isReachable)
                    {
                        NSDictionary *message = @{SPMWatchAction: SPMWatchActionRemoveParkingTimeLimit,
                                                  SPMWatchResponseStatus: SPMWatchResponseSuccess};
                        [[WCSession defaultSession] sendMessage:message
                                                   replyHandler:nil
                                                   errorHandler:^(NSError * _Nonnull error) {
                                                       NSLog(@"Could not send message to watch: %@", error);
                                                   }];
                    }
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
                                                                                      style:UIAlertActionStyleCancel
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

            [controller addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Other", nil)
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
            [self didClickAccessoryButtonForCallout:callout];
        };

        callout.clipsToBounds = YES;
        callout.margin = CGSizeZero;
        callout.cornerRadius = 5;
        callout.color = [UIColor colorWithWhite:0 alpha:.8];
        callout.customView = calloutView;
        callout.delegate = self;
    }
    else
    {
        // Legacy callout from the old codebase
        callout.accessoryButtonType = UIButtonTypeCustom;
        callout.accessoryButtonImage = [UIImage imageNamed:@"Close"];
        callout.delegate = self;
        callout.color = [UIColor colorWithWhite:0 alpha:.8];
        //    callout.borderColor = [UIColor colorWithWhite:1 alpha:.5];
        //    callout.borderWidth = 2;
        callout.titleColor = [UIColor whiteColor];
        callout.detailColor = [UIColor whiteColor];

        callout.title = (NSString *)[feature attributeForKey:@"title"];
        callout.detail = (NSString *)[feature attributeForKey:@"date"];
    }

    return YES;
}

/// Where parking data is available
- (AGSEnvelope *)SDOTEnvelope
{
    // This was obtained by zooming out to the limits of the city of Seattle and inspecting the ArcGIS map view's properties.
    // NAD_1983_HARN_StatePlane_Washington_North_FIPS_4601_Feet
    AGSSpatialReference *reference = [AGSSpatialReference spatialReferenceWithWKID:SPMSpatialReferenceWKIDSDOT];
    AGSEnvelope *envelope = [AGSEnvelope envelopeWithXmin:1236463.072915
                                                     ymin:183835.269949
                                                     xmax:1303549.175423
                                                     ymax:273283.406628
                                         spatialReference:reference];
    return envelope;
}

#pragma mark - AGSMapViewLayerDelegate

/// Essentially the state of WA, where there is data, you can still set a parking spot there
- (AGSEnvelope *)availableMapDataEnvelope
{
    return self.mapView.maxEnvelope;
}

- (void)mapViewDidLoad:(AGSMapView *)mapView
{
    self.locationButton.layer.borderColor = [UIColor whiteColor].CGColor;
    self.parkingButton.layer.borderColor = [UIColor whiteColor].CGColor;
    self.mapSegmentedControl.enabled = YES;
    self.locationButton.enabled = YES;
    self.parkingButton.enabled = YES;
    self.legendSlider.enabled = YES;

    if ([ParkingManager sharedManager].currentSpot)
    {
        [self restoreParkingSpotMarker];
    }
    else
    {
        [self centerOnSDOTEnvelopeAnimated:NO];
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
    // Official SDOT Wording: There may be a time lag between sign installation and record data entry; consequently, the map may not reflect on- the-ground reality. Always comply with city parking rules and regulations
    UIAlertController *controller = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Warning", nil)
                                                                        message:NSLocalizedString(@"The map may not always reflect the on-the-ground reality since there might be a delay between on-street changes and the data being entered into the system.\n\nAlways double check before parking and comply with city parking rules and regulations posted on the street.", nil)
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
                                                               [[UIApplication sharedApplication] openURL:settingsURL];
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
        [Flurry logError:@"Location_Disabled_Always"
                 message:@"User has disabled background location"
                   error:nil];
    }
    else
    {
        [Flurry logError:@"Location_Disabled"
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

#pragma mark - AGSMapServiceInfoDelegate

- (void)mapServiceInfo:(AGSMapServiceInfo *)mapServiceInfo operationDidRetrieveLegendInfo:(NSOperation *)op
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        for (AGSMapServiceLayerInfo *layerInfo in mapServiceInfo.layerInfos)
        {
            if (layerInfo.layerId == 6 ||
                layerInfo.layerId == 7)
            {
                //            NSLog(@"Found legend %@", layerInfo);
                // Not a fan of how ArcGIS structured the legends here without giving them their own object.
                // Just to be safe, double check the count
                NSUInteger labelCount = [layerInfo.legendLabels count];
                NSUInteger imageCount = [layerInfo.legendImages count];
                for (NSUInteger i = 0; i < labelCount; i++)
                {
                    Legend *legend = [[Legend alloc] init];
                    legend.name = layerInfo.legendLabels[i];

                    // Hapens for "Temporary No Parking"
                    if (![legend.name length])
                    {
                        legend.name = layerInfo.name;
                    }

                    if (i < imageCount)
                    {
                        legend.image = layerInfo.legendImages[i];
                    }

                    legend.index = i;

                    [self.legendDataSource addLegend:legend];
                    //                    NSLog(@"Added legend: %@", legend);
                }
            }

        }

        // For testing SDOT changes
        //        for (NSUInteger i = 0; i < 5; i++)
        //        {
        //            Legend *legend = [[Legend alloc] init];
        //            legend.name = [NSString stringWithFormat:@"Testing %ld", (long)i];
        //            [self.legendDataSource addLegend:legend];
        //        }

        [self.legendDataSource sortLegends];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self reloadLegendTableView];
        });
    });
}

- (void)mapServiceInfo:(AGSMapServiceInfo *)mapServiceInfo operation:(NSOperation *)op didFailToRetrieveLegendInfoWithError:(NSError *)error
{
    NSLog(@"Failed to load legend info with error %@", error);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [self.legendDataSource synthesizeDefaultLegends];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self reloadLegendTableView];
        });
    });
}

#pragma mark - Legend Table View

- (void)reloadLegendTableView
{
    [self.legendTableView reloadData];

    // Little auto layout bug in iOS 8
    // https://github.com/smileyborg/TableViewCellWithAutoLayoutiOS8/issues/10
    NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
    if (version.majorVersion == 8)
    {
        [self.legendTableView setNeedsLayout];
        [self.legendTableView layoutIfNeeded];
        [self.legendTableView reloadData];
    }

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

//#pragma mark - UISearchBarDelegate
//
//- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
//{
//    self.savedLeftBarButtonItem = self.navigationItem.leftBarButtonItem;
//    self.savedRightBarButtonItem = self.navigationItem.rightBarButtonItem;
//
//    [self.navigationItem setLeftBarButtonItem:nil animated:YES];
//    [self.navigationItem setRightBarButtonItem:nil animated:YES];
//    [self.searchBar setShowsCancelButton:YES animated:YES];
//}
//
//- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
//{
//    [self dismissSearchBar];
//}
//
//- (void)dismissSearchBar
//{
//    [self.navigationItem setLeftBarButtonItem:self.savedLeftBarButtonItem animated:YES];
//    [self.navigationItem setRightBarButtonItem:self.savedRightBarButtonItem animated:YES];
//    [self.searchBar resignFirstResponder];
//    [self.searchBar setShowsCancelButton:NO animated:YES];
//}
//
//- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
//{
//    if (!self.currentGeocoder)
//    {
//        CLCircularRegion *seattleCircularRegion = [[CLCircularRegion alloc] initWithCenter:CLLocationCoordinate2DMake(47.649167, -122.347687)
//                                                                                    radius:16000
//                                                                                identifier:@"Seattle City Limits"];
//        self.currentGeocoder = [[CLGeocoder alloc] init];
//        [self.currentGeocoder geocodeAddressString:searchBar.text inRegion:seattleCircularRegion completionHandler:^(NSArray *placemarks, NSError *error) {
//            if (!error)
//            {
//                NSLog(@"Found placemarks %@", placemarks);
//                if ([placemarks count])
//                {
//                    CLPlacemark *firstPlacemark = placemarks[0];
//                    CLLocation *location = firstPlacemark.location;
////                    AGSPoint *gpsPoint = [[AGSPoint alloc] initWithX:firstPlacemark.location.coordinate.longitude
////                                                                   y:firstPlacemark.location.coordinate.latitude
////                                                    spatialReference:[AGSSpatialReference wgs84SpatialReference]];
//
//                    AGSPoint *gpsPoint = [AGSPoint pointWithLocation:location];
//
//                    AGSGeometryEngine *engine = [AGSGeometryEngine defaultGeometryEngine];
//
//                    // convert CL coordinates to the map's spatial reference
//                    AGSPoint *mapPoint = (AGSPoint *)[engine projectGeometry:gpsPoint
//                                                          toSpatialReference:self.mapView.spatialReference];
////                    [self.mapView centerAtPoint:mapPoint animated:YES];
//                    [self.mapView zoomToScale:10000 withCenterPoint:mapPoint animated:YES];
//
//                    // TODO Add call out, zoom, listed placemarks.
//                    [self dismissSearchBar];
//                }
//            }
//            else
//            {
//                NSLog(@"Error %@", error);
//            }
//
//            self.currentGeocoder = nil;
//        }];
//    }
//}

//- (IBAction)shareTouched:(UIButton *)sender
//{
//    [self shareTab];
//    return;

//    NSString *text = @"Here is my location";
//
//    if ([self currentParkingSpot])
//    {
//
//    }
//    // if parking spot
//    // if current location
//    // check oput parkign
//
//    SPMMapActivityProvider *mapActivityItemProvider = [[SPMMapActivityProvider alloc] initWithPlaceholderItem:[UIImage imageNamed:@"Search"]];
//    mapActivityItemProvider.screenshotView = self.mapView;
//
//    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[mapActivityItemProvider] applicationActivities:nil];
//    [self presentViewController:activityVC animated:YES completion:nil];
//}

//- (void)shareTab
//{
//    CLLocation *geoPoint = ((AGSCLLocationManagerLocationDisplayDataSource *)self.mapView.locationDisplay.dataSource).locationManager.location;
//
//    CLLocation *userLocation = geoPoint;
//    CLGeocoder *geocoder;
//    geocoder = [[CLGeocoder alloc]init];
//
//    [geocoder reverseGeocodeLocation:userLocation completionHandler:^(NSArray *placemarks, NSError *error)
//    {
////        CLPlacemark *evolvedPlacemark = placemarks[0];
//        MKPlacemark *evolvedPlacemark = [[MKPlacemark alloc]initWithPlacemark:placemarks[0]];
//
//        ABRecordRef persona = ABPersonCreate();
//        ABRecordSetValue(persona, kABPersonFirstNameProperty, (__bridge CFTypeRef)(evolvedPlacemark.name), nil);
//        ABMutableMultiValueRef multiHome = ABMultiValueCreateMutable(kABMultiDictionaryPropertyType);
//
//        bool didAddHome = ABMultiValueAddValueAndLabel(multiHome, (__bridge CFTypeRef)(evolvedPlacemark.addressDictionary), kABHomeLabel, NULL);
//
//        if(didAddHome)
//        {
//            ABRecordSetValue(persona, kABPersonAddressProperty, multiHome, NULL);
//
//            NSLog(@"Address saved.");
//        }
//
//        NSArray *individual = [[NSArray alloc]initWithObjects:(__bridge id)(persona), nil];
//        CFArrayRef arrayRef = (__bridge CFArrayRef)individual;
//        NSData *vcards = (__bridge NSData *)ABPersonCreateVCardRepresentationWithPeople(arrayRef);
//
//        NSString* vcardString;
//        vcardString = [[NSString alloc] initWithData:vcards encoding:NSASCIIStringEncoding];
//        NSLog(@"%@",vcardString);
//
//
//        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
//        NSString *documentsDirectory = [paths objectAtIndex:0]; // Get documents directory
//
//        NSString *filePath = [documentsDirectory stringByAppendingPathComponent:@"pin.loc.vcf"];
//        [vcardString writeToFile:filePath
//                      atomically:YES encoding:NSUTF8StringEncoding error:&error];
//
//        NSURL *url =  [NSURL fileURLWithPath:filePath];
//        NSLog(@"url> %@ ", [url absoluteString]);
//
//
//        // Share Code //
//        NSArray *itemsToShare = [[NSArray alloc] initWithObjects: url, nil] ;
//        UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:itemsToShare applicationActivities:nil];
//        activityVC.excludedActivityTypes = @[UIActivityTypePrint,
//                                             UIActivityTypeCopyToPasteboard,
//                                             UIActivityTypeAssignToContact,
//                                             UIActivityTypeSaveToCameraRoll,
//                                             UIActivityTypePostToWeibo];
//
//        [self presentViewController:activityVC animated:YES completion:nil];
//
//    }];
//}

//#pragma mark - AGSQueryTaskDelegate
//
//- (void)queryTask:(AGSQueryTask *)queryTask operation:(NSOperation*)op didExecuteWithFeatureSetResult:(AGSFeatureSet *)featureSet
//{
//    NSLog(@"%@", NSStringFromSelector(_cmd));
//}
//
//- (void)queryTask:(AGSQueryTask *)queryTask operation:(NSOperation*)op didFailWithError:(NSError *)error
//{
//    NSLog(@"%@", NSStringFromSelector(_cmd));
//}
//
//- (void)queryTask:(AGSQueryTask *)queryTask operation:(NSOperation*)op didExecuteWithObjectIds:(NSArray *)objectIds
//{
//    NSLog(@"%@", NSStringFromSelector(_cmd));
//}
//
//- (void)queryTask:(AGSQueryTask *)queryTask operation:(NSOperation*)op didFailQueryForIdsWithError:(NSError *)error
//{
//    NSLog(@"%@", NSStringFromSelector(_cmd));
//}
//
//- (void)queryTask:(AGSQueryTask *)queryTask operation:(NSOperation*)op didExecuteWithRelatedFeatures:(NSDictionary *)relatedFeatures
//{
//    NSLog(@"%@", NSStringFromSelector(_cmd));
//}
//
//- (void)queryTask:(AGSQueryTask *)queryTask operation:(NSOperation*)op didFailRelationshipQueryWithError:(NSError *)error
//{
//    NSLog(@"%@", NSStringFromSelector(_cmd));
//}
//
//- (void)queryTask:(AGSQueryTask *)queryTask operation:(NSOperation*)op didExecuteWithFeatureCount:(NSInteger)count
//{
//    NSLog(@"%@", NSStringFromSelector(_cmd));
//}
//
//- (void)queryTask:(AGSQueryTask *)queryTask operation:(NSOperation*)op didFailQueryFeatureCountWithError:(NSError*)error
//{
//    NSLog(@"%@", NSStringFromSelector(_cmd));
//}

@end
