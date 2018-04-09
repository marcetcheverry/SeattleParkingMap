//
//  LegendDataSource.h
//  SeattleParkingMap
//
//  Created by Marc on 12/24/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

@class Legend;

@interface LegendDataSource <UITableViewDataSource> : NSObject

/// Not thread safe
- (void)addLegend:(nonnull Legend *)legend;
/// Not thread safe. Sorts according to Legend.index
- (void)sortLegends;

/// Just in case we fail to retrieve them
- (void)synthesizeDefaultLegends;

@end
