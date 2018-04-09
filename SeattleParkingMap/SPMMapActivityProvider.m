//
//  SPMMapActivityProvider.m
//  Seattle Parking Map
//
//  Created by Marc on 6/14/14.
//  Copyright (c) 2014 Tap Light Software. All rights reserved.
//

#import "SPMMapActivityProvider.h"

@implementation SPMMapActivityProvider

- (id)item
{
//    UIGraphicsBeginImageContextWithOptions(self.screenshotView.bounds.size, NO, 0);
//    [self.screenshotView drawViewHierarchyInRect:self.screenshotView.bounds afterScreenUpdates:YES];
//    UIImage *mapScreenshot = UIGraphicsGetImageFromCurrentImageContext();
//    UIGraphicsEndImageContext();
//    
    return [UIImage imageNamed:@"Location"];
}

- (NSString *)activityViewController:(UIActivityViewController *)activityViewController dataTypeIdentifierForActivityType:(NSString *)activityType
{
    return @"image/jpeg";
}

- (NSString *)activityViewController:(UIActivityViewController *)activityViewController subjectForActivityType:(NSString *)activityType
{
    return @"Subject location";
}

@end
