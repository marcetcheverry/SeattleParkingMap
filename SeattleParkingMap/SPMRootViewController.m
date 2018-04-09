//
//  SPMRootViewController.m
//  Seattle Parking Map
//
//  Created by Marc on 6/5/14.
//  Copyright (c) 2014 Tap Light Software. All rights reserved.
//

#import "SPMRootViewController.h"

//@import MapKit;
//@import AddressBook;

#import "SPMInformationTableViewController.h"
//#import "SPMMapActivityProvider.h"

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

@interface SPMRootViewController () <AGSMapViewLayerDelegate, AGSCalloutDelegate, AGSLayerCalloutDelegate, UIAlertViewDelegate, AGSLayerDelegate> // UISearchBarDelegate, AGSMapServiceInfoDelegate

@property (weak, nonatomic) IBOutlet AGSMapView *mapView;
@property (weak, nonatomic) IBOutlet UIImageView *legendsImageView;
@property (weak, nonatomic) IBOutlet UIButton *legendsButton;
@property (weak, nonatomic) IBOutlet UISegmentedControl *mapSegmentedControl;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *legendsContainerHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *legendContainerWidthConstraint;

@property (weak, nonatomic) IBOutlet UIButton *parkingButton;
@property (weak, nonatomic) IBOutlet UIButton *locationButton;
@property (weak, nonatomic) IBOutlet UIButton *infoButton;
@property (weak, nonatomic) IBOutlet UIView *legendContainerView;
//@property (weak, nonatomic) IBOutlet UIButton *searchButton;
@property (weak, nonatomic) IBOutlet UISlider *legendSlider;

@property (strong, nonatomic) IBOutletCollection(UIView) NSArray *borderedViews;

//@property (nonatomic) UISearchBar *searchBar;
//@property (nonatomic) UIBarButtonItem *savedLeftBarButtonItem;
//@property (nonatomic) UIBarButtonItem *savedRightBarButtonItem;

//@property (nonatomic) CLGeocoder *currentGeocoder;

@property (nonatomic) AGSDynamicMapServiceLayer *dynamicLayer;
//@property (nonatomic) AGSOpenStreetMapLayer *osmLayer;
@property (nonatomic) AGSGraphicsLayer *parkingSpotGraphicsLayer;
@property (nonatomic) AGSMapServiceInfo *serviceInfo;

// For Aerial status bar overlay
@property (nonatomic) CAGradientLayer *gradientLayer;

@property (nonatomic) SPMMapProvider currentMapProvider;
@property (nonatomic) BOOL renderMapsAtNativeResolution;
@property (nonatomic) BOOL needsMapRefreshOnAppearance;

@end

@implementation SPMRootViewController

- (void)dealloc
{
//    self.searchBar.delegate = nil;

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationWillEnterForegroundNotification
                                                  object:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSUserDefaultsDidChangeNotification
                                                  object:nil];
}

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
    // Try Again
    if (!self.mapView.loaded)
    {
        [self loadMapView];
    }
    else
    {
        [self centerOnCurrentLocation];
    }
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll; // rotate upside down on the iPhone for car users
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    self.gradientLayer.frame = CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), self.topLayoutGuide.length * 1.25);
}

- (void)viewDidLoad
{
    [super viewDidLoad];

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
    [self setLegendHidden:[[NSUserDefaults standardUserDefaults] boolForKey:SPMDefaultsLegendHidden]];

    UIColor *colorOne = [UIColor colorWithWhite:0 alpha:.6];
    UIColor *colorTwo = [UIColor colorWithWhite:0 alpha:.3];
    UIColor *colorThree = [UIColor clearColor];

    self.gradientLayer = [CAGradientLayer layer];
    self.gradientLayer.colors = @[(id)colorOne.CGColor, (id)colorTwo.CGColor, (id)colorThree.CGColor];
    self.gradientLayer.locations = @[@0.25, @0.5, @1];
    self.gradientLayer.opacity = 0;
    [self.view.layer addSublayer:self.gradientLayer];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(userDefaultsChanged:)
                                                 name:NSUserDefaultsDidChangeNotification
                                               object:nil];

    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                    action:@selector(legendsImageViewTapped)];
    [self.legendsImageView addGestureRecognizer:tapRecognizer];

#if TARGET_IPHONE_SIMULATOR
    UITapGestureRecognizer *screenshotTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                           action:@selector(screenshotLaunchImage)];
    screenshotTapRecognizer.numberOfTapsRequired = 2;
    [self.legendSlider addGestureRecognizer:screenshotTapRecognizer];
#endif

//    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
//    self.searchBar.delegate = self;
//    self.searchBar.placeholder = NSLocalizedString(@"Search", nil);
//    self.navigationItem.titleView = self.searchBar;

//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
//        NSError *serviceInfoError;
//        self.serviceInfo = [[AGSMapServiceInfo alloc] initWithURL:[NSURL URLWithString:kMapDynamicParkingURL] error:&serviceInfoError];
//
//        if (serviceInfoError)
//        {
//            NSLog(@"Failed to load info %@", serviceInfoError);
//        }
//        else
//        {
//            self.serviceInfo.delegate = self;
//            [self.serviceInfo retrieveLegendInfo];
//        }
//    });
//

    for (UIView *borderedView in self.borderedViews)
    {
        borderedView.layer.borderColor = [UIColor whiteColor].CGColor;
        borderedView.layer.borderWidth = 1;
        
        borderedView.layer.shadowColor = [UIColor blackColor].CGColor;
        borderedView.layer.shadowRadius = 10;
        borderedView.layer.shadowOpacity = .7;
        borderedView.layer.shadowOffset = CGSizeMake(0, 0);
        borderedView.layer.masksToBounds = NO;
        borderedView.clipsToBounds = NO;
        if ([borderedView isKindOfClass:[UIButton class]])
        {
            borderedView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:borderedView.bounds cornerRadius:borderedView.layer.cornerRadius].CGPath;
        }
    }

    // Disabled border for now (can't set it in IB)
    self.locationButton.layer.borderColor = [UIColor colorWithWhite:1 alpha:.5].CGColor;
    self.parkingButton.layer.borderColor = [UIColor colorWithWhite:1 alpha:.5].CGColor;

    self.mapSegmentedControl.layer.shadowColor = [UIColor blackColor].CGColor;
    self.mapSegmentedControl.layer.shadowRadius = 10;
    self.mapSegmentedControl.layer.shadowOpacity = .7;
    self.mapSegmentedControl.layer.shadowOffset = CGSizeMake(0, 0);
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

    [self loadMapView];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    if (self.needsMapRefreshOnAppearance)
    {
        [self refreshMapSettingsIfNeeded];
        self.needsMapRefreshOnAppearance = NO;
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

- (AGSLayer *)layerForMapType:(SPMMapType)mapType
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

    SPMMapType selectedMapType = [[NSUserDefaults standardUserDefaults] integerForKey:SPMDefaultsSelectedMapType];

    self.currentMapProvider = [[NSUserDefaults standardUserDefaults] integerForKey:SPMDefaultsSelectedMapProvider];

    AGSLayer *layer = [self layerForMapType:selectedMapType];

    if (selectedMapType == SPMMapTypeAerial)
    {
        [self.mapView addMapLayer:layer withName:NSLocalizedString(@"Aerial", nil)];
    }
    else
    {
        [self.mapView addMapLayer:layer withName:NSLocalizedString(@"Street", nil)];
    }

    // Add street labels when needed
    if (self.currentMapProvider == SPMMapProviderSDOT ||
        (self.currentMapProvider == SPMMapProviderOpenStreetMap && selectedMapType == SPMMapTypeAerial))
    {
        // Street Labels
        AGSTiledMapServiceLayer *tiledLayerLabels = [[AGSTiledMapServiceLayer alloc] initWithURL:[NSURL URLWithString:kMapTiledLabelsURL]];
        tiledLayerLabels.renderNativeResolution = NO;// self.renderLabelsAtNativeResolution;
        tiledLayerLabels.delegate = self;
        [self.mapView addMapLayer:tiledLayerLabels withName:NSLocalizedString(@"Labels", nil)];
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

    self.dynamicLayer.visibleLayers = @[@1, @6, @7];
    //    self.dynamicLayer.visibleLayers = @[@1, @7, @5, @6, @8, @9];

	// This is the name that is displayed if there was a property page, tocs, etc...
	[self.mapView addMapLayer:self.dynamicLayer withName:NSLocalizedString(@"Parking", nil)];

	self.dynamicLayer.opacity = [[NSUserDefaults standardUserDefaults] floatForKey:SPMDefaultsLegendOpacity];

    self.parkingSpotGraphicsLayer = [AGSGraphicsLayer graphicsLayer];
    self.parkingSpotGraphicsLayer.renderNativeResolution = YES;
    self.parkingSpotGraphicsLayer.calloutDelegate = self;
    [self.mapView addMapLayer:self.parkingSpotGraphicsLayer withName:NSLocalizedString(@"Parking Spot", nil)];
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

    [Flurry logEvent:@"Map_viewDidAppear" withParameters:@{SPMDefaultsLegendHidden: [[NSUserDefaults standardUserDefaults] objectForKey:SPMDefaultsLegendHidden],
                                                           SPMDefaultsSelectedMapProvider: mapProviderName,
                                                           SPMDefaultsSelectedMapType: mapTypeName,
                                                           @"SPMDefaultsHasStoredParkingPoint": @([self hasStoredParkingSpot]),
                                                           SPMDefaultsRenderMapsAtNativeResolution: @([[NSUserDefaults standardUserDefaults] boolForKey:SPMDefaultsRenderMapsAtNativeResolution]),
                                                           SPMDefaultsLegendOpacity: [[NSUserDefaults standardUserDefaults] objectForKey:SPMDefaultsLegendOpacity]}];
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

- (UIStatusBarStyle)preferredStatusBarStyle
{
    if (self.mapSegmentedControl.selectedSegmentIndex == SPMMapTypeAerial)
    {
        return UIStatusBarStyleLightContent;
    }
    
    return UIStatusBarStyleDefault;
}

#pragma mark - AGSLayerDelegate

- (void)layerDidLoad:(AGSLayer *)layer
{
#ifdef DEBUG
    NSLog(@"Loaded layer %@", layer.name);
#endif
}

- (void)layer:(AGSLayer *)layer didFailToLoadWithError:(NSError *)error
{
    NSLog(@"Failed to load layer %@ with error %@", layer, error);

    NSString *errorTitle = [NSString stringWithFormat:NSLocalizedString(@"Could not load map for: %@. Please try again later.", nil), layer.name];

    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:errorTitle
                                                        message:nil
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                              otherButtonTitles:nil];
    [alertView show];

    [Flurry logError:@"Map_LayerFailedToLoad" message:errorTitle error:error];

}

#pragma mark - Actions

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


- (IBAction)mapLayerSegmentedControlValueChanged:(UISegmentedControl *)segmentedControl
{
    AGSLayer *layer = [self layerForMapType:segmentedControl.selectedSegmentIndex];

    if (segmentedControl.selectedSegmentIndex == SPMMapTypeAerial)
    {
        [self.mapView removeMapLayerWithName:NSLocalizedString(@"Street", nil)];
        [self.mapView insertMapLayer:layer withName:NSLocalizedString(@"Aerial", nil) atIndex:0];
    }
    else
    {
        [self.mapView removeMapLayerWithName:NSLocalizedString(@"Aerial", nil)];
        [self.mapView insertMapLayer:layer withName:NSLocalizedString(@"Street", nil) atIndex:0];
    }

    [[NSUserDefaults standardUserDefaults] setInteger:segmentedControl.selectedSegmentIndex forKey:SPMDefaultsSelectedMapType];

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

#if TARGET_IPHONE_SIMULATOR
- (void)screenshotLaunchImage
{
    self.mapSegmentedControl.enabled = NO;
    self.locationButton.enabled = NO;
    self.parkingButton.enabled = NO;
    self.legendSlider.enabled = NO;
    self.locationButton.layer.borderColor = [UIColor colorWithWhite:1 alpha:.5].CGColor;
    self.parkingButton.layer.borderColor = [UIColor colorWithWhite:1 alpha:.5].CGColor;

    UIColor *preBackgroundColor = self.view.backgroundColor;
    // This is to take a Default.png screenshot without the status bar
    self.mapView.hidden = YES;
    // Matches the ArcGIS grid background color
    self.view.backgroundColor = [UIColor colorWithWhite:0.286 alpha:1.000]; // 73x3
    [self legendsImageViewTapped];
    self.mapSegmentedControl.hidden = YES;
    self.legendContainerView.hidden = YES;

    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Taking Screenshot...", nil)
                                                        message:nil
                                                       delegate:nil
                                              cancelButtonTitle:nil
                                              otherButtonTitles:nil];
    [alertView show];

    // Wait a little bit for the screen to update
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIGraphicsBeginImageContextWithOptions(self.view.bounds.size, YES, [[UIScreen mainScreen] scale]);
        [self.view drawViewHierarchyInRect:self.view.bounds afterScreenUpdates:YES];
        UIImage *viewImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();


        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.dateStyle = NSDateFormatterLongStyle;
        dateFormatter.timeStyle = NSDateFormatterLongStyle;

        NSString *orientation = @"Portrait";
        if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
        {
            orientation = @"Landscape";
        }
        
        // Warning, this is hardcoded for convenience.
        NSString *filePath = [NSString stringWithFormat:@"/Users/marc/Desktop/LaunchImage %@ %@.png", orientation, [dateFormatter stringFromDate:[NSDate date]]];
        [UIImagePNGRepresentation(viewImage) writeToFile:filePath atomically:YES];
        //            UIImageView *view = [[UIImageView alloc] initWithImage:viewImage];
        ////            CGRect frame = view.frame;
        ////            frame.origin.y = 50;
        ////            view.frame = frame;
        //
        //            [self.view addSubview:view];
        self.mapSegmentedControl.hidden = NO;
        self.legendContainerView.hidden = NO;
        self.mapView.hidden = NO;
        self.view.backgroundColor = preBackgroundColor;
        self.mapSegmentedControl.enabled = YES;
        self.locationButton.enabled = YES;
        self.locationButton.layer.borderColor = [UIColor whiteColor].CGColor;
        self.parkingButton.layer.borderColor = [UIColor whiteColor].CGColor;
        self.parkingButton.enabled = YES;
        self.legendSlider.enabled = YES;

        [alertView dismissWithClickedButtonIndex:alertView.cancelButtonIndex animated:YES];
    });
}
#endif

- (IBAction)legendsTouched:(UIButton *)sender
{
    [UIView animateWithDuration:.3
                     animations:^{
                         [self setLegendHidden:NO];
                     }];
}

- (void)legendsImageViewTapped
{
    [UIView animateWithDuration:.3
                     animations:^{
                         [self setLegendHidden:YES];
                     }];
}

- (void)setLegendHidden:(BOOL)hidden
{
    [[NSUserDefaults standardUserDefaults] setBool:hidden forKey:SPMDefaultsLegendHidden];

    if (hidden)
    {
        self.legendsContainerHeightConstraint.constant = 36;
        self.legendContainerWidthConstraint.constant = 75;

        CGFloat adjustedValue = self.legendSlider.value + .5;
        if (adjustedValue > 1)
        {
            adjustedValue = 1;
        }
        self.legendsButton.alpha = adjustedValue;

        self.legendsImageView.alpha = 0;
        self.legendSlider.alpha = 0;

        //                         CGRect bounds = self.legendContainerView.bounds;
        //                         bounds.size.height = self.legendsContainerHeightConstraint.constant;
        //                         self.legendContainerView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:bounds cornerRadius:self.legendContainerView.layer.cornerRadius].CGPath;
        [self.view layoutIfNeeded];
    }
    else
    {
        self.legendsContainerHeightConstraint.constant = 175;//self.legendsImageView.intrinsicContentSize.height;
        self.legendContainerWidthConstraint.constant = 125;

        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        {
            self.legendsContainerHeightConstraint.constant *= 1.12;
            self.legendContainerWidthConstraint.constant *= 1.5;
        }

        self.legendsButton.alpha = 0;

        CGFloat adjustedValue = self.legendSlider.value + .5;
        if (adjustedValue > 1)
        {
            adjustedValue = 1;
        }

        self.legendsImageView.alpha = adjustedValue;
        self.legendSlider.alpha = adjustedValue;

        //                         CGRect bounds = self.legendContainerView.bounds;
        //                         bounds.size.height = self.legendsContainerHeightConstraint.constant;
        //                         self.legendContainerView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:bounds cornerRadius:self.legendContainerView.layer.cornerRadius].CGPath;
        [self.view layoutIfNeeded];
    }
}

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

- (IBAction)parkingTouched:(id)sender
{
    if (self.parkingSpotGraphicsLayer.graphicsCount)
    {
        [self centerOnParkingSpot];
        return;
    }

    AGSPoint *parkingPoint = self.mapView.locationDisplay.mapLocation;

    if ([[self availableMapDataEnvelope] containsPoint:parkingPoint])
    {
        [Flurry logEvent:@"ParkingSpot_Set_Success"];

        parkingPoint = [AGSPoint pointWithX:parkingPoint.x// - 20
                                          y:parkingPoint.y// - 20
                           spatialReference:self.mapView.spatialReference];

        NSDate *parkDate = [NSDate date];

        [self addAndShowParkingSpotMarkerWithPoint:parkingPoint date:parkDate];

        [[NSUserDefaults standardUserDefaults] setObject:[parkingPoint encodeToJSON] forKey:SPMDefaultsLastParkingPoint];
        [[NSUserDefaults standardUserDefaults] setObject:parkDate forKey:SPMDefaultsLastParkingDate];
    }
    else
    {
        [Flurry logError:@"ParkingSpot_Set_Failure" message:@"Outside of service area" error:nil];

        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Could Not Set a Parking Spot", nil)
                                                            message:NSLocalizedString(@"Your current location is outside the Seattle Department of Transportation's service area.", nil)
                                                           delegate:nil
                                                  cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                                  otherButtonTitles:nil];
        [alertView show];
    }
}

//- (IBAction)unwindFromLegend:(UIStoryboardSegue *)segue
//{
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
    
    self.legendsImageView.alpha = adjustedValue;
    self.legendSlider.alpha = adjustedValue;
}

- (IBAction)updateLocationTouched:(UIBarButtonItem *)sender
{
    [self centerOnCurrentLocation];
}

- (void)centerOnParkingSpot
{
    AGSGraphic *parkingGraphic = [self.parkingSpotGraphicsLayer.graphics firstObject];

    [self centerOnParkingGraphic:parkingGraphic attemptEnvelopeUnion:YES];
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

            // Use this API instead of expanding the envelope, otherwise if you are very near the parking spot it will zoom in too much
            [self.mapView zoomToGeometry:wideEnvelope withPadding:200 animated:YES];

            // Expand the envelope so that both points are not at the edges.
            // [wideEnvelope expandByFactor:1.3];
            // [self.mapView zoomToEnvelope:wideEnvelope animated:YES];
        }
        else
        {
            // Otherwise just center at the point if we don't have the current location
            [self.mapView zoomToScale:10000 withCenterPoint:parkingPoint animated:YES];
        }

        [self.mapView.callout showCalloutAtPoint:parkingPoint forFeature:parkingGraphic layer:self.parkingSpotGraphicsLayer animated:YES];

        //    NSLog(@"Current location %@, point %@", self.mapView.locationDisplay.mapLocation, self.mapView.locationDisplay.location.point);
    }
}

- (void)centerOnSDOTEnvelope
{
    [self.mapView zoomToEnvelope:[self SDOTEnvelope] animated:YES];
}

- (void)centerOnCurrentLocation
{
    CLAuthorizationStatus authorizationStatus = [CLLocationManager authorizationStatus];
    if (authorizationStatus != kCLAuthorizationStatusAuthorized &&
        authorizationStatus != kCLAuthorizationStatusAuthorizedAlways &&
        authorizationStatus != kCLAuthorizationStatusAuthorizedWhenInUse &&
        authorizationStatus != kCLAuthorizationStatusNotDetermined)
    {
        // iOS 8 Settings
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Please go into your device's privacy settings and allow location services to be used by this application.", nil)
                                                            message:nil
                                                           delegate:nil
                                                  cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                                  otherButtonTitles:nil];
        [alertView show];

        [Flurry logError:@"Location_Disabled" message:@"User has disabled location" error:nil];
    }
    else
    {
        if ([[self availableMapDataEnvelope] containsPoint:self.mapView.locationDisplay.mapLocation])
        {
            //    NSLog(@"Current location %@, point %@", self.mapView.locationDisplay.mapLocation, self.mapView.locationDisplay.location.point);
            [self.mapView zoomToScale:4500 withCenterPoint:self.mapView.locationDisplay.mapLocation animated:YES];
            //    [self.mapView centerAtPoint:self.mapView.locationDisplay.mapLocation animated:YES];

            // If they had panned, it is automatically off, reset it!
            self.mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeDefault;

            // Restore rotation
            if (self.mapView.rotationAngle != 0)
            {
                [self.mapView setRotationAngle:0 animated:YES];
            }
        }
        else
        {
            // Don't warn them if there is a modal
            if (![self presentedViewController])
            {
                [Flurry logError:@"Location_OutOfArea" message:@"User has tried to center on a location outside the service area" error:nil];

                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"No Parking Data Available", nil)
                                                                    message:NSLocalizedString(@"Your current location is outside the Seattle Department of Transportation's service area.", nil)
                                                                   delegate:nil
                                                          cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                                          otherButtonTitles:nil];
                [alertView show];
            }

            // Attempt to center on something
            if ([self hasStoredParkingSpot])
            {
                [self centerOnParkingSpot];
            }
            else
            {
                [self centerOnSDOTEnvelope];
            }
        }
    }
}

// We use this because there is no way to set a modalPresentationStyle in a storyboard. Fix in iOS 8?
- (IBAction)presentInformationViewController:(UIButton *)sender
{
    SPMInformationTableViewController *controller = [self.storyboard instantiateViewControllerWithIdentifier:@"SPMInformationTableViewController"];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:controller];
    navigationController.navigationBar.barStyle = UIBarStyleBlack;

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    
    [self presentViewController:navigationController
                       animated:YES
                     completion:nil];
}

#pragma mark - Parking Spot

- (BOOL)hasStoredParkingSpot
{
    if ([[NSUserDefaults standardUserDefaults] objectForKey:SPMDefaultsLastParkingPoint] != nil)
    {
        return YES;
    }

    return NO;
}

- (void)restoreParkingSpotMarker
{
    id lastParkingPoint = [[NSUserDefaults standardUserDefaults] objectForKey:SPMDefaultsLastParkingPoint];

    if ([lastParkingPoint isKindOfClass:[NSDictionary class]])
    {
        AGSPoint *parkingPoint = [[AGSPoint alloc] initWithJSON:lastParkingPoint
                                               spatialReference:self.mapView.spatialReference];

        if ([[self availableMapDataEnvelope] containsPoint:parkingPoint])
        {
            NSDate *lastParkingDate = [[NSUserDefaults standardUserDefaults] objectForKey:SPMDefaultsLastParkingDate];
            NSAssert([lastParkingDate isKindOfClass:[NSDate class]], @"Parking date is wrong");
            if (![lastParkingDate isKindOfClass:[NSDate class]])
            {
                lastParkingDate = nil;
            }

            [self addAndShowParkingSpotMarkerWithPoint:parkingPoint date:lastParkingDate];
        }
        else
        {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Could Not Restore Your Parking Spot", nil)
                                                                message:NSLocalizedString(@"Your current location is outside the Seattle Department of Transportation's service area. Your stored parking spot will now be removed.", nil)
                                                               delegate:nil
                                                      cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                                      otherButtonTitles:nil];
            [alertView show];
            [Flurry logError:@"ParkingSpot_Restore_Failure" message:@"Outside of service area" error:nil];

            [[NSUserDefaults standardUserDefaults] setObject:nil forKey:SPMDefaultsLastParkingPoint];
            [[NSUserDefaults standardUserDefaults] setObject:nil forKey:SPMDefaultsLastParkingDate];
        }
    }
}

- (void)addAndShowParkingSpotMarkerWithPoint:(nonnull AGSPoint *)parkingPoint date:(nullable NSDate *)date
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

    AGSSimpleMarkerSymbol *parkingSymbol = [AGSSimpleMarkerSymbol simpleMarkerSymbol];
    parkingSymbol.color = [UIColor redColor];
    parkingSymbol.style = AGSSimpleMarkerSymbolStyleX;
    parkingSymbol.outline.color = [[UIColor redColor] colorWithAlphaComponent:.85];
    parkingSymbol.outline.width = 2.5;
    parkingSymbol.size = CGSizeMake(20, 20);

    AGSGraphic *parkingGraphic = [AGSGraphic graphicWithGeometry:parkingPoint
                                                          symbol:parkingSymbol
                                                      attributes:@{@"title": NSLocalizedString(@"Parked Here", nil), @"date" : dateString}];

    [self.parkingSpotGraphicsLayer addGraphic:parkingGraphic];

    [self centerOnParkingGraphic:parkingGraphic attemptEnvelopeUnion:NO];

    [UIView transitionWithView:self.parkingButton
                      duration:.3
                       options:UIViewAnimationOptionCurveEaseInOut
                    animations:^{
                        self.parkingButton.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:.65];
                        self.parkingButton.layer.shadowColor = [[UIColor redColor] colorWithAlphaComponent:1].CGColor;
                    }
                    completion:nil];
}

#pragma mark - AGSCalloutDelegate

- (void)calloutDidDismiss:(AGSCallout *)callout
{
    [self.legendSlider setValue:[[NSUserDefaults standardUserDefaults] floatForKey:SPMDefaultsLegendOpacity] animated:YES];
    self.dynamicLayer.opacity = self.legendSlider.value;
}

- (void)didClickAccessoryButtonForCallout:(AGSCallout *)callout
{
    [((AGSGraphicsLayer *)callout.representedLayer) removeGraphic:(AGSGraphic *)callout.representedFeature];
    [[NSUserDefaults standardUserDefaults] setObject:nil forKey:SPMDefaultsLastParkingPoint];
    [[NSUserDefaults standardUserDefaults] setObject:nil forKey:SPMDefaultsLastParkingDate];
    [callout dismiss];

    [UIView transitionWithView:self.parkingButton
                      duration:.3
                       options:UIViewAnimationOptionCurveEaseInOut
                    animations:^{
                        self.parkingButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:.65];
                        self.parkingButton.layer.shadowColor = [UIColor blackColor].CGColor;
                    }
                    completion:^(BOOL finished) {
                        self.mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeDefault;
                    }];
}

#pragma mark - AGSLayerCalloutDelegate

- (BOOL)callout:(AGSCallout *)callout willShowForFeature:(id <AGSFeature>)feature layer:(AGSLayer <AGSHitTestable> *)layer mapPoint:(AGSPoint *)mapPoint
{
    // At this point the user does not care anymore about the legend or overlays, just getting there.
    [self.legendSlider setValue:0 animated:YES];
    self.dynamicLayer.opacity = 0;
    [self setLegendHidden:YES];

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

	return YES;
}

#pragma mark - AGSMapViewLayerDelegate

/// Where parking data is available
- (AGSEnvelope *)SDOTEnvelope
{
    // This was obtained by zooming out to the limits of the city of Seattle and inspecting the ArcGIS map view's properties.
    AGSSpatialReference *reference = [AGSSpatialReference spatialReferenceWithWKID:2926];
    AGSEnvelope *envelope = [AGSEnvelope envelopeWithXmin:1236463.072915 ymin:183835.269949 xmax:1303549.175423 ymax:273283.406628 spatialReference:reference];
    return envelope;
}

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

    if ([self hasStoredParkingSpot])
    {
        [self restoreParkingSpotMarker];
    }
    else
    {
        [self centerOnSDOTEnvelope];
    }

    // Official SDOT Wording: There may be a time lag between sign installation and record data entry; consequently, the map may not reflect on- the-ground reality. Always comply with city parking rules and regulations

    if (![[NSUserDefaults standardUserDefaults] boolForKey:SPMDefaultsShownInitialWarning])
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Warning", nil)
                                                            message:NSLocalizedString(@"The map may not always reflect the on-the-ground reality since there might be a delay between on-street changes and the data being entered into the system.\n\nAlways double check before parking and comply with city parking rules and regulations posted on the street.", nil)
                                                           delegate:self
                                                  cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                                  otherButtonTitles:nil];
        [alertView show];

        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:SPMDefaultsShownInitialWarning];
    }
    else
    {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self beginLocationUpdates];
        });
    }
}

- (void)beginLocationUpdates
{
    // Don't automatically pan if we have a parking spot. This will be reset when the user taps the current location update, or dismisses the parking spot.
    // Test case: launch with a parking spot away from your current location.
    if (![self hasStoredParkingSpot])
    {
        self.mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeDefault;
    }

//    self.mapView.locationDisplay.wanderExtentFactor = 1;

//    self.mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeCompassNavigation;
    self.mapView.locationDisplay.showsPing = YES;
    [self.mapView.locationDisplay startDataSource];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    [self beginLocationUpdates];
}

//#pragma mark - AGSMapServiceInfoDelegate
//
//- (void)mapServiceInfo:(AGSMapServiceInfo *)mapServiceInfo operationDidRetrieveLegendInfo:(NSOperation *)op
//{
////    for (AGSMapServiceLayerInfo *layerInfo in mapServiceInfo.layerInfos)
////    {
////        NSLog(@"%@ %lu", layerInfo.name, (unsigned long)layerInfo.layerId);
////        NSLog(@"%@", layerInfo.legendLabels);
////        NSLog(@"%@", layerInfo.legendLabels);
////    }
//}
//
//- (void)mapServiceInfo:(AGSMapServiceInfo *)mapServiceInfo operation:(NSOperation *)op didFailToRetrieveLegendInfoWithError:(NSError* )error
//{
////    NSLog(@"Failed to load info");
//}


@end
