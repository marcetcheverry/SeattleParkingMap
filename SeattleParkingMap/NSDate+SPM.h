//
//  NSDate+SPM.h
//  SeattleParkingMap
//
//  Created by Marc on 1/5/16.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

@interface NSDate (SPM)

- (BOOL)SPMIsBeforeDate:(nonnull NSDate *)date;
- (BOOL)SPMIsAfterDate:(nonnull NSDate *)date;
- (BOOL)SPMIsEqualOrBeforeDate:(nonnull NSDate *)date;
- (BOOL)SPMIsEqualOrAfterDate:(nonnull NSDate *)date;

@end
