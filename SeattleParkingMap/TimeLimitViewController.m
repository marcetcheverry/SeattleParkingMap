//
//  TimeLimitViewController.m
//  SeattleParkingMap
//
//  Created by Marc on 12/19/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

#import "TimeLimitViewController.h"

#import "ParkingManager.h"

@interface TimeLimitViewController ()

@property (weak, nonatomic) IBOutlet UIDatePicker *datePicker;
@property (weak, nonatomic) IBOutlet UILabel *labelRemindMe;
@property (weak, nonatomic) IBOutlet UIStepper *stepper;

@end

@implementation TimeLimitViewController

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self.datePicker setValue:UIColor.whiteColor forKey:@"textColor"];

    self.datePicker.minuteInterval = SPMDefaultsParkingTimeLimitMinuteInterval;

    self.labelRemindMe.font = [UIFont monospacedDigitSystemFontOfSize:self.labelRemindMe.font.pointSize
                                                               weight:UIFontWeightRegular];

    // For a strange UIDatePicker bug
    // http://stackoverflow.com/questions/20181980/uidatepicker-bug-uicontroleventvaluechanged-after-hitting-minimum-internal
    dispatch_async(dispatch_get_main_queue(), ^{
        self.datePicker.countDownDuration = [[ParkingManager sharedManager].userDefinedParkingTimeLimit doubleValue];

        NSNumber *reminderThreshold = [[NSUserDefaults standardUserDefaults] objectForKey:SPMDefaultsLastParkingTimeLimitReminderThreshold];
        if (!reminderThreshold)
        {
            reminderThreshold = @(SPMDefaultsParkingTimeLimitReminderThreshold);
        }

        NSTimeInterval reminderThresholdInterval = [reminderThreshold doubleValue];

        self.stepper.value = reminderThresholdInterval / 60;
        [self updateLabelRemindMeWithInterval:reminderThresholdInterval];
        [self setStepperMaximumValueBasedOnCountDownDuration:self.datePicker.countDownDuration];
    });
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll; // rotate upside down on the iPhone for car users
}

#pragma mark - Interface Actions

- (void)setStepperMaximumValueBasedOnCountDownDuration:(NSTimeInterval)countDownDuration
{
    double stepperMaximumValue = countDownDuration / 60;

    if (stepperMaximumValue > 60)
    {
        stepperMaximumValue = (floor(stepperMaximumValue / 60) * 60);
        if (stepperMaximumValue > 60)
        {
            stepperMaximumValue -= 60;
        }
    }
    else
    {
        stepperMaximumValue -= 5;
    }

    self.stepper.maximumValue = stepperMaximumValue;

    if (self.stepper.value >= self.stepper.maximumValue)
    {
        self.stepper.value = self.stepper.maximumValue;
        [self.stepper sendActionsForControlEvents:UIControlEventValueChanged];
    }
}

- (void)updateLabelRemindMeWithInterval:(NSTimeInterval)interval
{
    NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
    formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
    formatter.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorDropAll;
    self.labelRemindMe.text = [NSString stringWithFormat:NSLocalizedString(@"%@ before", nil), [formatter stringFromTimeInterval:interval]];
}

- (IBAction)stepperValueChanged:(UIStepper *)sender
{
    if (sender.value > 60)
    {
        // Handle the initial 1 hour + 5 minutes step over
        double remainder = fmod(sender.value, 60);
        if (remainder > 0)
        {
            sender.value = (sender.value - remainder) + 60;
        }
        sender.stepValue = 60;
    }
    else
    {
        sender.stepValue = 5;
    }

    NSAssert(sender.value >= 5, @"Stepper value is invalid");

    [self updateLabelRemindMeWithInterval:sender.value * 60];
}

- (IBAction)datePickerValueChanged:(UIDatePicker *)sender
{
    // For an iOS bug (present on 9) in which the stepper does not send the value change the second time
    // Test case: switch from 2:00 to 0:00, then try to switch back to 2, this won't get called
    if (sender.countDownDuration == (sender.minuteInterval * 60))
    {
        sender.countDownDuration = sender.countDownDuration;
    }

    if (sender.countDownDuration < (self.stepper.value * 60))
    {
        self.stepper.value = sender.countDownDuration;
        [self.stepper sendActionsForControlEvents:UIControlEventValueChanged];
    }

    [self setStepperMaximumValueBasedOnCountDownDuration:sender.countDownDuration];
}

- (IBAction)touchedSet:(UIButton *)sender
{
    [ParkingManager sharedManager].userDefinedParkingTimeLimit = @(self.datePicker.countDownDuration);

    [self.delegate setParkingReminderWithLength:@(self.datePicker.countDownDuration)
                              reminderThreshold:@(self.stepper.value * 60)
                             fromViewController:self];
}

@end
