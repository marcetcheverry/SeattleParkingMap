//
//  Analytics.h
//  SeattleParkingMap
//
//  Created by Marc on 3/16/18.
//  Copyright © 2018 Tap Light Software. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

/// Placeholder class that replaced the Flurry API
@interface Analytics : NSObject

+ (void)logEvent:(NSString *)event;
+ (void)logEvent:(NSString *)event withParameters:(NSDictionary *)dictionary;
+ (void)logError:(NSString *)errror message:(NSString *)message error:(nullable NSError *)error;

@end

NS_ASSUME_NONNULL_END
