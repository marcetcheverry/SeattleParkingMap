//
//  LegendDataSource.m
//  SeattleParkingMap
//
//  Created by Marc on 12/24/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

#import "LegendDataSource.h"

#import "Legend.h"
#import "LegendTableViewCell.h"

#import "UIImage+SPM.h"

// Swift enums would be wonderful here!

// SDOT Names from the legend JSON response
#define SPMLegendSDOTNameUnrestricted @"Unrestricted Parking"
#define SPMLegendSDOTNameTimeLimited @"Time Limited Parking"
#define SPMLegendSDOTNameCarpool @"Carpool Parking"
#define SPMLegendSDOTNamePaid @"Paid Parking"
#define SPMLegendSDOTNameRestricted @"Restricted Parking Zone"
#define SPMLegendSDOTNameNoParking @"No Parking Allowed"
#define SPMLegendSDOTNameTemporary @"Temporary No Parking"

// Local order
typedef NS_ENUM(NSUInteger, SPMLegendDisplayIndex)
{
    SPMLegendDisplayIndexUnrestricted,
    SPMLegendDisplayIndexTimeLimited,
    SPMLegendDisplayIndexPaid,
    SPMLegendDisplayIndexRestricted,
    SPMLegendDisplayIndexCarpool,
    SPMLegendDisplayIndexNoParking,
    SPMLegendDisplayIndexTemporary,
    SPMLegendDisplayIndexCount
};

@interface LegendDataSource ()

@property (nonatomic) NSMutableArray <Legend *> *legends;
@property (nonatomic) NSArray <NSArray <Legend *> *> *sectionedLegends;

@end

@implementation LegendDataSource

- (nullable UIColor *)legendColorForDisplayIndex:(SPMLegendDisplayIndex)index
{
    UIColor *color;
    switch (index)
    {
        case SPMLegendDisplayIndexUnrestricted:
            color = [UIColor colorWithRed:0.664 green:0.664 blue:0.664 alpha:1];
            break;
        case SPMLegendDisplayIndexTimeLimited:
            color = [UIColor colorWithRed:0.002 green:0.437 blue:0.998 alpha:1];
            break;
        case SPMLegendDisplayIndexPaid:
            color = [UIColor colorWithRed:0 green:0.684 blue:0.3 alpha:1];
            break;
        case SPMLegendDisplayIndexRestricted:
            color = [UIColor colorWithRed:0.998 green:0.881 blue:0.001 alpha:1];
            break;
        case SPMLegendDisplayIndexCarpool:
            color = [UIColor colorWithRed:0.892 green:0.166 blue:0.562 alpha:1];
            break;
        case SPMLegendDisplayIndexNoParking:
            color = [UIColor colorWithRed:1 green:0.493 blue:0 alpha:1];
            break;
        case SPMLegendDisplayIndexTemporary:
            color = [UIColor colorWithRed:0.77 green:0.228 blue:0.997 alpha:1];
            break;
        default:
            break;
    }

    return color;
}

- (void)addLegend:(Legend *)legend
{
    NSParameterAssert(legend);
    if (!legend)
    {
        return;
    }

    if (!self.legends)
    {
        self.legends = [[NSMutableArray alloc] init];
    }

    // Override here, no need to do it at display time
    legend.index = [self displayIndexForSDOTName:legend.name
                                       SDOTIndex:legend.index];

    if (legend.index == SPMLegendDisplayIndexCarpool)
    {
        return;
    }
    else if (legend.index == SPMLegendDisplayIndexUnrestricted)
    {
        legend.isBold = YES;
    }
    else if (legend.index == SPMLegendDisplayIndexTemporary)
    {
        legend.hasRoundedCorners = YES;
    }

    UIImage *image = [UIImage SPMImageWithColor:[self legendColorForDisplayIndex:legend.index]];
    if (image)
    {
        legend.image = image;
    }

    legend.name = [self displayNameForSDOTName:legend.name];
    [self.legends addObject:legend];
}

- (void)sortLegends
{
    NSSortDescriptor *descriptor = [NSSortDescriptor sortDescriptorWithKey:@"index"
                                                                 ascending:YES];
    [self.legends sortUsingDescriptors:@[descriptor]];

    NSUInteger legendsCount = self.legends.count;

    if (legendsCount >= 6)
    {
        NSArray *section1 = [self.legends subarrayWithRange:NSMakeRange(0, SPMLegendDisplayIndexPaid + 1)];
        NSArray *section2 = [self.legends subarrayWithRange:NSMakeRange(SPMLegendDisplayIndexPaid + 1, 1)];
        NSRange noParkingRange = NSMakeRange(SPMLegendDisplayIndexRestricted + 1, 2);
        NSArray *section3 = [self.legends subarrayWithRange:noParkingRange];

        if (legendsCount > (section1.count + section2.count + section3.count))
        {
            NSUInteger startIndex = noParkingRange.location + noParkingRange.length;
            NSArray *serverSection = [self.legends subarrayWithRange:NSMakeRange(startIndex, legendsCount - startIndex)];
            self.sectionedLegends = @[section1, section2, section3, serverSection];
        }
        else
        {
            self.sectionedLegends = @[section1, section2, section3];
        }
    }
    else
    {
        self.sectionedLegends = @[self.legends];
    }


    self.legends = nil;
}

// It would be nicer to match by "url" in the legend dictionary but ArcGIS does not expose it
- (nullable NSString *)displayNameForSDOTName:(nonnull NSString *)name
{
    NSParameterAssert(name);

    if (!name)
    {
        return nil;
    }

    if ([name isEqualToString:SPMLegendSDOTNameUnrestricted])
    {
        return NSLocalizedString(@"Unrestricted", nil);
    }
    else if ([name isEqualToString:SPMLegendSDOTNameTimeLimited])
    {
        return NSLocalizedString(@"Time Limited", nil);
    }
    else if ([name isEqualToString:SPMLegendSDOTNameCarpool])
    {
        return NSLocalizedString(@"Carpool", nil);
    }
    else if ([name isEqualToString:SPMLegendSDOTNamePaid])
    {
        return NSLocalizedString(@"Paid", nil);
    }
    else if ([name isEqualToString:SPMLegendSDOTNameRestricted])
    {
        return NSLocalizedString(@"Permit", nil);
    }
    else if ([name isEqualToString:SPMLegendSDOTNameNoParking])
    {
        return NSLocalizedString(@"No Parking", nil);
    }
    else if ([name isEqualToString:SPMLegendSDOTNameTemporary])
    {
        return NSLocalizedString(@"Temporary Restriction", nil);
    }

    return name;
}

- (NSUInteger)displayIndexForSDOTName:(nonnull NSString *)name
                            SDOTIndex:(NSUInteger)index
{
    NSParameterAssert(name);

    if (!name)
    {
        return SPMLegendDisplayIndexCount + index;
    }

    if ([name isEqualToString:SPMLegendSDOTNameUnrestricted])
    {
        return SPMLegendDisplayIndexUnrestricted;
    }
    else if ([name isEqualToString:SPMLegendSDOTNameTimeLimited])
    {
        return SPMLegendDisplayIndexTimeLimited;
    }
    else if ([name isEqualToString:SPMLegendSDOTNameCarpool])
    {
        return SPMLegendDisplayIndexCarpool;
    }
    else if ([name isEqualToString:SPMLegendSDOTNamePaid])
    {
        return SPMLegendDisplayIndexPaid;
    }
    else if ([name isEqualToString:SPMLegendSDOTNameRestricted])
    {
        return SPMLegendDisplayIndexRestricted;
    }
    else if ([name isEqualToString:SPMLegendSDOTNameNoParking])
    {
        return SPMLegendDisplayIndexNoParking;
    }
    else if ([name isEqualToString:SPMLegendSDOTNameTemporary])
    {
        return SPMLegendDisplayIndexTemporary;
    }

    return SPMLegendDisplayIndexCount + index;
}

- (void)synthesizeDefaultLegends
{
    NSArray *defaultLegends = @[SPMLegendSDOTNameUnrestricted,
                                SPMLegendSDOTNameTimeLimited,
                                SPMLegendSDOTNamePaid,
                                SPMLegendSDOTNameRestricted,
                                //SPMLegendSDOTNameCarpool,
                                SPMLegendSDOTNameNoParking,
                                SPMLegendSDOTNameTemporary];
    for (NSString *legendTitle in defaultLegends)
    {
        Legend *legend = [[Legend alloc] init];
        legend.name = legendTitle;
        [self addLegend:legend];
    }

    [self sortLegends];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return self.sectionedLegends.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.sectionedLegends[section].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    LegendTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"LegendTableViewCell"
                                                                forIndexPath:indexPath];
    Legend *legend = self.sectionedLegends[indexPath.section][indexPath.row];
    cell.legend = legend;
    return cell;
}

@end
