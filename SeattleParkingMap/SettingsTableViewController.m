//
//  SettingsTableViewController.m
//  Seattle Parking Map
//
//  Created by Marc on 6/14/14.
//  Copyright (c) 2014 Tap Light Software. All rights reserved.
//

#import "SettingsTableViewController.h"

#import "Analytics.h"

@import MessageUI;

#import <sys/utsname.h>

@interface SettingsTableViewController () <MFMailComposeViewControllerDelegate>

@property (strong, nonatomic) IBOutletCollection(UISegmentedControl) NSArray *segmentedControls;

@property (weak, nonatomic) IBOutlet UISegmentedControl *mapProviderSegmentedControl;
@property (weak, nonatomic) IBOutlet UISegmentedControl *mapStyleSegmentedControl;

@end

@implementation SettingsTableViewController

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [Analytics logEvent:@"Information_viewDidLoad"];
    
    self.mapProviderSegmentedControl.selectedSegmentIndex = [[NSUserDefaults standardUserDefaults] integerForKey:SPMDefaultsSelectedMapProvider];
    self.mapStyleSegmentedControl.selectedSegmentIndex = [[NSUserDefaults standardUserDefaults] integerForKey:SPMDefaultsSelectedMapType];

    for (UISegmentedControl *segmentedControl in self.segmentedControls)
    {
        segmentedControl.backgroundColor = [segmentedControl.tintColor colorWithAlphaComponent:.1];
        
        NSDictionary *titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor whiteColor]};
        [segmentedControl setTitleTextAttributes:titleTextAttributes
                                        forState:UIControlStateNormal];
        [segmentedControl setTitleTextAttributes:titleTextAttributes
                                        forState:UIControlStateSelected];
    }
}

#pragma mark - UITableViewDelegate

- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 3)
    {
        return [self localizedAppVersionString];
    }
    
    return [super tableView:tableView titleForHeaderInSection:section];
}

- (NSString *)localizedAppVersionString
{
    return [NSString stringWithFormat:NSLocalizedString(@"Seattle Parking Map %@", nil), [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]];
}

- (IBAction)contactTouched:(UIButton *)sender
{
    if ([MFMailComposeViewController canSendMail])
    {
        [Analytics logEvent:@"Information_ContactTouched"];
        
        struct utsname systemInfo;
        uname(&systemInfo);
        
        NSString *deviceModel = [NSString stringWithCString:systemInfo.machine
                                                   encoding:NSUTF8StringEncoding];
        
        MFMailComposeViewController *controller = [[MFMailComposeViewController alloc] init];
        //        controller.navigationBar.barStyle = self.navigationController.navigationBar.barStyle;
        [controller setMailComposeDelegate:self];
        [controller setSubject:[NSString stringWithFormat:NSLocalizedString(@"%@ feedback", @"Feedback mail subject"), [self localizedAppVersionString]]];
        [controller setToRecipients:[NSArray arrayWithObject:NSLocalizedString(@"feedback@taplightsoftware.com", @"Feedback email address")]];
        NSString *messageBody = [NSString stringWithFormat:NSLocalizedString(@"System: %@ (%@)\n\n", @"Email body system version header"), deviceModel, [[UIDevice currentDevice] systemVersion]];
        [controller setMessageBody:messageBody isHTML:NO];
        controller.modalPresentationStyle = UIModalPresentationFormSheet;
        [self presentViewController:controller animated:YES completion:nil];
    }
    else
    {
        [Analytics logError:@"Information_ContactTouchedNoMail" message:@"No mail accounts set up" error:nil];
        
        UIAlertController *controller = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"No Mail Accounts", nil)
                                                                            message:NSLocalizedString(@"Please set up a Mail account in order to send email.", nil)
                                                                     preferredStyle:UIAlertControllerStyleAlert];
        [controller addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                       style:UIAlertActionStyleCancel
                                                     handler:nil]];
        
        [self presentViewController:controller animated:YES completion:nil];
    }
}

#pragma mark - Actions

- (IBAction)mapProviderSegmentedControlValueChanged:(UISegmentedControl *)sender
{
    [[NSUserDefaults standardUserDefaults] setInteger:sender.selectedSegmentIndex
                                               forKey:SPMDefaultsSelectedMapProvider];
}

- (IBAction)mapStyleSegmentedControlValueChanged:(UISegmentedControl *)sender
{
    [[NSUserDefaults standardUserDefaults] setInteger:sender.selectedSegmentIndex
                                               forKey:SPMDefaultsSelectedMapType];
}

#pragma mark - MFMailComposeViewControllerDelegate

- (void)mailComposeController:(MFMailComposeViewController *)controller
          didFinishWithResult:(MFMailComposeResult)result error:(nullable NSError *)error
{
    if (error)
    {
        [Analytics logError:@"Information_ContactTouchedEmailFinished" message:@"MessageUI framework finished with error" error:error];
    }
    
    [self dismissViewControllerAnimated:YES completion:^{
        [self becomeFirstResponder];
    }];
}

@end
