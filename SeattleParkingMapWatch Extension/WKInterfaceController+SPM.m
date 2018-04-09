//
//  WKInterfaceController+SPM.m
//  SeattleParkingMap
//
//  Created by Marc on 12/14/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

#import "WKInterfaceController+SPM.h"

@implementation WKInterfaceController (SPM)

- (void)SPMAnimateWithDuration:(NSTimeInterval)duration
                    animations:(dispatch_block_t)animations
                    completion:(dispatch_block_t)completion
{
    [self animateWithDuration:duration animations:animations];

    if (completion)
    {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            completion();
        });
    }
}

@end
