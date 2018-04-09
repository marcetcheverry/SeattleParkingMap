//
//  SnapshotTests.m
//  SeattleParkingMapUITests
//
//  Created by Marc on 1/9/16.
//  Copyright © 2016 Tap Light Software. All rights reserved.
//

/*
#import <XCTest/XCTest.h>

#import "SeattleParkingMapUITests-Swift.h"

#import "ParkingManager.h"
#import "ParkingManager.h"
#import "ParkingSpot.h"
#import "ParkingTimeLimit.h"

@interface SnapshotTests : XCTestCase

@end

@implementation SnapshotTests

- (void)setUp
{
    [super setUp];

    XCUIApplication *app = [[XCUIApplication alloc] init];
    [Snapshot setupSnapshot:app];
    [app launch];
}

- (void)testSnapshots
{
    XCUIApplication *app = [[XCUIApplication alloc] init];

    CLLocation *location = [[CLLocation alloc] initWithLatitude:47.613584
                                                      longitude:-122.339480];
    NSDate *parkDate = [NSDate date];
    ParkingSpot *spot = [[ParkingSpot alloc] initWithLocation:location
                                                         date:parkDate];

    ParkingTimeLimit *timeLimit = [[ParkingTimeLimit alloc] initWithStartDate:parkDate
                                                                       length:@(20 * 60)
                                                            reminderThreshold:nil];
    spot.timeLimit = timeLimit;
    [ParkingManager sharedManager].currentSpot = spot;

    [NSUserDefaults.standardUserDefaults synchronize];

    //    [app.buttons[@"Settings"] tap];
    //    [app.tables.segmentedControls.buttons[@"SDOT"] tap];
    //    [app.navigationBars[@"Settings"].buttons[@"Done"] tap];

//    if (app.buttons[@"ParkHere"].hittable)
//    {
//        [app.buttons[@"ParkHere"] tap];
//    }

    if (app.buttons[@"Guide"].hittable)
    {
        [app.buttons[@"Guide"] tap];
    }

    [app.sliders[@"Legend Opacity"] adjustToNormalizedSliderPosition:1];
    //    [app.buttons[@"Current Location"] tap];

    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"test"];

    [self waitForExpectations:@[expectation] timeout:50];

    [Snapshot snapshot:@"Main" timeWaitingForIdle:5];
    //
    //    [app.buttons[@"Settings"] tap];
    //    [app.tables.buttons[@"Bing"] tap];
    //    [app.navigationBars[@"Settings"].buttons[@"Done"] tap];
    //
    //    currentLocationElement = [app.otherElements containingType:XCUIElementTypeButton identifier:@"Current Location"].element;
    //    [currentLocationElement tap];
    //    [app.buttons[@"Guide"] tap];
    //    [app.sliders[@"Legend Opacity"] adjustToNormalizedSliderPosition:1];
    //
    //    [Snapshot snapshot:@"Secondary" waitForLoadingIndicator:YES];
}

@end

*/
