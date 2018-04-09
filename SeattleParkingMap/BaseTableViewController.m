//
//  BaseTableViewController.m
//  Seattle Parking Map
//
//  Created by Marc on 1/30/16.
//  Copyright (c) 2016 Tap Light Software. All rights reserved.
//

#import "BaseTableViewController.h"

@implementation BaseTableViewController

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.tableView.estimatedRowHeight = 100;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    [self.tableView reloadData];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll; // rotate upside down on the iPhone for car users
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewAutomaticDimension;
}

@end
