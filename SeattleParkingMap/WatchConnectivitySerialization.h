//
//  WatchConnectivitySerialization.h
//  SeattleParkingMap
//
//  Created by Marc on 12/26/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

@protocol WatchConnectivitySerialization <NSObject>

- (nullable instancetype)initWithWatchConnectivityDictionary:(nonnull NSDictionary *)dictionary;
- (nonnull NSDictionary *)watchConnectivityDictionaryRepresentation;

@end
