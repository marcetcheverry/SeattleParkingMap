//
//  WKInterfaceController+SPM.h
//  SeattleParkingMap
//
//  Created by Marc on 12/14/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

@interface WKInterfaceController (SPM)

// WatchOS 2 does not have a completion API
- (void)SPMAnimateWithDuration:(NSTimeInterval)duration
                    animations:(dispatch_block_t)animations
                    completion:(dispatch_block_t)completion;

@end
