//
//  ParkInterfaceController.h
//  SeattleParkingMapWatch Extension
//
//  Created by Marc on 11/15/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

#import "BaseInterfaceController.h"

@interface ParkInterfaceController : BaseInterfaceController

- (void)presentMapInterfaceWithContext:(id)context;
- (void)parkWithNoTimeLimit;

@end
