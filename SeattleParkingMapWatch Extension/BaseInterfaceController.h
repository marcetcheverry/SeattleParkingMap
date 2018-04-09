//
//  BaseInterfaceController.h
//  SeattleParkingMapWatch Extension
//
//  Created by Marc on 12/14/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

#import "WatchConnectivityOperation.h"

NS_ASSUME_NONNULL_BEGIN

@interface BaseInterfaceController : WKInterfaceController

@property (weak, nonatomic) IBOutlet WKInterfaceLabel *labelLoading;
@property (weak, nonatomic) IBOutlet WKInterfaceGroup *groupLoading;
@property (weak, nonatomic) IBOutlet WKInterfaceButton *buttonCancel;
@property (weak, nonatomic) IBOutlet WKInterfaceGroup *groupMain;

@property (nullable, nonatomic) NSString *currentlyDisplayedWarningMessage;

@property (nullable, nonatomic) WatchConnectivityOperation *currentOperation;
@property (nullable, nonatomic, readonly) ExtensionDelegate *extensionDelegate;

- (IBAction)cancelTouched;

- (NSTimeInterval)loadingIndicatorDelay;
- (void)setLoadingIndicatorHidden:(BOOL)hidden NS_REQUIRES_SUPER;
- (void)setLoadingIndicatorHidden:(BOOL)hidden
                         animated:(BOOL)animated;

- (void)displayErrorMessage:(NSString *)errorMessage;
- (void)displayErrorMessage:(NSString *)errorMessage
       hideLoadingIndicator:(BOOL)hideLoadingIndicator
           dismissalHandler:(WKAlertActionHandler)dismissalHandler;

- (void)startLoadingIndicator;
- (void)stopLoadingIndicator;

@end

NS_ASSUME_NONNULL_END
