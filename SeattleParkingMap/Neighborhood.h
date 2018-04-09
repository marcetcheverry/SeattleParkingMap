//
//  Neighborhood.h
//  SeattleParkingMap
//
//  Created by Marc on 3/22/18.
//  Copyright © 2018 Tap Light Software. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

@interface Neighborhood : NSObject

- (BOOL)isEqualToNeighborhood:(Neighborhood *)neighborhood;

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly, nullable) AGSEnvelope *envelope;

@end

NS_ASSUME_NONNULL_END
