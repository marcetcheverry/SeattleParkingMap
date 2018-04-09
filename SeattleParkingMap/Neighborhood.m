//
//  Neighborhood.m
//  SeattleParkingMap
//
//  Created by Marc on 3/22/18.
//  Copyright © 2018 Tap Light Software. All rights reserved.
//

#import "Neighborhood.h"

@interface Neighborhood ()

@property (nonatomic, readwrite) NSString *name;
@property (nonatomic) NSNumber *XMin;
@property (nonatomic) NSNumber *XMax;
@property (nonatomic) NSNumber *YMin;
@property (nonatomic) NSNumber *YMax;

@end

@implementation Neighborhood

- (nullable AGSEnvelope *)envelope
{
    if (self.XMin != nil &&
        self.XMax != nil &&
        self.YMin != nil &&
        self.YMax != nil)
    {
        return [AGSEnvelope envelopeWithXMin:self.XMin.doubleValue
                                        yMin:self.YMin.doubleValue
                                        xMax:self.XMax.doubleValue
                                        yMax:self.YMax.doubleValue
                            spatialReference:[AGSSpatialReference spatialReferenceWithWKID:SPMSpatialReferenceWKIDSDOT]];
    }

    return nil;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@\nName: %@\nXMin: %@\nXMax: %@\nYMin: %@\nYMax: %@\nenvelope: %@",
            [super description],
            self.name,
            self.XMin,
            self.XMax,
            self.YMin,
            self.YMax,
            self.envelope];
}

#pragma mark - Equality

- (BOOL)isEqualToNeighborhood:(Neighborhood *)neighborhood
{
    NSParameterAssert(neighborhood);

    if (!neighborhood)
    {
        return NO;
    }

    BOOL haveEqualName = (!self.name && !neighborhood.name) || [self.name isEqualToString:neighborhood.name];
    BOOL haveEqualXMin = (!self.XMin && !neighborhood.XMin) || [self.XMin isEqualToNumber:neighborhood.XMin];
    BOOL haveEqualXMax = (!self.XMax && !neighborhood.XMax) || [self.XMax isEqualToNumber:neighborhood.XMax];
    BOOL haveEqualYMin = (!self.YMin && !neighborhood.YMin) || [self.YMin isEqualToNumber:neighborhood.YMin];
    BOOL haveEqualYMax = (!self.YMax && !neighborhood.YMax) || [self.YMax isEqualToNumber:neighborhood.YMax];

    return haveEqualName && haveEqualXMin && haveEqualXMax && haveEqualYMin && haveEqualYMax;
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

    return [self isEqualToNeighborhood:(Neighborhood *)object];
}

- (NSUInteger)hash
{
    return self.name.hash ^ self.XMin.hash ^ self.XMax.hash ^ self.YMin.hash ^ self.YMax.hash;
}

@end

