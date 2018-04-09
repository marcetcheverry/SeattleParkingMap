//
//  ParkingTimeLimit.m
//  SeattleParkingMap
//
//  Created by Marc on 12/21/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

#import "ParkingTimeLimit.h"

// For UI, what do we consider a warning or urgent for an upcoming time limit arrival
static NSTimeInterval const SPMDefaultsParkingTimeLimitThresholdExpired = 0;
static NSTimeInterval const SPMDefaultsParkingTimeLimitThresholdWarning = 20 * 60;
static NSTimeInterval const SPMDefaultsParkingTimeLimitThresholdUrgent = 10 * 60;

static NSString * const SPMWatchObjectParkingTimeLimitLength = @"SPMWatchObjectParkingTimeLimitLength"; // NSNumber NSTimeInterval
static NSString * const SPMWatchObjectParkingTimeLimitStartDate = @"SPMWatchObjectParkingTimeLimitStartDate"; // NSDate
static NSString * const SPMWatchObjectParkingTimeLimitReminderThreshold = @"SPMWatchObjectParkingTimeLimitReminderThreshold"; // NSNumber

@interface ParkingTimeLimit ()

@property (nonnull, nonatomic, readwrite) NSDate *startDate;
@property (nonnull, nonatomic, readwrite) NSNumber *length;
@property (nonnull, nonatomic, readwrite) NSNumber *reminderThreshold;

@end

@implementation ParkingTimeLimit : NSObject

@dynamic endDate;

- (nullable instancetype)initWithStartDate:(nonnull NSDate *)startDate
                                    length:(nonnull NSNumber *)length
                         reminderThreshold:(nullable NSNumber *)reminderThreshold
{
    self = [super init];
    if (self)
    {
        NSParameterAssert(startDate);
        NSParameterAssert(length);

        if (!startDate || !length)
        {
            return nil;
        }

        NSAssert([length doubleValue] > 0, @"The length must be bigger than 0");
        NSAssert([length doubleValue] >= (SPMDefaultsParkingTimeLimitMinuteInterval * 60), @"Time Interval must be at least 10 minutes");

        if (!reminderThreshold)
        {
            NSTimeInterval defaultThreshold = SPMDefaultsParkingTimeLimitReminderThreshold;

            NSTimeInterval timeInterval = [length doubleValue];
            NSAssert(timeInterval >= (SPMDefaultsParkingTimeLimitMinuteInterval * 60), @"Time Interval must be at least 10 minutes");
            while (timeInterval <= defaultThreshold)
            {
                defaultThreshold /= 2;
            }

            NSAssert(defaultThreshold >= (5 * 60), @"Reminder threshold must be at least 5 minutes");

            if (defaultThreshold < (5 * 60))
            {
                defaultThreshold = 5 * 60;
            }

            reminderThreshold = @(defaultThreshold);
        }

        NSAssert([reminderThreshold doubleValue] < [length doubleValue], @"The reminder threshold must be lower than the length");

        if (!([length doubleValue] > 0) ||
            !([reminderThreshold doubleValue] < [length doubleValue]))
        {
            NSLog(@"Error, attempting to init time limit with length %@ and threshold %@", length, reminderThreshold);
            return nil;
        }

        self.startDate = startDate;
        self.reminderThreshold = reminderThreshold;
        self.length = length;
    }

    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@\nStart Date: %@\nEnd Date: %@\nLength: %@\nReminder Threshold: %@",
            [super description],
            self.startDate,
            self.endDate,
            self.length,
            self.reminderThreshold];
}

- (nonnull NSDate *)endDate
{
    return [self.startDate dateByAddingTimeInterval:[self.length doubleValue]];
}

- (nullable NSString *)localizedEndDateString
{
    return [self.endDate SPMLocalizedRelativeString];
}

- (nullable NSString *)localizedLengthString
{
    NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
    formatter.allowedUnits = NSCalendarUnitHour | NSCalendarUnitMinute;
    formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
    formatter.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorDropAll;
    return [formatter stringFromTimeInterval:[self.length doubleValue]];
}

- (nullable NSString *)localizedExpiredAgoString
{
    if (![self isExpired])
    {
        return nil;
    }

    NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
    formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
    formatter.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorDropAll;
    formatter.allowedUnits = NSCalendarUnitHour | NSCalendarUnitMinute;
    return [formatter stringFromDate:self.endDate
                              toDate:[NSDate date]];
}

- (NSTimeInterval)remainingTimeInterval
{
    return [self.endDate timeIntervalSinceDate:[NSDate date]];
}

- (BOOL)isExpired
{
    NSComparisonResult comparisonResult = [self.endDate compare:[NSDate date]];
    if (comparisonResult == NSOrderedAscending || comparisonResult == NSOrderedSame)
    {
        return YES;
    }

    return NO;
}

- (BOOL)isExpiring
{
    if (self.remainingTimeInterval <= [self timeIntervalForThreshold:SPMParkingTimeLimitThresholdWarning])
    {
        return YES;
    }

    return  NO;
}

- (nonnull NSDate *)dateForThreshold:(SPMParkingTimeLimitThreshold)threshold
{
    return [self.endDate dateByAddingTimeInterval:-[self timeIntervalForThreshold:threshold]];
}

- (NSTimeInterval)timeIntervalForThreshold:(SPMParkingTimeLimitThreshold)threshold
{
    if (threshold == SPMParkingTimeLimitThresholdWarning)
    {
        NSTimeInterval warning = SPMDefaultsParkingTimeLimitThresholdWarning;
        NSTimeInterval length = self.length.doubleValue;
        if (length <= warning)
        {
            warning = length * 0.5;
        }

        NSAssert(warning < length, @"Warning must less than length");
        if (warning >= length)
        {
            warning = SPMDefaultsParkingTimeLimitThresholdWarning;
        }

        return warning;
    }
    else if (threshold == SPMParkingTimeLimitThresholdUrgent)
    {
        NSTimeInterval urgent = SPMDefaultsParkingTimeLimitThresholdUrgent;
        NSTimeInterval length = self.length.doubleValue;
        if (length <= SPMDefaultsParkingTimeLimitThresholdWarning)
        {
            urgent = length * 0.25;
        }

        NSAssert(urgent < length, @"Urgent must less than length");
        if (urgent >= length)
        {
            urgent = SPMDefaultsParkingTimeLimitThresholdWarning;
        }
        
        return urgent;
    }
    else if (threshold == SPMParkingTimeLimitThresholdSafe)
    {
        return [self timeIntervalForThreshold:SPMParkingTimeLimitThresholdWarning] + 1;
    }
    else if (threshold == SPMParkingTimeLimitThresholdExpired)
    {
        return SPMDefaultsParkingTimeLimitThresholdExpired;
    }

    return 0;
}

#pragma mark - Equality

- (BOOL)isEqualToParkingTimeLimit:(ParkingTimeLimit *)timeLimit
{
    if (!timeLimit)
    {
        return NO;
    }

    BOOL haveEqualStartDate = (!self.startDate && !timeLimit.startDate) || [self.startDate isEqualToDate:timeLimit.startDate];
    BOOL haveEqualLength = (!self.length && !timeLimit.length) || [self.length isEqualToNumber:timeLimit.length];
    BOOL haveEqualReminderThreshold = (!self.reminderThreshold && !timeLimit.reminderThreshold) || [self.reminderThreshold isEqualToNumber:timeLimit.reminderThreshold];

    return haveEqualStartDate && haveEqualLength && haveEqualReminderThreshold;
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

    return [self isEqualToParkingTimeLimit:(ParkingTimeLimit *)object];
}

- (NSUInteger)hash
{
    return [self.startDate hash] ^ [self.length hash] ^ [self.reminderThreshold hash];
}

#pragma mark - WatchConnectivitySerialization

- (nullable instancetype)initWithWatchConnectivityDictionary:(nonnull NSDictionary *)dictionary
{
    //    NSParameterAssert(dictionary);

    if (!dictionary)
    {
        return nil;
    }

    return [self initWithStartDate:dictionary[SPMWatchObjectParkingTimeLimitStartDate]
                            length:dictionary[SPMWatchObjectParkingTimeLimitLength]
                 reminderThreshold:dictionary[SPMWatchObjectParkingTimeLimitReminderThreshold]];
}

- (nonnull NSDictionary *)watchConnectivityDictionaryRepresentation
{
    return @{SPMWatchObjectParkingTimeLimitLength: self.length,
             SPMWatchObjectParkingTimeLimitStartDate: self.startDate,
             SPMWatchObjectParkingTimeLimitReminderThreshold: self.reminderThreshold};
}

#pragma mark - Helpers

+ (nonnull NSMutableOrderedSet *)defaultLengthTimeIntervals
{
    return [NSMutableOrderedSet orderedSetWithObjects:@(30 * 60), @(60 * 60), @(120 * 60), nil];
}

+ (void)creationActionPathForParkDate:(nonnull NSDate *)parkDate
                          timeLimitLength:(nonnull NSNumber *)length
                                  handler:(void (^ __nonnull)(SPMParkingTimeLimitSetActionPath actionPath,
                                                              NSString * __nullable alertTitle,
                                                              NSString * __nullable alertMessage))handler
{
    NSParameterAssert(parkDate);
    if (!parkDate)
    {
        return;
    }

    NSParameterAssert(length);
    if (!length)
    {
        return;
    }

    NSParameterAssert(handler);
    if (!handler)
    {
        return;
    }

    // Are we beyond our original park date?
    NSTimeInterval timeIntervalSinceParkDate = [[NSDate date] timeIntervalSinceDate:parkDate];
    if (timeIntervalSinceParkDate > (5 * 60))
    {
        NSTimeInterval timeInterval = [length doubleValue];

        // If we are trying to set a parking date for a time limit that can't be achived, warn the user.
        if (timeIntervalSinceParkDate >= timeInterval)
        {
            NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
            formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
            formatter.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorDropAll;

            NSString *timeString = [formatter stringFromTimeInterval:timeInterval];

            if (timeInterval == (60 * 60))
            {
                timeString = [NSString stringWithFormat:NSLocalizedString(@"%@ has", nil), timeString];
            }
            else
            {
                timeString = [NSString stringWithFormat:NSLocalizedString(@"%@ have", nil), timeString];
            }

            NSString *title = NSLocalizedString(@"Warning", nil);
            NSString *message = [NSString stringWithFormat:NSLocalizedString(@"More than %@ passed since you parked. The time limit will be started from now.", nil), timeString];

            handler(SPMParkingTimeLimitSetActionPathWarn, title, message);
        }
        else
        {
            NSString *title = NSLocalizedString(@"More Than 5 Minutes Passed Since Parking", nil);
            NSString *message = NSLocalizedString(@"Start the time limit from your initial parking time or from now?", nil);
            handler(SPMParkingTimeLimitSetActionPathAsk, title, message);
        }
    }
    else
    {
        handler(SPMParkingTimeLimitSetActionPathSet, nil, nil);
    }
}

@end

@implementation NSDate (SPMParkingTimeLimit)

- (nullable NSString *)SPMLocalizedRelativeString
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.doesRelativeDateFormatting = YES;
    dateFormatter.locale = [NSLocale currentLocale];
    dateFormatter.timeStyle = NSDateFormatterShortStyle;

    NSString *expireDateString;

    if (![[NSCalendar currentCalendar] isDate:self
                              inSameDayAsDate:[NSDate date]])
    {
        dateFormatter.dateStyle = NSDateFormatterShortStyle;
        expireDateString = [dateFormatter stringFromDate:self];
    }
    else
    {
        // Only time, no date
        expireDateString = [NSString stringWithFormat:NSLocalizedString(@"at %@", nil), [dateFormatter stringFromDate:self]];
    }
    
    return expireDateString;
}

@end
