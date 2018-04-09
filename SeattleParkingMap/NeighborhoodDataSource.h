//
//  NeighborhoodDataSource.m
//  SeattleParkingMap
//
//  Created by Marc on 3/21/18.
//  Copyright © 2018 Tap Light Software. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

@class Neighborhood;

typedef NS_ENUM(NSInteger, SPMLoadingState)
{
    SPMStateUnknown,
    SPMStateLoading,
    SPMStateLoaded,
    SPMStateFailedToLoad
};

@interface NeighborhoodDataSource : NSObject

@property (nonatomic, readonly) SPMLoadingState state;

@property (nonatomic, nullable) Neighborhood *selectedNeighborhood;
@property (nonatomic, copy, readonly) NSArray <Neighborhood *> *neighborhoods;
@property (nonatomic, readonly) NSDictionary <NSString *, NSArray *> *alphabeticallySectionedNeighborhoods;

/// Will return NO if called when state is already loading
- (void)loadNeighboorhoodsWithCompletionHandler:(void (^)(BOOL success))completionHandler;

@end

NS_ASSUME_NONNULL_END
