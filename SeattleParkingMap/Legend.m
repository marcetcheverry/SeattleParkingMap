//
//  Legend.m
//  SeattleParkingMap
//
//  Created by Marc on 12/24/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

#import "Legend.h"

@implementation Legend

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@, name: %@, image %@, index %lu, isBold %i, hasRoundedCorners %i",
            [super description],
            self.name,
            self.image,
            (unsigned long)self.index,
            self.isBold,
            self.hasRoundedCorners];
}
@end
