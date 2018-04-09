//
//  NeighborhoodTableViewCell.m
//  SeattleParkingMap
//
//  Created by Marc on 03/22/18.
//  Copyright © 2018 Tap Light Software. All rights reserved.
//

#import "NeighborhoodTableViewCell.h"

#import "Neighborhood.h"

@interface NeighborhoodTableViewCell ()

@property (weak, nonatomic) IBOutlet UILabel *neighborhoodLabel;

@end

@implementation NeighborhoodTableViewCell

- (void)setNeighborhood:(Neighborhood *)neighborhood
{
    if (_neighborhood != neighborhood)
    {
        _neighborhood = neighborhood;
        self.neighborhoodLabel.text = neighborhood.name;
    }
}

@end
