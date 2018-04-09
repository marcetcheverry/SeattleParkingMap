//
//  UIColor+SPM.m
//  SeattleParkingMap
//
//  Created by Marc on 12/27/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

#import "UIColor+SPM.h"

@implementation UIColor (SPM)

+ (nonnull UIColor *)SPMLocationButtonColor
{
    // Blue based on ArcGIS location dot
    return [UIColor colorWithRed:0
                           green:.47
                            blue:.771
                           alpha:1];
}

+ (nonnull UIColor *)SPMWatchTintColor
{
    // Light blue
    return [UIColor colorWithRed:.234
                           green:.778
                            blue:1
                           alpha:1];
}

+ (nonnull UIColor *)SPMButtonParkColor
{
    // Light blue variant
    return [UIColor colorWithRed:0
                           green:.569
                            blue:1
                           alpha:1];
}

+ (nonnull UIColor *)SPMParkedColor
{
    return [UIColor colorWithRed:1
                           green:.132
                            blue:0
                           alpha:1];
}

@end
