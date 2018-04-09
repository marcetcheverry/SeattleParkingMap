//
//  SPMInformationTableViewController.m
//  Seattle Parking Map
//
//  Created by Marc Etcheverry on 6/14/14.
//  Copyright (c) 2014 Tap Light Software. All rights reserved.
//

#import "SPMInformationTableViewController.h"

@import MessageUI;

#import <sys/utsname.h>

@interface  SPMInformationTableViewController () <MFMailComposeViewControllerDelegate>
@end

@implementation SPMInformationTableViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    [Flurry logPageView];
    
    [Flurry logEvent:@"Information_viewDidLoad"];
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat height = [super tableView:tableView heightForRowAtIndexPath:indexPath];

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        if (indexPath.section < 8)
        {
            // Approximation for text cells based on the iPhone height since we do not have self sizing table view cells in iOS 7
            height /= 1.4;
        }
    }

    return height;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == (tableView.numberOfSections - 1))
    {
        return [self localizedAppVersionString];
    }

    return [super tableView:tableView titleForHeaderInSection:section];
}

#pragma mark - Actions

// On iOS 8 use an unwind segue?
- (IBAction)doneTouched:(UIBarButtonItem *)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)sdotTouched:(UIButton *)sender
{
    [Flurry logEvent:@"Information_SDOTWebsiteTouched"];

    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://www.seattle.gov/transportation/"]];
}

- (IBAction)seattleParkingMapTouched:(UIButton *)sender
{
    [Flurry logEvent:@"Information_SPMWebsiteTouched"];

    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://web6.seattle.gov/sdot/seattleparkingmap/"]];
}

- (IBAction)arcGISRuntimeTouched:(UIButton *)sender
{
    [Flurry logEvent:@"Information_ArcGISWebsiteTouched"];

    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://developers.arcgis.com/ios/"]];
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

        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        {
            controller.modalPresentationStyle = UIModalPresentationFormSheet;
        }

        [self presentViewController:controller animated:YES completion:nil];
    }
    else
    {
        [Flurry logError:@"Information_ContactTouchedNoMail" message:@"No mail accounts set up" error:nil];
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"No Mail Accounts", nil)
                                                            message:NSLocalizedString(@"Please set up a Mail account in order to send email.", nil)
                                                           delegate:nil
                                                  cancelButtonTitle:nil
                                                  otherButtonTitles:NSLocalizedString(@"OK", nil), nil];
        [alertView show];
    }
}

#pragma mark - MFMailComposeViewControllerDelegate

- (void)mailComposeController:(MFMailComposeViewController *)controller
          didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
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
