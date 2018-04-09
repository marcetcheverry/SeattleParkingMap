//
//  SPMBaseInterfaceController.h
//  SeattleParkingMapWatch Extension
//
//  Created by Marc on 12/14/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

@interface SPMBaseInterfaceController : WKInterfaceController

@property (weak, nonatomic) IBOutlet WKInterfaceLabel *labelLoading;
@property (weak, nonatomic) IBOutlet WKInterfaceGroup *groupLoading;
@property (weak, nonatomic) IBOutlet WKInterfaceButton *buttonCancel;
@property (weak, nonatomic) IBOutlet WKInterfaceGroup *groupMain;

@property (nullable, nonatomic) NSMutableDictionary <NSString *, NSNumber *> *currentOperation;

- (nullable SPMExtensionDelegate *)extensionDelegate;
- (IBAction)cancelTouched;

- (void)setLoadingIndicatorHidden:(BOOL)hidden NS_REQUIRES_SUPER;
- (void)setLoadingIndicatorHidden:(BOOL)hidden
                         animated:(BOOL)animated;

- (void)displayErrorMessage:(nonnull NSString *)errorMessage;

- (void)startLoadingIndicator;
- (void)stopLoadingIndicator;

@end
