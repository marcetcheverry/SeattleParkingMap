//
//  ComplicationController.m
//  SeattleParkingMapWatch Extension
//
//  Created by Marc on 12/27/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

#import "ComplicationController.h"

#import "ParkingSpot+Watch.h"
#import "ParkingTimeLimit.h"

#import "ParkingTimeLimit+Watch.h"
#import "UIColor+SPM.h"
#import "NSDate+SPM.h"

@interface NSDate (SPMComplication)

- (nullable NSString *)SPMLocalizedRelativeDateTimeString;

@end

@implementation NSDate (SPMComplication)

- (nullable NSString *)SPMLocalizedRelativeDateTimeString
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.doesRelativeDateFormatting = YES;
    dateFormatter.locale = [NSLocale currentLocale];
    dateFormatter.timeStyle = NSDateFormatterShortStyle;
    dateFormatter.dateStyle = NSDateFormatterShortStyle;
    return [dateFormatter stringFromDate:self];
}

@end

@interface ParkingTimeLimit (SPMComplication)

- (nullable UIColor *)complicationTintColorAtDate:(nonnull NSDate *)date;
- (BOOL)isExpiringAtDate:(nonnull NSDate *)date;
- (BOOL)isExpiredAtDate:(nonnull NSDate *)date;
- (float)fillFractionAtDate:(nonnull NSDate *)date;

@end

@implementation ParkingTimeLimit (SPMComplication)

- (nullable UIColor *)complicationTintColorAtDate:(nonnull NSDate *)date
{
    NSParameterAssert(date);
    
    if (!date)
    {
        return nil;
    }
    
    NSTimeInterval timeInterval = [self remainingTimeIntervalAtDate:date];
    
    // Expired
    if (timeInterval <= [self timeIntervalForThreshold:SPMParkingTimeLimitThresholdExpired])
    {
        // Yellow
        return [UIColor colorWithRed:0.998 green:0.881 blue:0.001 alpha:1];
    }
    else if (timeInterval <= [self timeIntervalForThreshold:SPMParkingTimeLimitThresholdUrgent])
    {
        // Red
        return [UIColor colorWithRed:1 green:0.132 blue:0 alpha:1];
    }
    else if (timeInterval <= [self timeIntervalForThreshold:SPMParkingTimeLimitThresholdWarning])
    {
        // Yellow
        return [UIColor colorWithRed:0.998 green:0.881 blue:0.001 alpha:1];
    }
    
    return nil;
}

- (BOOL)isExpiringAtDate:(nonnull NSDate *)date
{
    NSParameterAssert(date);
    
    NSComparisonResult comparisonResult = [[self dateForThreshold:SPMParkingTimeLimitThresholdWarning] compare:date];
    if (comparisonResult == NSOrderedAscending || comparisonResult == NSOrderedSame)
    {
        return YES;
    }
    
    return NO;
}

- (BOOL)isExpiredAtDate:(nonnull NSDate *)date
{
    NSParameterAssert(date);
    
    NSComparisonResult comparisonResult = [self.endDate compare:date];
    if (comparisonResult == NSOrderedAscending || comparisonResult == NSOrderedSame)
    {
        return YES;
    }
    
    return NO;
}

- (float)fillFractionAtDate:(NSDate *)date
{
    NSParameterAssert(date);
    
    if (!date)
    {
        return 0;
    }
    
    if ([self isExpiredAtDate:date])
    {
        return 0;
    }
    
    NSTimeInterval length = [self.length doubleValue];
    NSTimeInterval timeInterval = [self.endDate timeIntervalSinceDate:date];
    
    NSAssert(length >= timeInterval, @"Length must always be bigger or equal");
    float fraction = (length - timeInterval) / length;
    fraction = 1.0 - fraction;
    
    //    NSLog(@"Time Limit fraction is %f", fraction);
    NSAssert((fraction >= 0 && fraction <= 1), @"Fraction must be in th renage of 0 to 1");
    
    if (fraction < 0)
    {
        fraction = 0;
    }
    else if (fraction > 1)
    {
        fraction = 1;
    }
    
    return fraction;
}

@end

@interface ComplicationController ()

@property (nullable, nonatomic, readonly) ExtensionDelegate *extensionDelegate;

@end

@implementation ComplicationController

@dynamic extensionDelegate;

- (ExtensionDelegate *)extensionDelegate
{
    return (ExtensionDelegate *)[WKExtension sharedExtension].delegate;
}

#pragma mark - Timeline Configuration

- (void)getTimelineStartDateForComplication:(CLKComplication *)complication withHandler:(void(^)(NSDate * __nullable date))handler
{
    handler([self.extensionDelegate.currentSpot complicationStartDate]);
}

- (void)getTimelineEndDateForComplication:(CLKComplication *)complication withHandler:(void(^)(NSDate * __nullable date))handler
{
    handler([self.extensionDelegate.currentSpot complicationEndDate]);
}

- (void)getSupportedTimeTravelDirectionsForComplication:(CLKComplication *)complication
                                            withHandler:(void(^)(CLKComplicationTimeTravelDirections directions))handler
{
    if (self.extensionDelegate.currentSpot.timeLimit)
    {
        if ([self.extensionDelegate.currentSpot.timeLimit isExpired])
        {
            handler(CLKComplicationTimeTravelDirectionBackward);
        }
        else
        {
            handler(CLKComplicationTimeTravelDirectionBackward | CLKComplicationTimeTravelDirectionForward);
        }
    }
    else
    {
        handler(CLKComplicationTimeTravelDirectionNone);
    }
}

- (void)getPrivacyBehaviorForComplication:(CLKComplication *)complication
                              withHandler:(void(^)(CLKComplicationPrivacyBehavior privacyBehavior))handler
{
    handler(CLKComplicationPrivacyBehaviorShowOnLockScreen);
}

- (void)getTimelineAnimationBehaviorForComplication:(CLKComplication *)complication withHandler:(void(^)(CLKComplicationTimelineAnimationBehavior behavior))handler
{
    handler(CLKComplicationTimelineAnimationBehaviorNever);
}

#pragma mark - Timeline Tests

#ifdef DEBUG

/// This should probably be moved to Unit Tests when watchOS supports them
- (void)assertSpacingInComplicationEntries:(nonnull NSArray <CLKComplicationTimelineEntry *> *)entries
{
    NSParameterAssert(entries);
    
    NSUInteger count = [entries count];
    
    if (!count)
    {
        return;
    }
    
    for (NSUInteger i = 0; i < count; i++)
    {
        NSDate *date = entries[i].date;
        
        if (i < (count - 1))
        {
            NSDate *nextDate = entries[i + 1].date;
            
            if (fabs([date timeIntervalSinceDate:nextDate]) < SPMComplicationEntryInterval)
            {
                SPMLog(@"Date: %@ and %@ are below the minimum spacing threshold", date, nextDate);
                NSAssert(0, @"Date: %@ and %@ are below the minimum spacing threshold", date, nextDate);
                break;
            }
        }
    }
}

- (void)assertComplicationEntriesOrder:(nonnull NSArray <CLKComplicationTimelineEntry *> *)entries
{
    NSParameterAssert(entries);
    
    if (![entries count])
    {
        return;
    }
    
    NSArray *sortedEntries = [entries sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"date"
                                                                                                  ascending:YES]]];
    NSAssert([entries isEqual:sortedEntries], @"Wrong sort order");
}

- (void)assertComplicationEntries:(nonnull NSArray <CLKComplicationTimelineEntry *> *)entries
                     containDates:(nonnull NSArray *)dates
{
    NSParameterAssert(entries);
    NSParameterAssert(dates);
    
    if (![entries count] || ![dates count])
    {
        return;
    }
    
    NSMutableArray *testedDates = [dates mutableCopy];
    
    for (CLKComplicationTimelineEntry *entry in entries)
    {
        for (NSDate *date in dates)
        {
            if ([entry.date isEqualToDate:date])
            {
                [testedDates removeObject:date];
            }
        }
        
        if (![testedDates count])
        {
            break;
        }
    }
    
    NSUInteger testedDatesCount = [testedDates count];
    if (testedDatesCount > 0)
    {
        SPMLog(@"Missing dates: %@", testedDates);
    }
    NSAssert(testedDatesCount == 0, @"We are missing some dates in the complication entries");
}

#endif

#pragma mark - Timeline Population

- (void)getTimelineEntriesForComplication:(CLKComplication *)complication
                               beforeDate:(NSDate *)date
                                    limit:(NSUInteger)limit
                              withHandler:(void(^)(NSArray<CLKComplicationTimelineEntry *> * __nullable entries))handler
{
    //    SPMLog(@"beforeDate: begin timelime entries  %@ - limit %i", date, limit);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSDate *beginDate = [self.extensionDelegate.currentSpot complicationStartDate];
        
        if (!beginDate || [date SPMIsEqualOrBeforeDate:beginDate])
        {
            //            NSLog(@"Not returning anything for beforeDate");
            handler(nil);
            return;
        }
        
        //        NSDateFormatter *debugFormatter = [[NSDateFormatter alloc] init];
        //        debugFormatter.dateStyle = NSDateFormatterShortStyle;
        //        debugFormatter.timeStyle = NSDateFormatterFullStyle;
        
        NSDate *dateToBackwards = date;
        NSDate *complicationEndDate = [self.extensionDelegate.currentSpot.timeLimit endDate];
        if ([date SPMIsEqualOrAfterDate:complicationEndDate])
        {
            dateToBackwards = complicationEndDate;
        }
        
        NSDate *dateWarning = [self.extensionDelegate.currentSpot.timeLimit dateForThreshold:SPMParkingTimeLimitThresholdWarning];
        NSDate *dateUrgent = [self.extensionDelegate.currentSpot.timeLimit dateForThreshold:SPMParkingTimeLimitThresholdUrgent];
        
        // No need for granularity for these as they use relative dates
        if (complication.family == CLKComplicationFamilyModularLarge ||
            complication.family == CLKComplicationFamilyUtilitarianLarge)
        {
            NSArray *dates = @[beginDate,
                               self.extensionDelegate.currentSpot.date,
                               self.extensionDelegate.currentSpot.timeLimit.startDate,
                               dateWarning,
                               dateUrgent,
                               [complicationEndDate dateByAddingTimeInterval:-59],
                               dateToBackwards,
                               [complicationEndDate dateByAddingTimeInterval:60]];
            
            NSMutableArray <CLKComplicationTimelineEntry *> *array = [[NSMutableArray alloc] initWithCapacity:[dates count]];
            
            for (NSDate *entryDate in dates)
            {
                NSComparisonResult result = [entryDate compare:date];
                if (result == NSOrderedDescending || result == NSOrderedSame)
                {
                    continue;
                }
                
                //            SPMLog(@"%f Will return %@", -adjustInterval, [debugFormatter stringFromDate:entryDate]);
                CLKComplicationTemplate *template = [self templateForComplication:complication
                                                                           atDate:entryDate];
                CLKComplicationTimelineEntry *entry = [CLKComplicationTimelineEntry entryWithDate:entryDate
                                                                             complicationTemplate:template];
                [array addObject:entry];
            }
            
            [array sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"date"
                                                                        ascending:YES]]];
            
            //            SPMLog(@"Modular large key dates %@, adjusted for beforeDate: %@: %@", dates, date, [array valueForKey:@"date"]);
#ifdef DEBUG
            [self assertComplicationEntriesOrder:array];
#endif
            handler(array);
            return;
        }
        
        NSTimeInterval spanLength = [dateToBackwards timeIntervalSinceDate:beginDate];
        //        SPMLog(@"%@ (beforeDate) timeIntervalSinceDate %@ (parkDate) = %f", [debugFormatter stringFromDate:dateToBackwards], [debugFormatter stringFromDate:beginDate], spanLength);
        NSAssert(spanLength > 0, @"Span length must be positive");
        NSUInteger adjustedLimit = limit - 1;
        NSTimeInterval interval = spanLength / adjustedLimit;
        
        //        SPMLog(@"Original interval %f limit %lu", interval, (unsigned long)adjustedLimit);
        if (interval < SPMComplicationEntryInterval)
        {
            interval = SPMComplicationEntryInterval;
            adjustedLimit = ceil(spanLength / interval);
            NSAssert(adjustedLimit <= limit, @"Our adjusted limit must not exceed Apple's");
            //            SPMLog(@"Adjusted interval %f limit %lu", interval, (unsigned long)adjustedLimit);
            NSAssert(adjustedLimit > 0, @"We must have at least one");
        }
        
        NSMutableArray <CLKComplicationTimelineEntry *> *array = [[NSMutableArray alloc] initWithCapacity:adjustedLimit];
        
        // Transition anchors. We could probably use a set, but this seems more efficient. WatchOS will ignore any bouding entries less than 60 seconds away. We don't adjust our second intervals based on the position of these transition anchors.
        BOOL dateWarningAdded = NO;
        BOOL dateUrgentAdded = NO;
        
        // This must be from older to newest, otherwise it won't work!
        for (NSUInteger i = adjustedLimit; i > 0; i--)
        {
            NSTimeInterval adjustInterval = i * interval;
            NSDate *entryDate = [dateToBackwards dateByAddingTimeInterval:-adjustInterval];
            
            if (fabs([entryDate timeIntervalSinceDate:dateWarning]) < interval)
            {
                if (dateWarningAdded)
                {
                    continue;
                }
                
                entryDate = dateWarning;
                dateWarningAdded = YES;
            }
            else if (fabs([entryDate timeIntervalSinceDate:dateUrgent]) < interval)
            {
                if (dateUrgentAdded)
                {
                    continue;
                }
                entryDate = dateUrgent;
                dateUrgentAdded = YES;
            }
            
            //            SPMLog(@"%f Will return %@", -adjustInterval, [debugFormatter stringFromDate:entryDate]);
            
            //            SPMLog(@"Adding entry date %@", entryDate);
            NSAssert([entryDate compare:date] == NSOrderedAscending, @"Entry date is after before date");
            
            CLKComplicationTemplate *template = [self templateForComplication:complication
                                                                       atDate:entryDate];
            CLKComplicationTimelineEntry *entry = [CLKComplicationTimelineEntry entryWithDate:entryDate
                                                                         complicationTemplate:template];
            [array addObject:entry];
        }
        
#ifdef DEBUG
        NSMutableArray *datesToTest = [[NSMutableArray alloc] initWithCapacity:3];
        if ([dateWarning SPMIsBeforeDate:date])
        {
            [datesToTest addObject:dateWarning];
            NSAssert(dateWarningAdded, @"The warning date should have been added");
        }
        if ([dateUrgent SPMIsBeforeDate:date])
        {
            [datesToTest addObject:dateUrgent];
            NSAssert(dateUrgentAdded, @"The urgent date should have been added");
        }
#endif
        
        // We already checked that it is before the Apple required date
        if (dateToBackwards == complicationEndDate)
        {
            NSComparisonResult result = [array.lastObject.date compare:dateToBackwards];
            if (result != NSOrderedSame)
            {
                // If it is after, use our end date, not that date
                //                if (result == NSOrderedDescending)
                //                {
                [array removeLastObject];
                //                }
                
                // Final one so we always show the "time expired"
                CLKComplicationTemplate *template = [self templateForComplication:complication
                                                                           atDate:dateToBackwards];
                CLKComplicationTimelineEntry *entry = [CLKComplicationTimelineEntry entryWithDate:dateToBackwards
                                                                             complicationTemplate:template];
                [array addObject:entry];
#ifdef DEBUG
                [datesToTest addObject:dateToBackwards];
#endif
            }
        }
        
        NSAssert([array count] <= adjustedLimit, @"Array must match adjusted limit");
        
#ifdef DEBUG
        [self assertSpacingInComplicationEntries:array];
        [self assertComplicationEntriesOrder:array];
        [self assertComplicationEntries:array
                           containDates:datesToTest];
#endif
        
        NSAssert([[array firstObject].date SPMIsEqualOrBeforeDate:beginDate], @"Oldest date must be on or after our beginDate");
        
        handler(array);
        //        SPMLog(@"beforeDate: end\n\n");
    });
}

- (void)getTimelineEntriesForComplication:(CLKComplication *)complication
                                afterDate:(NSDate *)date
                                    limit:(NSUInteger)limit
                              withHandler:(void(^)(NSArray<CLKComplicationTimelineEntry *> * __nullable entries))handler
{
    //    SPMLog(@"afterDate: begin timelime entries %@ - limit %i", date, limit);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSDate *dateEnd = [self.extensionDelegate.currentSpot.timeLimit endDate];
        
        if (!dateEnd || [date SPMIsEqualOrAfterDate:dateEnd])
        {
            //            SPMLog(@"Not returning anything for afterDate");
            handler(nil);
            return;
        }
        
        //        NSDateFormatter *debugFormatter = [[NSDateFormatter alloc] init];
        //        debugFormatter.dateStyle = NSDateFormatterShortStyle;
        //        debugFormatter.timeStyle = NSDateFormatterFullStyle;
        
        NSDate *dateWarning = [self.extensionDelegate.currentSpot.timeLimit dateForThreshold:SPMParkingTimeLimitThresholdWarning];
        NSDate *dateUrgent = [self.extensionDelegate.currentSpot.timeLimit dateForThreshold:SPMParkingTimeLimitThresholdUrgent];
        
        // No need for granularity for these as they use relative dates
        if (complication.family == CLKComplicationFamilyModularLarge ||
            complication.family == CLKComplicationFamilyUtilitarianLarge)
        {
            NSArray *dates = @[dateWarning,
                               dateUrgent,
                               [dateEnd dateByAddingTimeInterval:-59],
                               dateEnd,
                               [dateEnd dateByAddingTimeInterval:60]
                               ];
            
            NSMutableArray <CLKComplicationTimelineEntry *> *array = [[NSMutableArray alloc] initWithCapacity:[dates count]];
            
            for (NSDate *entryDate in dates)
            {
                NSComparisonResult result = [entryDate compare:date];
                
                if (result == NSOrderedAscending || result == NSOrderedSame)
                {
                    continue;
                }
                
                NSAssert([entryDate compare:date] == NSOrderedDescending, @"Entry date is before start date");
                //            SPMLog(@"%f Will return %@", -adjustInterval, [debugFormatter stringFromDate:entryDate]);
                CLKComplicationTemplate *template = [self templateForComplication:complication
                                                                           atDate:entryDate];
                CLKComplicationTimelineEntry *entry = [CLKComplicationTimelineEntry entryWithDate:entryDate
                                                                             complicationTemplate:template];
                [array addObject:entry];
            }
            
            //            SPMLog(@"Modular large key dates %@, adjusted for afterDate: %@: %@", dates, date, [array valueForKey:@"date"]);
            
#ifdef DEBUG
            [self assertComplicationEntriesOrder:array];
#endif
            if ([array count])
            {
                handler(array);
            }
            else
            {
                handler(nil);
            }
            return;
        }
        
        NSTimeInterval spanLength = [dateEnd timeIntervalSinceDate:date];
        //        SPMLog(@"%@ (afterDate) timeIntervalSinceDate %@ (limit end date) = %f", [debugFormatter stringFromDate:date], [debugFormatter stringFromDate:endDate], spanLength);
        NSAssert(spanLength > 0, @"Span length must be positive");
        
        if (spanLength == 0)
        {
            NSLog(@"Error: Span length is 0");
            handler(nil);
            return;
        }
        
        NSUInteger adjustedLimit = limit;
        NSTimeInterval interval = spanLength / adjustedLimit;
        
        //        SPMLog(@"Original interval %f limit %lu", interval, (unsigned long)adjustedLimit);
        if (interval < SPMComplicationEntryInterval)
        {
            interval = SPMComplicationEntryInterval;
            adjustedLimit = ceil(spanLength / interval);
            
            NSAssert(adjustedLimit <= limit, @"Our adjusted limit must not exceed Apple's");
            if (adjustedLimit > limit)
            {
                adjustedLimit = limit;
            }
            
            NSAssert(adjustedLimit > 0, @"We must have at least one");
            if (adjustedLimit == 0)
            {
                NSLog(@"Error: adjustedLimit is 0");
                handler(nil);
                return;
            }
            
            //            SPMLog(@"Adjusted interval %f limit %lu", interval, (unsigned long)adjustedLimit);
        }
        
        NSMutableArray <CLKComplicationTimelineEntry *> *array = [[NSMutableArray alloc] initWithCapacity:adjustedLimit];
        
        // Transition anchors. We could probably use a set, but this seems more efficient. WatchOS will ignore any bouding entries less than 60 seconds away. We don't adjust our second intervals based on the position of these transition anchors.
        BOOL dateWarningAdded = NO;
        BOOL dateUrgentAdded = NO;
        BOOL dateEndAdded = NO;
        
        NSUInteger index = 0;
        while (index != adjustedLimit)
        {
            index++;
            
            NSTimeInterval adjustInterval = index * interval;
            NSDate *entryDate = [date dateByAddingTimeInterval:adjustInterval];
            
            if (dateWarningAdded && [entryDate isEqualToDate:dateWarning])
            {
                //                SPMLog(@"We already added the warning date!");
                continue;
            }
            
            if (dateUrgentAdded && [entryDate isEqualToDate:dateUrgent])
            {
                //                SPMLog(@"We already added the urgent date!");
                continue;
            }
            
            if (dateEndAdded && [entryDate isEqualToDate:dateEnd])
            {
                //                SPMLog(@"We already added the end date!");
                continue;
            }
            
            BOOL skipEntryDateInsertion = NO;
            // Test case 24 hour time limit. All of these should fall through!
            if (fabs([entryDate timeIntervalSinceDate:dateWarning]) < interval)
            {
                if (!dateWarningAdded)
                {
                    //                    SPMLog(@"%lu Setting dateWarning %@ instead of %@", (unsigned long)index, dateWarning, entryDate);
                    entryDate = dateWarning;
                    dateWarningAdded = YES;
                }
                else
                {
                    //                    SPMLog(@"%lu Will continue for date close to warning: %@", (unsigned long)index, entryDate);
                    skipEntryDateInsertion = YES;
                }
            }
            
            if (fabs([entryDate timeIntervalSinceDate:dateUrgent]) < interval)
            {
                if (![entryDate isEqualToDate:dateWarning])
                {
                    if (!dateUrgentAdded)
                    {
                        //                        SPMLog(@"%lu Setting dateUrgent %@ instead of %@", (unsigned long)index, dateUrgent, entryDate);
                        entryDate = dateUrgent;
                        dateUrgentAdded = YES;
                        skipEntryDateInsertion = NO;
                    }
                    else
                    {
                        //                        SPMLog(@"%lu Will continue for date close to urgent: %@", (unsigned long)index, entryDate);
                        skipEntryDateInsertion = YES;
                    }
                }
            }
            
            if (fabs([entryDate timeIntervalSinceDate:dateEnd]) < interval)
            {
                // This should always be at the end
                if (![entryDate isEqualToDate:dateWarning] &&
                    ![entryDate isEqualToDate:dateUrgent])
                {
                    if (!dateEndAdded)
                    {
                        if (index == adjustedLimit)
                        {
                            //                            SPMLog(@"%lu Setting dateEnd %@ instead of %@", (unsigned long)index, dateEnd, entryDate);
                            entryDate = dateEnd;
                            dateEndAdded = YES;
                            skipEntryDateInsertion = NO;
                        }
                        else
                        {
                            skipEntryDateInsertion = YES;
                            //                    SPMLog(@"Not adding dateEnd yet!");
                        }
                    }
                    else
                    {
                        //                        SPMLog(@"%lu Will continue for date close to end: %@", (unsigned long)index, entryDate);
                        skipEntryDateInsertion = YES;
                    }
                }
            }
            
            if (skipEntryDateInsertion)
            {
                //                SPMLog(@"%lu Continue!", (unsigned long)index);
                continue;
            }
            
            NSAssert([entryDate compare:date] == NSOrderedDescending, @"Entry date is before start date");
            
            if ([entryDate compare:date] != NSOrderedDescending)
            {
                //                SPMLog(@"Entry date %@ is before start date %@, continuing!", entryDate, date);
                continue;
            }
            
            CLKComplicationTemplate *template = [self templateForComplication:complication
                                                                       atDate:entryDate];
            CLKComplicationTimelineEntry *entry = [CLKComplicationTimelineEntry entryWithDate:entryDate
                                                                         complicationTemplate:template];
            [array addObject:entry];
            
            if (entryDate != dateEnd && dateEndAdded)
            {
                NSAssert(0, @"The loop should be done");
            }
        }
        
        CLKComplicationTimelineEntry *lastEntry = array.lastObject;
        if (!dateEndAdded &&
            ![array.lastObject.date SPMIsEqualOrAfterDate:dateEnd])
        {
            // Make sure that we meet our minimum intervals
            if (fabs([dateEnd timeIntervalSinceDate:lastEntry.date]) < SPMComplicationEntryInterval)
            {
                [array removeObject:lastEntry];
            }
            
            // Final one so we always show the "time expired"
            CLKComplicationTemplate *template = [self templateForComplication:complication
                                                                       atDate:dateEnd];
            CLKComplicationTimelineEntry *entry = [CLKComplicationTimelineEntry entryWithDate:dateEnd
                                                                         complicationTemplate:template];
            [array addObject:entry];
            
            dateEndAdded = YES;
        }
        
        //        SPMLog(@"Warning: %@, Urgent: %@, End: %@", dateWarning, dateUrgent, dateEnd);
        
#ifdef DEBUG
        NSMutableArray *datesToTest = [[NSMutableArray alloc] initWithCapacity:3];
        if ([dateWarning SPMIsAfterDate:date])
        {
            [datesToTest addObject:dateWarning];
            NSAssert(dateWarningAdded, @"The warning date should have been added");
        }
        if ([dateUrgent SPMIsAfterDate:date])
        {
            [datesToTest addObject:dateUrgent];
            NSAssert(dateUrgentAdded, @"The urgent date should have been added");
        }
        if ([dateEnd SPMIsAfterDate:date])
        {
            [datesToTest addObject:dateEnd];
            NSAssert(dateEndAdded, @"The end date should have been added");
        }
#endif
        
        NSAssert([array count] <= adjustedLimit, @"Array must match adjusted limit");
        
#ifdef DEBUG
        [self assertSpacingInComplicationEntries:array];
        
        [self assertComplicationEntriesOrder:array];
        
        [self assertComplicationEntries:array
                           containDates:datesToTest];
#endif
        
        handler(array);
        //        SPMLog(@"afterDate: end\n\n");
    });
}

- (void)getCurrentTimelineEntryForComplication:(CLKComplication *)complication
                                   withHandler:(void(^)(CLKComplicationTimelineEntry * __nullable))handler
{
    NSDate *date = [NSDate date];
    CLKComplicationTemplate *entryTemplate = [self templateForComplication:complication
                                                                    atDate:date];
    CLKComplicationTimelineEntry *entry = [CLKComplicationTimelineEntry entryWithDate:date
                                                                 complicationTemplate:entryTemplate];
    
    handler(entry);
}

- (nullable CLKComplicationTemplate *)templateForComplication:(nonnull CLKComplication *)complication
                                                       atDate:(nonnull NSDate *)date;
{
    NSParameterAssert(complication);
    NSParameterAssert(date);
    
    if (!complication || !date)
    {
        return nil;
    }
    
    ParkingSpot *currentSpot = self.extensionDelegate.currentSpot;
    CLKComplicationTemplate *entryTemplate;
    
    if (complication.family == CLKComplicationFamilyModularSmall)
    {
        if (!currentSpot)
        {
            CLKComplicationTemplateModularSmallSimpleImage *template = [[CLKComplicationTemplateModularSmallSimpleImage alloc] init];
            template.imageProvider = [CLKImageProvider imageProviderWithOnePieceImage:[UIImage imageNamed:@"Complication/Modular"]];
            entryTemplate = template;
        }
        else
        {
            if (currentSpot.timeLimit && [date SPMIsEqualOrAfterDate:currentSpot.timeLimit.startDate])
            {
                // Granular should go beyond end date?
                if ([currentSpot.timeLimit isExpiredAtDate:date])
                {
                    CLKComplicationTemplateModularSmallRingText *template = [[CLKComplicationTemplateModularSmallRingText alloc] init];
                    template.textProvider = [CLKSimpleTextProvider textProviderWithText:NSLocalizedString(@"⚠️", nil)];
                    template.tintColor = [currentSpot.timeLimit textColorForThreshold:SPMParkingTimeLimitThresholdExpired];
                    template.fillFraction = [currentSpot.timeLimit fillFractionAtDate:date];
                    entryTemplate = template;
                }
                else
                {
                    CLKComplicationTemplateModularSmallRingText *template = [[CLKComplicationTemplateModularSmallRingText alloc] init];
                    CLKRelativeDateTextProvider *textProvider = [CLKRelativeDateTextProvider textProviderWithDate:currentSpot.timeLimit.endDate
                                                                                                            style:CLKRelativeDateStyleTimer
                                                                                                            units:NSCalendarUnitHour | NSCalendarUnitMinute];
                    template.textProvider = textProvider;
                    
                    UIColor *tintColor = [currentSpot.timeLimit complicationTintColorAtDate:date];
                    if (tintColor)
                    {
                        template.tintColor = tintColor;
                        template.textProvider.tintColor = tintColor;
                    }
                    
                    template.fillFraction = [currentSpot.timeLimit fillFractionAtDate:date];
                    
                    entryTemplate = template;
                }
            }
            else
            {
                CLKComplicationTemplateModularSmallStackText *template = [[CLKComplicationTemplateModularSmallStackText alloc] init];
                template.line1TextProvider = [CLKSimpleTextProvider textProviderWithText:NSLocalizedString(@"Parked", nil)];
                template.line1TextProvider.tintColor = [UIColor SPMWatchTintColor];
                template.line2TextProvider = [CLKTimeTextProvider textProviderWithDate:currentSpot.date];
                template.highlightLine2 = YES;
                entryTemplate = template;
            }
        }
    }
    else if (complication.family == CLKComplicationFamilyModularLarge)
    {
        CLKComplicationTemplateModularLargeStandardBody *template = [[CLKComplicationTemplateModularLargeStandardBody alloc] init];
        
        if (!currentSpot)
        {
            template.headerTextProvider = [CLKSimpleTextProvider textProviderWithText:NSLocalizedString(@"Seattle Parking", nil)];
            
            if (self.extensionDelegate.currentSpot != nil)
            {
                template.body1TextProvider = [CLKSimpleTextProvider textProviderWithText:NSLocalizedString(@"Tap to Open", nil)];
            }
            else
            {
                template.body1TextProvider = [CLKSimpleTextProvider textProviderWithText:NSLocalizedString(@"Tap to Park", nil)];
            }
            template.headerTextProvider.tintColor = [UIColor SPMWatchTintColor];
        }
        else
        {
            if (currentSpot.timeLimit && [date SPMIsEqualOrAfterDate:currentSpot.timeLimit.startDate])
            {
                if ([currentSpot.timeLimit isExpiredAtDate:date])
                {
                    template.headerTextProvider = [CLKSimpleTextProvider textProviderWithText:NSLocalizedString(@"⚠️ Parking Expired", nil)];
                    template.headerTextProvider.tintColor = [currentSpot.timeLimit textColorForThreshold:SPMParkingTimeLimitThresholdExpired];
                    
                    NSTimeInterval timeInterval = fabs([currentSpot.timeLimit.endDate timeIntervalSinceDate:date]);
                    
                    NSCalendarUnit units;
                    if (timeInterval < 60)
                    {
                        units = NSCalendarUnitSecond;
                    }
                    else
                    {
                        units = NSCalendarUnitHour | NSCalendarUnitMinute;
                    }
                    
                    CLKRelativeDateTextProvider *textProvider = [CLKRelativeDateTextProvider textProviderWithDate:currentSpot.timeLimit.endDate
                                                                                                            style:CLKRelativeDateStyleOffset
                                                                                                            units:units];
                    
                    template.body1TextProvider = textProvider;
                    
                    if (currentSpot.address)
                    {
                        template.body2TextProvider = [CLKSimpleTextProvider textProviderWithText:currentSpot.address];
                    }
                }
                else if ([currentSpot.timeLimit isExpiringAtDate:date])
                {
                    template.headerImageProvider = [CLKImageProvider imageProviderWithOnePieceImage:[UIImage imageNamed:@"Complication Runtime/ModularLargeTimeLimit"]];
                    template.headerTextProvider = [CLKSimpleTextProvider textProviderWithText:NSLocalizedString(@"Parking Expiring", nil)];
                    
                    UIColor *tintColor = [currentSpot.timeLimit complicationTintColorAtDate:date];
                    if (tintColor)
                    {
                        template.headerImageProvider.tintColor = tintColor;
                        template.headerTextProvider.tintColor = tintColor;
                    }
                    
                    NSTimeInterval timeInterval = fabs([currentSpot.timeLimit.endDate timeIntervalSinceDate:date]);
                    
                    if (timeInterval == 0)
                    {
                        template.body1TextProvider = [CLKSimpleTextProvider textProviderWithText:NSLocalizedString(@"Now", nil)];
                    }
                    else
                    {
                        NSCalendarUnit units;
                        if (timeInterval < 60)
                        {
                            units = NSCalendarUnitSecond;
                        }
                        else
                        {
                            units = NSCalendarUnitHour | NSCalendarUnitMinute;
                        }
                        CLKRelativeDateTextProvider *textProvider = [CLKRelativeDateTextProvider textProviderWithDate:currentSpot.timeLimit.endDate
                                                                                                                style:CLKRelativeDateStyleNatural
                                                                                                                units:units];
                        
                        template.body1TextProvider = textProvider;
                    }
                    
                    
                    if (currentSpot.address)
                    {
                        template.body2TextProvider = [CLKSimpleTextProvider textProviderWithText:currentSpot.address];
                    }
                }
                else
                {
                    template.headerImageProvider = [CLKImageProvider imageProviderWithOnePieceImage:[UIImage imageNamed:@"Complication Runtime/ModularLargeTimeLimit"]];
                    
                    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                    dateFormatter.doesRelativeDateFormatting = YES;
                    dateFormatter.locale = [NSLocale currentLocale];
                    if ([currentSpot wasParkedToday])
                    {
                        dateFormatter.timeStyle = NSDateFormatterShortStyle;
                        dateFormatter.dateStyle = NSDateFormatterNoStyle;
                        
                        NSString *title = [NSString stringWithFormat:NSLocalizedString(@"Parked %@", nil), [dateFormatter stringFromDate:currentSpot.date]];
                        template.headerTextProvider = [CLKSimpleTextProvider textProviderWithText:title];
                    }
                    else
                    {
                        dateFormatter.timeStyle = NSDateFormatterNoStyle;
                        dateFormatter.dateStyle = NSDateFormatterShortStyle;
                        
                        NSString *title = [NSString stringWithFormat:NSLocalizedString(@"Parked %@", nil), [dateFormatter stringFromDate:currentSpot.date]];
                        template.headerTextProvider = [CLKSimpleTextProvider textProviderWithText:title];
                    }
                    
                    CLKRelativeDateTextProvider *dateProvider = [CLKRelativeDateTextProvider textProviderWithDate:currentSpot.timeLimit.endDate
                                                                                                            style:CLKRelativeDateStyleNatural
                                                                                                            units:NSCalendarUnitHour | NSCalendarUnitMinute];
                    
                    UIColor *tintColor = [currentSpot.timeLimit complicationTintColorAtDate:date];
                    if (tintColor)
                    {
                        template.headerImageProvider.tintColor = tintColor;
                        template.headerTextProvider.tintColor = tintColor;
                        dateProvider.tintColor = tintColor;
                    }
                    else
                    {
                        dateProvider.tintColor = [UIColor whiteColor];
                    }
                    
                    
                    template.body1TextProvider = dateProvider;
                    
                    if (currentSpot.address)
                    {
                        template.body2TextProvider = [CLKSimpleTextProvider textProviderWithText:currentSpot.address];
                    }
                }
            }
            else
            {
                if ([currentSpot wasParkedToday])
                {
                    if (currentSpot.address)
                    {
                        NSString *title = [NSString stringWithFormat:NSLocalizedString(@"Parked %@", nil), [currentSpot localizedDateString]];
                        template.headerTextProvider = [CLKSimpleTextProvider textProviderWithText:title];
                    }
                    else
                    {
                        // So it does not look so empty
                        template.headerTextProvider = [CLKSimpleTextProvider textProviderWithText:NSLocalizedString(@"Parked", nil)];
                        template.body1TextProvider = [CLKSimpleTextProvider textProviderWithText:[currentSpot.date SPMLocalizedRelativeDateTimeString]];
                    }
                }
                else
                {
                    template.headerTextProvider = [CLKSimpleTextProvider textProviderWithText:NSLocalizedString(@"Parked", nil)];
                    template.body1TextProvider = [CLKSimpleTextProvider textProviderWithText:[currentSpot.date SPMLocalizedRelativeDateTimeString]];
                }
                
                if (currentSpot.address)
                {
                    if ([currentSpot wasParkedToday])
                    {
                        template.body1TextProvider = [CLKSimpleTextProvider textProviderWithText:currentSpot.address];
                    }
                    else
                    {
                        template.body2TextProvider = [CLKSimpleTextProvider textProviderWithText:currentSpot.address];
                    }
                }
                
                template.headerTextProvider.tintColor = [UIColor SPMWatchTintColor];
            }
        }
        entryTemplate = template;
    }
    else if (complication.family == CLKComplicationFamilyUtilitarianSmall)
    {
        if (!currentSpot)
        {
            CLKComplicationTemplateUtilitarianSmallSquare *template = [[CLKComplicationTemplateUtilitarianSmallSquare alloc] init];
            template.imageProvider = [CLKImageProvider imageProviderWithOnePieceImage:[UIImage imageNamed:@"Complication/Utilitarian"]];
            entryTemplate = template;
        }
        else
        {
            if (currentSpot.timeLimit && [date SPMIsEqualOrAfterDate:currentSpot.timeLimit.startDate])
            {
                if ([currentSpot.timeLimit isExpiredAtDate:date])
                {
                    CLKComplicationTemplateUtilitarianSmallRingText *template = [[CLKComplicationTemplateUtilitarianSmallRingText alloc] init];
                    template.textProvider = [CLKSimpleTextProvider textProviderWithText:NSLocalizedString(@"⚠️", nil)];
                    template.tintColor = [currentSpot.timeLimit textColorForThreshold:SPMParkingTimeLimitThresholdExpired];
                    template.fillFraction = [currentSpot.timeLimit fillFractionAtDate:date];
                    entryTemplate = template;
                }
                else
                {
                    CLKComplicationTemplateUtilitarianSmallRingText *template = [[CLKComplicationTemplateUtilitarianSmallRingText alloc] init];
                    CLKRelativeDateTextProvider *textProvider = [CLKRelativeDateTextProvider textProviderWithDate:currentSpot.timeLimit.endDate
                                                                                                            style:CLKRelativeDateStyleTimer
                                                                                                            units:NSCalendarUnitHour | NSCalendarUnitMinute];
                    template.textProvider = textProvider;
                    
                    UIColor *tintColor = [currentSpot.timeLimit complicationTintColorAtDate:date];
                    if (tintColor)
                    {
                        template.tintColor = tintColor;
                        template.textProvider.tintColor = tintColor;
                    }
                    
                    template.fillFraction = [currentSpot.timeLimit fillFractionAtDate:date];
                    
                    entryTemplate = template;
                }
            }
            else
            {
                CLKComplicationTemplateUtilitarianSmallFlat *template = [[CLKComplicationTemplateUtilitarianSmallFlat alloc] init];
                template.textProvider = [CLKTimeTextProvider textProviderWithDate:currentSpot.date];
                template.imageProvider = [CLKImageProvider imageProviderWithOnePieceImage:[UIImage imageNamed:@"Complication Runtime/UtilitarianFlat"]];
                entryTemplate = template;
            }
        }
    }
    else if (complication.family == CLKComplicationFamilyUtilitarianLarge)
    {
        CLKComplicationTemplateUtilitarianLargeFlat *template = [[CLKComplicationTemplateUtilitarianLargeFlat alloc] init];
        if (!currentSpot)
        {
            if (self.extensionDelegate.currentSpot != nil)
            {
                template.textProvider = [CLKSimpleTextProvider textProviderWithText:NSLocalizedString(@"Tap to Open", nil)];
            }
            else
            {
                template.textProvider = [CLKSimpleTextProvider textProviderWithText:NSLocalizedString(@"Tap to Park", nil)];
            }
            template.imageProvider = [CLKImageProvider imageProviderWithOnePieceImage:[UIImage imageNamed:@"Complication Runtime/UtilitarianFlat"]];
        }
        else
        {
            if (currentSpot.timeLimit && [date SPMIsEqualOrAfterDate:currentSpot.timeLimit.startDate])
            {
                if ([currentSpot.timeLimit isExpiredAtDate:date])
                {
                    template.textProvider = [CLKSimpleTextProvider textProviderWithText:NSLocalizedString(@"⚠️ Parking Expired", nil)];
                    template.textProvider.tintColor = [currentSpot.timeLimit textColorForThreshold:SPMParkingTimeLimitThresholdExpired];
                }
                else
                {
                    NSTimeInterval timeInterval = fabs([currentSpot.timeLimit.endDate timeIntervalSinceDate:date]);
                    
                    if (timeInterval == 0)
                    {
                        template.textProvider = [CLKSimpleTextProvider textProviderWithText:NSLocalizedString(@"Now", nil)];
                    }
                    else
                    {
                        NSCalendarUnit units;
                        if (timeInterval < 60)
                        {
                            units = NSCalendarUnitSecond;
                        }
                        else
                        {
                            units = NSCalendarUnitHour | NSCalendarUnitMinute;
                        }
                        CLKRelativeDateTextProvider *textProvider = [CLKRelativeDateTextProvider textProviderWithDate:currentSpot.timeLimit.endDate
                                                                                                                style:CLKRelativeDateStyleNatural
                                                                                                                units:units];
                        
                        template.textProvider = textProvider;
                    }
                    template.imageProvider = [CLKImageProvider imageProviderWithOnePieceImage:[UIImage imageNamed:@"Complication Runtime/UtilitarianFlatTimeLimit"]];
                    
                    UIColor *tintColor = [currentSpot.timeLimit complicationTintColorAtDate:date];
                    if (tintColor)
                    {
                        template.textProvider.tintColor = tintColor;
                        template.imageProvider.tintColor = tintColor;
                    }
                }
            }
            else
            {
                if ([currentSpot wasParkedToday])
                {
                    NSString *title = [NSString stringWithFormat:NSLocalizedString(@"Parked %@", nil), [currentSpot localizedDateString]];
                    template.textProvider = [CLKSimpleTextProvider textProviderWithText:title];
                }
                else
                {
                    template.textProvider = [CLKSimpleTextProvider textProviderWithText:[currentSpot.date SPMLocalizedRelativeDateTimeString]];
                    template.imageProvider = [CLKImageProvider imageProviderWithOnePieceImage:[UIImage imageNamed:@"Complication Runtime/UtilitarianFlat"]];
                }
            }
        }
        entryTemplate = template;
    }
    else if (complication.family == CLKComplicationFamilyCircularSmall)
    {
        if (!currentSpot)
        {
            CLKComplicationTemplateCircularSmallSimpleImage *template = [[CLKComplicationTemplateCircularSmallSimpleImage alloc] init];
            template.imageProvider = [CLKImageProvider imageProviderWithOnePieceImage:[UIImage imageNamed:@"Complication/Circular"]];
            entryTemplate = template;
        }
        else
        {
            if (currentSpot.timeLimit && [date SPMIsEqualOrAfterDate:currentSpot.timeLimit.startDate])
            {
                if ([currentSpot.timeLimit isExpiredAtDate:date])
                {
                    CLKComplicationTemplateCircularSmallRingText *template = [[CLKComplicationTemplateCircularSmallRingText alloc] init];
                    template.textProvider = [CLKSimpleTextProvider textProviderWithText:NSLocalizedString(@"⚠️", nil)];
                    template.tintColor = [currentSpot.timeLimit textColorForThreshold:SPMParkingTimeLimitThresholdExpired];
                    template.fillFraction = [currentSpot.timeLimit fillFractionAtDate:date];
                    entryTemplate = template;
                }
                else
                {
                    CLKComplicationTemplateCircularSmallRingText *template = [[CLKComplicationTemplateCircularSmallRingText alloc] init];
                    CLKRelativeDateTextProvider *textProvider = [CLKRelativeDateTextProvider textProviderWithDate:currentSpot.timeLimit.endDate
                                                                                                            style:CLKRelativeDateStyleTimer
                                                                                                            units:NSCalendarUnitHour | NSCalendarUnitMinute];
                    template.textProvider = textProvider;
                    
                    UIColor *tintColor = [currentSpot.timeLimit complicationTintColorAtDate:date];
                    if (tintColor)
                    {
                        template.tintColor = tintColor;
                        template.textProvider.tintColor = tintColor;
                    }
                    
                    template.fillFraction = [currentSpot.timeLimit fillFractionAtDate:date];
                    
                    entryTemplate = template;
                }
            }
            else
            {
                CLKComplicationTemplateCircularSmallStackImage *template = [[CLKComplicationTemplateCircularSmallStackImage alloc] init];
                template.line1ImageProvider =[CLKImageProvider imageProviderWithOnePieceImage:[UIImage imageNamed:@"Complication Runtime/CircularSmall"]];
                template.line2TextProvider = [CLKTimeTextProvider textProviderWithDate:currentSpot.date];
                entryTemplate = template;
            }
        }
    }
    
    return entryTemplate;
}

#pragma mark - Placeholder Templates

- (void)getLocalizableSampleTemplateForComplication:(CLKComplication *)complication
                                        withHandler:(void(^)(CLKComplicationTemplate * __nullable complicationTemplate))handler
{
    CLKComplicationTemplate *template;
    
    if (complication.family == CLKComplicationFamilyModularSmall)
    {
        CLKComplicationTemplateModularSmallSimpleImage *t = [[CLKComplicationTemplateModularSmallSimpleImage alloc] init];
        t.imageProvider = [CLKImageProvider imageProviderWithOnePieceImage:[UIImage imageNamed:@"Complication/Modular"]];
        template = t;
    }
    else if (complication.family == CLKComplicationFamilyModularLarge)
    {
        CLKComplicationTemplateModularLargeStandardBody *t = [[CLKComplicationTemplateModularLargeStandardBody alloc] init];
        t.headerTextProvider = [CLKSimpleTextProvider textProviderWithText:NSLocalizedString(@"Seattle Parking", nil)];
        t.headerTextProvider.tintColor = [UIColor SPMWatchTintColor];
        t.body1TextProvider = [CLKSimpleTextProvider textProviderWithText:NSLocalizedString(@"Loading…", nil)];
        template = t;
    }
    else if (complication.family == CLKComplicationFamilyUtilitarianSmall)
    {
        CLKComplicationTemplateUtilitarianSmallSquare *t = [[CLKComplicationTemplateUtilitarianSmallSquare alloc] init];
        t.imageProvider = [CLKImageProvider imageProviderWithOnePieceImage:[UIImage imageNamed:@"Complication/Utilitarian"]];
        template = t;
    }
    else if (complication.family == CLKComplicationFamilyUtilitarianLarge)
    {
        CLKComplicationTemplateUtilitarianLargeFlat *t = [[CLKComplicationTemplateUtilitarianLargeFlat alloc] init];
        t.textProvider = [CLKSimpleTextProvider textProviderWithText:NSLocalizedString(@"Seattle Parking Map", nil)];
        t.imageProvider = [CLKImageProvider imageProviderWithOnePieceImage:[UIImage imageNamed:@"Complication Runtime/UtilitarianFlat"]];
        template = t;
    }
    else if (complication.family == CLKComplicationFamilyCircularSmall)
    {
        CLKComplicationTemplateCircularSmallSimpleImage *t = [[CLKComplicationTemplateCircularSmallSimpleImage alloc] init];
        t.imageProvider = [CLKImageProvider imageProviderWithOnePieceImage:[UIImage imageNamed:@"Complication/Circular"]];
        template = t;
    }
    
    handler(template);
}

@end
