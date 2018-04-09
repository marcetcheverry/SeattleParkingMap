//
//  TimeLimitViewController.h
//  SeattleParkingMap
//
//  Created by Marc on 12/19/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

@protocol TimeLimitViewControllerDelegate <NSObject>

- (void)setParkingReminderWithLength:(nonnull NSNumber *)length
                   reminderThreshold:(nullable NSNumber *)reminderThreshold
                  fromViewController:(nullable UIViewController *)viewController;

@end

@interface TimeLimitViewController : UIViewController

@property (nullable, weak, nonatomic) id <TimeLimitViewControllerDelegate> delegate;

@end
