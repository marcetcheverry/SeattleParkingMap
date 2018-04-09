//
//  ParkingSpot.m
//  SeattleParkingMap
//
//  Created by Marc on 12/21/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

#import "ParkingSpot.h"

#import "ParkingTimeLimit.h"

static NSString * const SPMWatchObjectParkingLocation = @"SPMWatchObjectParkingLocation";
static NSString * const SPMWatchObjectParkingLocationLatitude = @"SPMWatchObjectParkingLocationLatitude";
static NSString * const SPMWatchObjectParkingLocationLongitude = @"SPMWatchObjectParkingLocationLongitude";
static NSString * const SPMWatchObjectParkingDate = @"SPMWatchObjectParkingDate";
NSString * const SPMWatchObjectParkingAddress = @"SPMWatchObjectParkingAddress";

@interface ParkingSpot ()

@property (nonnull, nonatomic, readwrite) NSDate *date;
@property (nonnull, nonatomic, readwrite) CLLocation *location;

@end

@implementation ParkingSpot

- (nullable instancetype)initWithLocation:(nonnull CLLocation *)location
                                     date:(nonnull NSDate *)date
{
    NSParameterAssert(location);
    NSParameterAssert(date);
    
    if (!location)
    {
        return nil;
    }
    
    if (!date)
    {
        return nil;
    }
    
    self = [super init];
    
    if (self)
    {
        self.location = location;
        self.date = date;
    }
    
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@\nDate: %@\nLocation: %@\nTime Limit: %@\nAddress: %@",
            [super description],
            self.date,
            self.location,
            self.timeLimit,
            self.address];
}

#pragma mark - Equality

- (BOOL)isEqualToParkingSpot:(ParkingSpot *)parkingSpot
{
    NSParameterAssert(parkingSpot);
    
    if (!parkingSpot)
    {
        return NO;
    }
    
    BOOL haveEqualDate = (!self.date && !parkingSpot.date) || [self.date isEqualToDate:parkingSpot.date];
    BOOL haveEqualLocation = (!self.location && !parkingSpot.location) || [self.location distanceFromLocation:parkingSpot.location] < 1;
    BOOL haveEqualTimeLimit = (!self.timeLimit && !parkingSpot.timeLimit) || [self.timeLimit isEqualToParkingTimeLimit:parkingSpot.timeLimit];
    
    return haveEqualDate && haveEqualLocation && haveEqualTimeLimit;
}

- (BOOL)isEqual:(id)object
{
    if (self == object)
    {
        return YES;
    }
    
    if (![object isKindOfClass:[self class]])
    {
        return NO;
    }
    
    return [self isEqualToParkingSpot:(ParkingSpot *)object];
}

- (NSUInteger)hash
{
    return [self.date hash] ^ [self.location hash] ^ [self.timeLimit hash];
}

#pragma mark - WatchConnectivitySerialization

- (nullable instancetype)initWithWatchConnectivityDictionary:(nonnull NSDictionary *)dictionary
{
    //    NSParameterAssert(dictionary);
    
    if (!dictionary)
    {
        return nil;
    }
    
    NSNumber *latitude = dictionary[SPMWatchObjectParkingLocation][SPMWatchObjectParkingLocationLatitude];
    NSNumber *longitude = dictionary[SPMWatchObjectParkingLocation][SPMWatchObjectParkingLocationLongitude];
    
    CLLocation *location = [[CLLocation alloc] initWithLatitude:[latitude doubleValue]
                                                      longitude:[longitude doubleValue]];
    ParkingSpot *spot = [self initWithLocation:location
                                          date:dictionary[SPMWatchObjectParkingDate]];
    
    spot.timeLimit = [[ParkingTimeLimit alloc] initWithWatchConnectivityDictionary:dictionary[SPMWatchObjectParkingTimeLimit]];
    spot.address = dictionary[SPMWatchObjectParkingAddress];
    return spot;
}

- (nonnull NSDictionary *)watchConnectivityDictionaryRepresentation
{
    NSDictionary *coordinates = @{SPMWatchObjectParkingLocationLatitude: @(self.location.coordinate.latitude),
                                  SPMWatchObjectParkingLocationLongitude: @(self.location.coordinate.longitude)};
    
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] initWithCapacity:2];
    dictionary[SPMWatchObjectParkingLocation] = coordinates;
    dictionary[SPMWatchObjectParkingDate] = self.date;
    
    if (self.timeLimit)
    {
        dictionary[SPMWatchObjectParkingTimeLimit] =[self.timeLimit watchConnectivityDictionaryRepresentation];
    }
    
    if (self.address)
    {
        dictionary[SPMWatchObjectParkingAddress] = self.address;
    }
    
    return dictionary;
}

- (BOOL)wasParkedToday
{
    return [[NSCalendar currentCalendar] isDate:self.date
                                inSameDayAsDate:[NSDate date]];
}

- (nonnull NSString *)localizedDateString
{
    return [self.date SPMLocalizedRelativeString];
}

- (nonnull NSString *)localizedAbsoluteDateString
{
    return [self.date SPMLocalizedString];
}

@end
