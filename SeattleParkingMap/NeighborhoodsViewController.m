//
//  NeighborhoodsViewController.m
//  SeattleParkingMap
//
//  Created by Marc on 3/22/18.
//  Copyright © 2018 Tap Light Software. All rights reserved.
//

#import "NeighborhoodsViewController.h"

#import "NeighborhoodDataSource.h"
#import "NeighborhoodTableViewCell.h"
#import "Neighborhood.h"

@interface NeighborhoodsViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic) NSArray <NSString *> *sortedSectionInitials;
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@end

@implementation NeighborhoodsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self.tableView reloadData];

    Neighborhood *selected = self.neighborhoodDataSource.selectedNeighborhood;
    if (selected)
    {
        NSString *initial = [selected.name substringWithRange:NSMakeRange(0, 1)];

        NSUInteger section = [self.sortedSectionInitials indexOfObject:initial];
        NSArray *rows = [self.neighborhoodDataSource.alphabeticallySectionedNeighborhoods objectForKey:initial];
        NSUInteger row = [rows indexOfObject:selected];

        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row
                                                    inSection:section];
        [self.tableView selectRowAtIndexPath:indexPath
                                    animated:NO
                              scrollPosition:UITableViewScrollPositionNone];
    }
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *key = self.sortedSectionInitials[indexPath.section];
    Neighborhood *hood = self.neighborhoodDataSource.alphabeticallySectionedNeighborhoods[key][indexPath.row];
    self.neighborhoodDataSource.selectedNeighborhood = hood;
    [self performSegueWithIdentifier:@"SelectedNeighborhood"
                              sender:self];
}

#pragma mark - UITableViewDataSource

- (NSArray <NSString *> *)sortedSectionInitials
{
    if (!_sortedSectionInitials)
    {
        _sortedSectionInitials = [self.neighborhoodDataSource.alphabeticallySectionedNeighborhoods.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    }

    return _sortedSectionInitials;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return self.sortedSectionInitials.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSString *key = self.sortedSectionInitials[section];
    return self.neighborhoodDataSource.alphabeticallySectionedNeighborhoods[key].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NeighborhoodTableViewCell *cell = (NeighborhoodTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"NeighborhoodTableViewCell"];

    NSString *key = self.sortedSectionInitials[indexPath.section];
    cell.neighborhood = self.neighborhoodDataSource.alphabeticallySectionedNeighborhoods[key][indexPath.row];

    UIView *backgroundView = [[UIView alloc] initWithFrame:cell.bounds];
    backgroundView.backgroundColor = [UIColor colorWithWhite:0 alpha:.25];
    backgroundView.opaque = NO;

    cell.selectedBackgroundView = backgroundView;

    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self.neighborhoodDataSource.selectedNeighborhood isEqualToNeighborhood:((NeighborhoodTableViewCell *)cell).neighborhood])
    {
        cell.selected = YES;
    }
    else
    {
        cell.selected = NO;
    }
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section
{
    view.tintColor = UIColor.clearColor;

    UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
    header.textLabel.textColor = UIColor.whiteColor;
    header.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return self.sortedSectionInitials[section];
}

- (NSArray <NSString *> *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
    return self.sortedSectionInitials;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
{
    return [self.sortedSectionInitials indexOfObject:title];
}

@end
