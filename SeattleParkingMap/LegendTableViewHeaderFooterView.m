//
//  LegendTableViewHeaderFooterView.m
//  SeattleParkingMap
//
//  Created by Marc on 12/14/19.
//  Copyright © 2019 Tap Light Software. All rights reserved.
//

#import "LegendTableViewHeaderFooterView.h"

@implementation LegendTableViewHeaderFooterView

- (instancetype)initWithReuseIdentifier:(nullable NSString *)reuseIdentifier {
    self = [super initWithReuseIdentifier:reuseIdentifier];
    if (self)
    {
        self.opaque = NO;
        self.backgroundView = [UIView new];
        self.backgroundView.backgroundColor = [UIColor clearColor];
        self.backgroundView.opaque = NO;
    }

    return self;
}

@end
