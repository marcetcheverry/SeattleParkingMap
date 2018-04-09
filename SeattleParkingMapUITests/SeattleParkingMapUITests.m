//
//  SeattleParkingMapUITests.m
//  SeattleParkingMapUITests
//
//  Created by Marc on 1/9/16.
//  Copyright © 2016 Tap Light Software. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface SeattleParkingMapUITests : XCTestCase

@end

@implementation SeattleParkingMapUITests

- (void)setUp
{
    [super setUp];
    
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    // In UI tests it is usually best to stop immediately when a failure occurs.
    self.continueAfterFailure = NO;
    // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
    [[[XCUIApplication alloc] init] launch];
    
    // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testSettingsModal
{
    XCUIApplication *app = [[XCUIApplication alloc] init];
    [app.buttons[@"Settings"] tap];
    XCTAssertEqualObjects(app.navigationBars.element.identifier, @"Settings");
    [app.navigationBars[@"Settings"].buttons[@"Done"] tap];
    XCTAssert(app.navigationBars.count == 0);
}

@end
