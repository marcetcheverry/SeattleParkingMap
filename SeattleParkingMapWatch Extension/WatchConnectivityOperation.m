//
//  WatchConnectivityOperation.m
//  SeattleParkingMap
//
//  Created by Marc on 12/27/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

#import "WatchConnectivityOperation.h"

@implementation WatchConnectivityOperation

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@\nIdentifier: %@\nCancelled: %@\nFinished: %@",
            [super description],
            self.identifier,
            @(self.cancelled),
            @(self.finished)];
}

@end
