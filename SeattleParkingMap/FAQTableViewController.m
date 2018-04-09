//
//  FAQTableViewController.m
//  Seattle Parking Map
//
//  Created by Marc on 1/30/16
//  Copyright (c) 2016 Tap Light Software. All rights reserved.
//

#import "FAQTableViewController.h"

#import "Analytics.h"

@implementation FAQTableViewController

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [Analytics logEvent:@"FAQ_viewDidLoad"];
}

@end
