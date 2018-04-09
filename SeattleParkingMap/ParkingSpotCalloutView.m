//
//  ParkingSpotCalloutView.m
//  SeattleParkingMap
//
//  Created by Marc on 12/19/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

#import "ParkingSpotCalloutView.h"

#import "ParkingManager.h"
#import "ParkingSpot.h"
#import "ParkingTimeLimit.h"

#import "UIImage+SPM.h"

@interface ParkingTimeLimit (CalloutView)

+ (nonnull UIColor *)buttonTimeBackgroundColorForThreshold:(SPMParkingTimeLimitThreshold)threshold;
- (nonnull UIColor *)buttonTimeBackgroundColor;
+ (nonnull UIColor *)buttonTimeBackgroundHighlightedColorForThreshold:(SPMParkingTimeLimitThreshold)threshold;
- (nonnull UIColor *)buttonTimeBackgroundHighlightedColor;

@end

@implementation ParkingTimeLimit (CalloutView)

+ (nonnull UIColor *)buttonTimeBackgroundColorForThreshold:(SPMParkingTimeLimitThreshold)threshold
{
    if (threshold == SPMParkingTimeLimitThresholdUrgent ||
        threshold == SPMParkingTimeLimitThresholdExpired)
    {
        // Red
        return [UIColor colorWithRed:1 green:0.149 blue:0 alpha:1];
    }
    else if (threshold == SPMParkingTimeLimitThresholdWarning)
    {
        // Yellow
        return [UIColor colorWithRed:0.927 green:0.688 blue:0.045 alpha:1];
    }

    // Default blue
    return [UIColor colorWithRed:0 green:0.569 blue:1 alpha:1];
}

- (nonnull UIColor *)buttonTimeBackgroundColor
{
    NSTimeInterval timeInterval = [self remainingTimeInterval];

    if (timeInterval <= [self timeIntervalForThreshold:SPMParkingTimeLimitThresholdUrgent])
    {
        return [[self class] buttonTimeBackgroundColorForThreshold:SPMParkingTimeLimitThresholdUrgent];
    }
    else if (timeInterval <= [self timeIntervalForThreshold:SPMParkingTimeLimitThresholdWarning])
    {
        return [[self class] buttonTimeBackgroundColorForThreshold:SPMParkingTimeLimitThresholdWarning];
    }

    return [[self class] buttonTimeBackgroundColorForThreshold:SPMParkingTimeLimitThresholdSafe];
}

+ (nonnull UIColor *)buttonTimeBackgroundHighlightedColorForThreshold:(SPMParkingTimeLimitThreshold)threshold
{
    if (threshold == SPMParkingTimeLimitThresholdUrgent ||
        threshold == SPMParkingTimeLimitThresholdExpired)
    {
        // Red
        return [UIColor colorWithRed:0.751 green:0.099 blue:0 alpha:1];
    }
    else if (threshold == SPMParkingTimeLimitThresholdWarning)
    {
        // Yellow
        return [UIColor colorWithRed:0.933 green:0.644 blue:0.011 alpha:1];
    }

    // Default blue
    return [UIColor colorWithRed:0 green:0.437 blue:0.795 alpha:1];
}

- (nonnull UIColor *)buttonTimeBackgroundHighlightedColor
{
    NSTimeInterval timeInterval = [self remainingTimeInterval];

    if (timeInterval <= [self timeIntervalForThreshold:SPMParkingTimeLimitThresholdUrgent])
    {
        return [[self class] buttonTimeBackgroundHighlightedColorForThreshold:SPMParkingTimeLimitThresholdUrgent];
    }
    else if (timeInterval <= [self timeIntervalForThreshold:SPMParkingTimeLimitThresholdWarning])
    {
        return [[self class] buttonTimeBackgroundHighlightedColorForThreshold:SPMParkingTimeLimitThresholdWarning];
    }

    return [[self class] buttonTimeBackgroundHighlightedColorForThreshold:SPMParkingTimeLimitThresholdSafe];
}

@end

static void *ParkingSpotCalloutViewContext = &ParkingSpotCalloutViewContext;

@interface ParkingSpotCalloutView ()

@property (weak, nonatomic) IBOutlet UIButton *buttonTime;
@property (strong, nonatomic) NSTimer *timerReminder;
@property (strong, nonatomic) NSDateComponentsFormatter *dateComponentsFormatter;

@end

@implementation ParkingSpotCalloutView

@dynamic popoverSourceView;

#pragma mark - View Lifecycle

- (void)awakeFromNib
{
    [super awakeFromNib];

    self.backgroundColor = [UIColor clearColor];

    [self.buttonTime setBackgroundImage:[UIImage SPMImageWithColor:[ParkingTimeLimit buttonTimeBackgroundColorForThreshold:SPMParkingTimeLimitThresholdSafe]]
                               forState:UIControlStateNormal];
    [self.buttonTime setBackgroundImage:[UIImage SPMImageWithColor:[ParkingTimeLimit buttonTimeBackgroundHighlightedColorForThreshold:SPMParkingTimeLimitThresholdSafe]]
                               forState:UIControlStateHighlighted];

    self.buttonTime.titleLabel.adjustsFontSizeToFitWidth = YES;
    if ([self.buttonTime.titleLabel respondsToSelector:@selector(setAllowsDefaultTighteningForTruncation:)])
    {
        self.buttonTime.titleLabel.allowsDefaultTighteningForTruncation = YES;
    }

    self.buttonTime.titleLabel.numberOfLines = 0;
    self.buttonTime.titleLabel.textAlignment = NSTextAlignmentCenter;

    // Non monospace actually looks better in our tight space
    //    self.buttonTime.titleLabel.font = [UIFont monospacedDigitSystemFontOfSize:self.buttonTime.titleLabel.font.pointSize weight:UIFontWeightBold];

    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:self.buttonTime.bounds
                                                   byRoundingCorners:(UIRectCornerBottomLeft|UIRectCornerTopLeft)
                                                         cornerRadii:CGSizeMake(5, 5)];

    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    maskLayer.frame = self.buttonTime.bounds;
    maskLayer.path = maskPath.CGPath;
    self.buttonTime.layer.mask = maskLayer;

    [[ParkingManager sharedManager] addObserver:self
                                     forKeyPath:@"currentSpot.timeLimit"
                                        options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld)
                                        context:ParkingSpotCalloutViewContext];
    [self updateTimeView];
}

- (void)dealloc
{
    [[ParkingManager sharedManager] removeObserver:self
                                        forKeyPath:@"currentSpot.timeLimit"
                                           context:ParkingSpotCalloutViewContext];
    [self.timerReminder invalidate];
}

#pragma mark - Popover

- (UIView *)popoverSourceView
{
    return self.buttonTime;
}

#pragma mark - Notifications

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context == ParkingSpotCalloutViewContext)
    {
        if ([keyPath isEqualToString:@"currentSpot.timeLimit"])
        {
            if (![change[NSKeyValueChangeOldKey] isEqual:change[NSKeyValueChangeNewKey]])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self updateTimeView];
                });
            }
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath
                             ofObject:object
                               change:change
                              context:context];
    }
}

#pragma mark - Interface Actions

- (IBAction)touchedTime:(UIButton *)sender
{
    if (self.timeBlock)
    {
        self.timeBlock();
    }
}

- (IBAction)touchedClose:(UIButton *)sender
{
    if (self.dismissBlock)
    {
        self.dismissBlock();
    }
}

- (void)setButtonTimeBackgroundsForThreshold:(SPMParkingTimeLimitThreshold)threshold
{
    [self.buttonTime setBackgroundImage:[UIImage SPMImageWithColor:[ParkingTimeLimit buttonTimeBackgroundColorForThreshold:threshold]]
                               forState:UIControlStateNormal];
    [self.buttonTime setBackgroundImage:[UIImage SPMImageWithColor:[ParkingTimeLimit buttonTimeBackgroundHighlightedColorForThreshold:threshold]]
                               forState:UIControlStateHighlighted];
}

- (void)updateTimeView
{
    if ([ParkingManager sharedManager].currentSpot.timeLimit)
    {
        if ([[ParkingManager sharedManager].currentSpot.timeLimit isExpired])
        {
            [self setButtonTimeBackgroundsForThreshold:SPMParkingTimeLimitThresholdUrgent];
            [UIView transitionWithView:self.buttonTime
                              duration:.3
                               options:UIViewAnimationOptionTransitionCrossDissolve
                            animations:^{
                                [self.buttonTime setImage:nil
                                                 forState:UIControlStateNormal];
                                [self.buttonTime setTitle:@"⚠️"
                                                 forState:UIControlStateNormal];
                            }
                            completion:nil];
            [self.timerReminder invalidate];
            self.timerReminder = nil;
            self.dateComponentsFormatter = nil;
        }
        else
        {
            if (!self.timerReminder)
            {
                self.timerReminder = [NSTimer timerWithTimeInterval:60
                                                             target:self
                                                           selector:@selector(updateTimeView)
                                                           userInfo:nil
                                                            repeats:YES];
                [[NSRunLoop currentRunLoop] addTimer:self.timerReminder
                                             forMode:NSRunLoopCommonModes];

            }

            if (!self.dateComponentsFormatter)
            {
                self.dateComponentsFormatter = [[NSDateComponentsFormatter alloc] init];
                self.dateComponentsFormatter.allowedUnits = NSCalendarUnitHour | NSCalendarUnitMinute;
                self.dateComponentsFormatter.unitsStyle = NSDateComponentsFormatterUnitsStyleAbbreviated;
                self.dateComponentsFormatter.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorDropAll;
            }

            NSString *title = [self.dateComponentsFormatter stringFromDate:[NSDate date] toDate:[ParkingManager sharedManager].currentSpot.timeLimit.endDate];

            [UIView transitionWithView:self.buttonTime
                              duration:.3
                               options:UIViewAnimationOptionTransitionCrossDissolve
                            animations:^{
                                ParkingTimeLimit *timeLimit = [ParkingManager sharedManager].currentSpot.timeLimit;

                                [self.buttonTime setBackgroundImage:[UIImage SPMImageWithColor:[timeLimit buttonTimeBackgroundColor]]
                                                           forState:UIControlStateNormal];
                                [self.buttonTime setBackgroundImage:[UIImage SPMImageWithColor:[timeLimit buttonTimeBackgroundHighlightedColor]]
                                                           forState:UIControlStateHighlighted];

                                [self.buttonTime setImage:nil
                                                 forState:UIControlStateNormal];
                                [self.buttonTime setTitle:title
                                                 forState:UIControlStateNormal];
                            }
                            completion:nil];
        }
    }
    else
    {
        [UIView transitionWithView:self.buttonTime
                          duration:.3
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
                            [self setButtonTimeBackgroundsForThreshold:SPMParkingTimeLimitThresholdSafe];
                            [self.buttonTime setTitle:nil
                                             forState:UIControlStateNormal];
                            [self.buttonTime setImage:[UIImage imageNamed:@"Time"]
                                             forState:UIControlStateNormal];
                        }
                        completion:nil];

        self.dateComponentsFormatter = nil;
        [self.timerReminder invalidate];
        self.timerReminder = nil;
    }
}

@end
