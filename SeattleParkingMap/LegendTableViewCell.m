//
//  LegendTableViewCell.m
//  SeattleParkingMap
//
//  Created by Marc on 12/24/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

#import "LegendTableViewCell.h"

#import "Legend.h"

@interface LegendTableViewCell ()

@property (weak, nonatomic) IBOutlet UIImageView *legendImageView;
@property (nonatomic) CGRect lastLegendImageViewBounds;

@end

@implementation LegendTableViewCell

- (void)setLegend:(Legend *)legend
{
    if (_legend != legend)
    {
        _legend = legend;
        self.legendImageView.image = legend.image;
        self.legendLabel.text = legend.name;

        if (legend.hasRoundedCorners)
        {
            [self setRoundedLegendMask];
        }
        else
        {
            self.legendImageView.layer.mask = nil;
        }
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    if (self.legendImageView.layer.mask)
    {
        if (!CGRectEqualToRect(self.lastLegendImageViewBounds, self.legendImageView.bounds))
        {
            [self setRoundedLegendMask];
        }
    }
}

- (void)setRoundedLegendMask
{
    self.lastLegendImageViewBounds = self.legendImageView.bounds;
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:self.legendImageView.bounds
                                                        cornerRadius:10];
    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    maskLayer.frame = self.legendImageView.bounds;
    maskLayer.path = maskPath.CGPath;
    self.legendImageView.layer.mask = maskLayer;
}

@end
