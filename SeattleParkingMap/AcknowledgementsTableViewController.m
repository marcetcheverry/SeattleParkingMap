//
//  AcknowledgementsTableViewController.m
//  Seattle Parking Map
//
//  Created by Marc on 1/30/16
//  Copyright (c) 2016 Tap Light Software. All rights reserved.
//

#import "AcknowledgementsTableViewController.h"

#import "Analytics.h"

@implementation AcknowledgementsTableViewController

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [Analytics logEvent:@"Acknowledgements_viewDidLoad"];
}

#pragma mark - Actions

- (IBAction)sdotTouched:(UIButton *)sender
{
    [Analytics logEvent:@"Information_SDOTWebsiteTouched"];
    
    NSURL *URL = [NSURL URLWithString:@"http://www.seattle.gov/transportation/"];
    if (URL)
    {
        [UIApplication.sharedApplication openURL:URL
                                         options:@{}
                               completionHandler:nil];
    }
}

- (IBAction)seattleParkingMapTouched:(UIButton *)sender
{
    [Analytics logEvent:@"Information_SPMWebsiteTouched"];
    
    NSURL *URL = [NSURL URLWithString:@"http://web6.seattle.gov/sdot/seattleparkingmap/"];
    if (URL)
    {
        [UIApplication.sharedApplication openURL:URL
                                         options:@{}
                               completionHandler:nil];
    }
}

- (IBAction)arcGISRuntimeTouched:(UIButton *)sender
{
    [Analytics logEvent:@"Information_ArcGISWebsiteTouched"];
    
    NSURL *URL = [NSURL URLWithString:@"http://developers.arcgis.com/ios/"];
    if (URL)
    {
        [UIApplication.sharedApplication openURL:URL
                                         options:@{}
                               completionHandler:nil];
    }
}

@end
