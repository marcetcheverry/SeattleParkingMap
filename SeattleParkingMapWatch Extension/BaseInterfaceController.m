//
//  ParkInterfaceController.m
//  SeattleParkingMapWatch Extension
//
//  Created by Marc on 12/14/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

#import "BaseInterfaceController.h"

#import "WKInterfaceController+SPM.h"
#import "UIColor+SPM.h"

@interface BaseInterfaceController ()

@property (weak, nonatomic) IBOutlet WKInterfaceLabel *loadingIndicator;
@property (nonatomic) BOOL loadingIndicatorCancelled;
@property (nonatomic) NSTimer *timerLoadingLabel;
@property (nonatomic) NSUInteger ellipsisCounter;

@end

@implementation BaseInterfaceController : WKInterfaceController

@dynamic extensionDelegate;

- (ExtensionDelegate *)extensionDelegate
{
    return (ExtensionDelegate *)[WKExtension sharedExtension].delegate;
}

- (void)willDisappear
{
    [super willDisappear];
    [self stopLoadingIndicator];
}

- (void)dealloc
{
    [self stopLoadingIndicator];
}

- (IBAction)cancelTouched
{
    if (self.currentOperation)
    {
        self.currentOperation.cancelled = YES;
    }

    [self setLoadingIndicatorHidden:YES
                           animated:YES];
}

- (void)setCurrentOperation:(WatchConnectivityOperation *)currentOperation
{
    if (_currentOperation != currentOperation)
    {
        _currentOperation.cancelled = YES;
        _currentOperation = currentOperation;
    }
}

- (void)setLoadingIndicatorHidden:(BOOL)hidden
{
    self.groupMain.hidden = !hidden;
    self.groupLoading.hidden = hidden;

    if (hidden)
    {
        [self stopLoadingIndicator];
    }
    else
    {
        [self startLoadingIndicator];
    }
}

- (void)setLoadingIndicatorHidden:(BOOL)hidden
                         animated:(BOOL)animated
{
    [self setLoadingIndicatorHidden:hidden];

    [self animateWithDuration:0.3
                   animations:^{
                       self.groupMain.alpha = hidden ? 1 : 0;
                       self.groupLoading.alpha = hidden ? 0 : 1;
                   }];
}

- (void)displayErrorMessage:(nonnull NSString *)errorMessage
{
    [[WKInterfaceDevice currentDevice] playHaptic:WKHapticTypeFailure];

    //    [self presentAlertControllerWithTitle:@"Error"
    //                                  message:errorMessage
    //                           preferredStyle:WKAlertControllerStyleAlert
    //                                  actions:@[[WKAlertAction actionWithTitle:@"OK"
    //                                                                     style:WKAlertActionStyleCancel
    //                                                                   handler:^{
    //                                                                   }]
    //                                            ]];

    [self setLoadingIndicatorHidden:YES
                           animated:YES];
    self.buttonCancel.hidden = YES;

    [self presentAlertControllerWithTitle:nil
                                  message:errorMessage
                           preferredStyle:WKAlertControllerStyleAlert
                                  actions:@[[WKAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                                   style:WKAlertActionStyleCancel
                                                                 handler:^{}]]];
}

- (NSTimeInterval)loadingIndicatorDelay
{
    return 1;
}

- (void)startLoadingIndicator
{
    self.loadingIndicatorCancelled = NO;
    [self.timerLoadingLabel invalidate];

    dispatch_block_t delayedBlock = ^{
        [self startLoadingIndicatorTimer];
    };

    NSTimeInterval delay = [self loadingIndicatorDelay];
    if (delay > 0)
    {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), delayedBlock);
    }
    else
    {
        delayedBlock();
    }
}

- (void)startLoadingIndicatorTimer
{
    if (self.loadingIndicatorCancelled)
    {
        return;
    }

    self.ellipsisCounter = 0;
    self.loadingIndicator.text = @"•\n";

    NSTimeInterval animationInterval = 1/3.;

    [self animateWithDuration:animationInterval / 2.
                   animations:^{
                       self.loadingIndicator.alpha = 1;
                   }];

    [self.timerLoadingLabel invalidate];

    if (self.loadingIndicatorCancelled)
    {
        return;
    }

    self.timerLoadingLabel = [NSTimer timerWithTimeInterval:animationInterval
                                                     target:self
                                                   selector:@selector(updateLoadingLabelTimerFired)
                                                   userInfo:nil
                                                    repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.timerLoadingLabel forMode:NSRunLoopCommonModes];
}

- (void)stopLoadingIndicator
{
    if (self.loadingIndicatorCancelled)
    {
        return;
    }

    self.loadingIndicatorCancelled = YES;
    self.loadingIndicator.text = @"\n";
    [self.timerLoadingLabel invalidate];
    self.timerLoadingLabel = nil;
}

- (void)updateLoadingLabelTimerFired
{
    NSString *loadingIndicatorString;

    switch (self.ellipsisCounter)
    {
        case 0:
            loadingIndicatorString = @"•\n";
            self.ellipsisCounter = 1;
            break;
        case 1:
            loadingIndicatorString = @"••\n";
            self.ellipsisCounter = 2;
            break;
        case 2:
            loadingIndicatorString = @"•••\n";
            self.ellipsisCounter = 3;
            break;
        case 3:
        {
            // Stop the timer and animate
            [self.timerLoadingLabel invalidate];
            self.timerLoadingLabel = nil;

            [self SPMAnimateWithDuration:1/6.
                              animations:^{
                                  self.loadingIndicator.alpha = 0;
                              }
                              completion:^{
                                  [self startLoadingIndicator];
                              }];
            return;
        }
            break;

        default:
            loadingIndicatorString = @"\n";
            break;
    }
    
    self.loadingIndicator.text = loadingIndicatorString;
}

@end
