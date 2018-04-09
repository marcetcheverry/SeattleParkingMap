//
//  SettingsTableViewController.m
//  Seattle Parking Map
//
//  Created by Marc on 6/14/14.
//  Copyright (c) 2014 Tap Light Software. All rights reserved.
//

#import "SettingsTableViewController.h"

@import MessageUI;

#import <sys/utsname.h>

@interface  SettingsTableViewController () <MFMailComposeViewControllerDelegate>

@property (strong, nonatomic) IBOutletCollection(UISegmentedControl) NSArray *segmentedControls;

@property (weak, nonatomic) IBOutlet UISegmentedControl *mapProviderSegmentedControl;
//@property (weak, nonatomic) IBOutlet UISegmentedControl *mapLabelSizeSegmentedControl;
@property (weak, nonatomic) IBOutlet UISegmentedControl *mapResolutionSegmentedControl;

@end

@implementation SettingsTableViewController

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    [Flurry logEvent:@"Information_viewDidLoad"];

    self.mapProviderSegmentedControl.selectedSegmentIndex = [[NSUserDefaults standardUserDefaults] integerForKey:SPMDefaultsSelectedMapProvider];

    if ([[UIScreen mainScreen] scale] < 2)
    {
        self.mapResolutionSegmentedControl.selectedSegmentIndex = 0;
        self.mapResolutionSegmentedControl.enabled = NO;
    }
    else
    {
        BOOL renderMapsAtNativeResolution = [[NSUserDefaults standardUserDefaults] boolForKey:SPMDefaultsRenderMapsAtNativeResolution];

        if (renderMapsAtNativeResolution)
        {
            self.mapResolutionSegmentedControl.selectedSegmentIndex = 1;
        }
        else
        {
            self.mapResolutionSegmentedControl.selectedSegmentIndex = 0;
        }
    }
    //
    //    BOOL renderLabelsAtNativeResolution = [[NSUserDefaults standardUserDefaults] boolForKey:SPMDefaultsRenderLabelsAtNativeResolution];
    //
    //    if (renderLabelsAtNativeResolution)
    //    {
    //        self.mapLabelSizeSegmentedControl.selectedSegmentIndex = 0;
    //    }
    //    else
    //    {
    //        self.mapLabelSizeSegmentedControl.selectedSegmentIndex = 1;
    //    }
    //
    for (UISegmentedControl *segmentedControl in self.segmentedControls)
    {
        segmentedControl.backgroundColor = [segmentedControl.tintColor colorWithAlphaComponent:.1];

        NSDictionary *titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor whiteColor]};
        [segmentedControl setTitleTextAttributes:titleTextAttributes
                                        forState:UIControlStateNormal];
        [segmentedControl setTitleTextAttributes:titleTextAttributes
                                        forState:UIControlStateSelected];
    }

    self.tableView.estimatedRowHeight = 100;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    [self.tableView reloadData];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll; // rotate upside down on the iPhone for car users
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewAutomaticDimension;
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 2)
    {
        return [self localizedAppVersionString];
    }

    return [super tableView:tableView titleForHeaderInSection:section];
}

#pragma mark - Actions

- (IBAction)mapProviderSegmentedControlValueChanged:(UISegmentedControl *)sender
{
    [[NSUserDefaults standardUserDefaults] setInteger:sender.selectedSegmentIndex
                                               forKey:SPMDefaultsSelectedMapProvider];
}

//- (IBAction)mapLabelSizeSegmentedControlValueChanged:(UISegmentedControl *)sender
//{
//    // Flipped, big labels = non native
//    BOOL renderLabelsAtNativeResolution = YES;
//
//    if (sender.selectedSegmentIndex == 1)
//    {
//        renderLabelsAtNativeResolution = NO;
//    }
//
//
//    [[NSUserDefaults standardUserDefaults] setBool:renderLabelsAtNativeResolution
//                                            forKey:SPMDefaultsRenderLabelsAtNativeResolution];
//}

- (IBAction)mapResolutionSegmentedControlValueChanged:(UISegmentedControl *)sender
{
    BOOL renderMapsAtNativeResolution = NO;

    if (sender.selectedSegmentIndex == 1)
    {
        renderMapsAtNativeResolution = YES;
    }

    [[NSUserDefaults standardUserDefaults] setBool:renderMapsAtNativeResolution
                                            forKey:SPMDefaultsRenderMapsAtNativeResolution];

}

- (IBAction)sdotTouched:(UIButton *)sender
{
    [Flurry logEvent:@"Information_SDOTWebsiteTouched"];

    NSURL *URL = [NSURL URLWithString:@"http://www.seattle.gov/transportation/"];
    if (URL)
    {
        [[UIApplication sharedApplication] openURL:URL];
    }
}

- (IBAction)seattleParkingMapTouched:(UIButton *)sender
{
    [Flurry logEvent:@"Information_SPMWebsiteTouched"];

    NSURL *URL = [NSURL URLWithString:@"http://web6.seattle.gov/sdot/seattleparkingmap/"];
    if (URL)
    {
        [[UIApplication sharedApplication] openURL:URL];
    }

}

- (IBAction)arcGISRuntimeTouched:(UIButton *)sender
{
    [Flurry logEvent:@"Information_ArcGISWebsiteTouched"];

    NSURL *URL = [NSURL URLWithString:@"http://developers.arcgis.com/ios/"];
    if (URL)
    {
        [[UIApplication sharedApplication] openURL:URL];
    }
}

- (NSString *)localizedAppVersionString
{
    return [NSString stringWithFormat:NSLocalizedString(@"Seattle Parking Map %@", nil), [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]];
}

- (IBAction)contactTouched:(UIButton *)sender
{
    if ([MFMailComposeViewController canSendMail])
    {
        [Flurry logEvent:@"Information_ContactTouched"];

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
        [Flurry logError:@"Information_ContactTouchedNoMail" message:@"No mail accounts set up" error:nil];

        UIAlertController *controller = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"No Mail Accounts", nil)
                                                                            message:NSLocalizedString(@"Please set up a Mail account in order to send email.", nil)
                                                                     preferredStyle:UIAlertControllerStyleAlert];
        [controller addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                       style:UIAlertActionStyleCancel
                                                     handler:nil]];

        [self presentViewController:controller animated:YES completion:nil];
    }
}

#pragma mark - MFMailComposeViewControllerDelegate

- (void)mailComposeController:(MFMailComposeViewController *)controller
          didFinishWithResult:(MFMailComposeResult)result error:(nullable NSError *)error
{
    if (error)
    {
        [Flurry logError:@"Information_ContactTouchedEmailFinished" message:@"MessageUI framework finished with error" error:error];
    }
    
    [self dismissViewControllerAnimated:YES completion:^{
        [self becomeFirstResponder];
    }];
}

@end
