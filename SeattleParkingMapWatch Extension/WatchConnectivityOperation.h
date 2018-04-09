//
//  WatchConnectivityOperation.h
//  SeattleParkingMap
//
//  Created by Marc on 12/27/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

@interface WatchConnectivityOperation : NSObject

@property (nullable, nonatomic) NSString *identifier;
@property (nonatomic, getter=isCancelled) BOOL cancelled;
@property (nonatomic, getter=isFinished) BOOL finished;

@end
