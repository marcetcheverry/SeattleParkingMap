//
//  UIImage+SPM.m
//  SeattleParkingMap
//
//  Created by Marc on 12/25/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

#import "UIImage+SPM.h"

@implementation UIImage (SPM)

+ (nullable UIImage *)SPMImageWithColor:(nonnull UIColor *)color
{
    if (!color)
    {
        return nil;
    }

    CGRect rect = CGRectMake(0, 0, 1, 1);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();

    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return image;
}

@end
