//
//  SeattleParkingMapTests.m
//  SeattleParkingMapTests
//
//  Created by Marc on 1/9/16.
//  Copyright © 2016 Tap Light Software. All rights reserved.
//

#import <XCTest/XCTest.h>

@import CoreLocation;

#import "NSDate+SPM.h"
#import "UIImage+SPM.h"
#import "ParkingTimeLimit.h"

#import "ParkingSpot.h"

#import "Legend.h"
#import "LegendDataSource.h"

#import "NeighborhoodDataSource.h"

#import "ParkingManager.h"

@interface SeattleParkingMapTests : XCTestCase

@end

@implementation SeattleParkingMapTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testDateExtensions
{
    NSDate *date = [NSDate date];
    NSDate *date2 = [date copy];
    NSDate *beforeDate = [date dateByAddingTimeInterval:-1];
    NSDate *afterDate = [date dateByAddingTimeInterval:1];

    XCTAssertTrue([beforeDate SPMIsBeforeDate:date], @"Date should be before");
    XCTAssertTrue([beforeDate SPMIsEqualOrBeforeDate:date], @"Date should be before or equal");
    XCTAssertTrue([date SPMIsEqualOrBeforeDate:date2], @"Date should be before or equal");

    XCTAssertFalse([date SPMIsBeforeDate:beforeDate], @"Date should not be before");
    XCTAssertFalse([date SPMIsEqualOrBeforeDate:beforeDate], @"Date should not be before or equal");

    XCTAssertTrue([afterDate SPMIsAfterDate:date], @"Date should be after");
    XCTAssertTrue([afterDate SPMIsEqualOrAfterDate:date], @"Date should be after or equal");
    XCTAssertTrue([date SPMIsEqualOrAfterDate:date2], @"Date should be after or equal");

    XCTAssertFalse([date SPMIsAfterDate:afterDate], @"Date should be not after");
    XCTAssertFalse([date SPMIsEqualOrAfterDate:afterDate], @"Date should be not after or equal");
}

- (void)testImageExtensions
{
    XCTAssertNotNil([UIImage SPMImageWithColor:[UIColor blackColor]], @"It should produce an image");
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertNil([UIImage SPMImageWithColor:nil], @"It should not produce an image");
#pragma clang diagnostic pop
}

- (void)testParkingSpot
{
    CLLocation *location = [[CLLocation alloc] initWithLatitude:47.649167
                                                      longitude:-122.347687];
    NSDate *parkDate = [NSDate date];
    ParkingSpot *spot = [[ParkingSpot alloc] initWithLocation:location
                                                         date:parkDate];
    XCTAssertTrue([spot wasParkedToday]);

    XCTAssertEqualObjects(spot.date, parkDate);
    XCTAssertEqualObjects(spot.location, location);
    XCTAssert([[spot localizedDateString] length] > 0);

    ParkingSpot *spotCopy = [[ParkingSpot alloc] initWithLocation:location
                                                             date:parkDate];

    XCTAssertEqualObjects(spot, spotCopy);
}

- (void)testParkingSpotSerialization
{
    CLLocation *location = [[CLLocation alloc] initWithLatitude:47.649167
                                                      longitude:-122.347687];
    NSDate *parkDate = [NSDate date];
    ParkingSpot *spot = [[ParkingSpot alloc] initWithLocation:location
                                                         date:parkDate];

    NSDictionary *serialized = [spot watchConnectivityDictionaryRepresentation];
    XCTAssertNotNil(serialized);
    ParkingSpot *reconstructed = [[ParkingSpot alloc] initWithWatchConnectivityDictionary:serialized];
    XCTAssertNotNil(reconstructed);
    XCTAssertEqualObjects(spot, reconstructed);
}

- (void)testNeighborhoodsDataSource
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"loadNeighboorhoodsWithCompletionHandler"];

    NeighborhoodDataSource *dataSource = [[NeighborhoodDataSource alloc] init];
    XCTAssert(dataSource.state == SPMStateUnknown);
    [dataSource loadNeighboorhoodsWithCompletionHandler:^(BOOL success) {
        NSUInteger count = dataSource.neighborhoods.count;
        XCTAssertNil(dataSource.selectedNeighborhood);
        if (success)
        {
            XCTAssert(count > 0);
            XCTAssert(dataSource.state == SPMStateLoaded);
            XCTAssertNotNil(dataSource.alphabeticallySectionedNeighborhoods);
        }
        else
        {
            XCTAssert(count == 0);
            XCTAssert(dataSource.state == SPMStateFailedToLoad);
        }
        XCTAssert(success == YES);
        [expectation fulfill];
    }];

    XCTAssert(dataSource.state == SPMStateLoading);

    [self waitForExpectations:@[expectation]
                      timeout:25];
}

- (void)testParkingTimeLimit
{
    NSDate *startDate = [NSDate date];
    NSNumber *length = @(60 * 10);
    NSNumber *reminder = @(60 * 5);
    ParkingTimeLimit *timeLimit = [[ParkingTimeLimit alloc] initWithStartDate:startDate
                                                                       length:length
                                                            reminderThreshold:reminder];
    XCTAssertNotNil(timeLimit, @"Time Limit should have been created");
    XCTAssertEqualObjects(timeLimit.startDate, startDate);
    XCTAssertEqualObjects(timeLimit.length, length);
    XCTAssertEqualObjects(timeLimit.reminderThreshold, reminder);
    XCTAssertEqualObjects(timeLimit.endDate, [timeLimit.startDate dateByAddingTimeInterval:[timeLimit.length doubleValue]]);
}

- (void)testParkingTimeLimitSerialization
{
    NSDate *startDate = [NSDate date];
    NSNumber *length = @(60 * 10);
    NSNumber *reminder = @(60 * 5);
    ParkingTimeLimit *timeLimit = [[ParkingTimeLimit alloc] initWithStartDate:startDate
                                                                       length:length
                                                            reminderThreshold:reminder];

    NSDictionary *serialized = [timeLimit watchConnectivityDictionaryRepresentation];
    XCTAssertNotNil(serialized);
    ParkingTimeLimit *reconstructed = [[ParkingTimeLimit alloc] initWithWatchConnectivityDictionary:serialized];
    XCTAssertNotNil(reconstructed);
    XCTAssertEqualObjects(timeLimit, reconstructed);
}

- (void)testParkingTimeLimitExpiration
{
    NSNumber *length = @(60 * 10);
    NSNumber *reminder = @(60 * 5);
    NSDate *startDate = [NSDate dateWithTimeIntervalSinceNow:-([length doubleValue] - 5)];

    ParkingTimeLimit *expiringTimeLimit = [[ParkingTimeLimit alloc] initWithStartDate:startDate
                                                                               length:length
                                                                    reminderThreshold:reminder];

    XCTAssertTrue([expiringTimeLimit isExpiring]);

    startDate = [NSDate dateWithTimeIntervalSinceNow:-([length doubleValue] + 5)];
    ParkingTimeLimit *expiredTimeLimit = [[ParkingTimeLimit alloc] initWithStartDate:startDate
                                                                              length:length
                                                                   reminderThreshold:reminder];
    XCTAssertTrue([expiredTimeLimit isExpired]);
}

- (void)testLegendDataSource
{
    LegendDataSource <UITableViewDataSource> *dataSource = (LegendDataSource <UITableViewDataSource> *)[[LegendDataSource alloc] init];

    Legend *legend = [[Legend alloc] init];
    legend.name = @"Test";
    [dataSource addLegend:legend];

    [dataSource sortLegends];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertEqual([dataSource tableView:nil numberOfRowsInSection:0], 1);
#pragma clang diagnostic pop

}

- (void)testLegendDataSourceSynthesize
{
    LegendDataSource <UITableViewDataSource> *dataSource = (LegendDataSource <UITableViewDataSource> *)[[LegendDataSource alloc] init];
    [dataSource synthesizeDefaultLegends];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertEqual([dataSource numberOfSectionsInTableView:nil], 3);
    XCTAssertEqual([dataSource tableView:nil numberOfRowsInSection:0], 3);
    XCTAssertEqual([dataSource tableView:nil numberOfRowsInSection:1], 1);
    XCTAssertEqual([dataSource tableView:nil numberOfRowsInSection:2], 2);
#pragma clang diagnostic pop
}

- (void)testParkingManager
{
    CLLocation *location = [[CLLocation alloc] initWithLatitude:47.649167
                                                      longitude:-122.347687];
    ParkingManager *manager = [ParkingManager sharedManager];
    XCTAssertNotNil(manager);

    AGSPoint *point = [manager pointFromLocation:location];
    XCTAssertNotNil(point);

    CLLocation *locationBack = [manager locationFromAGSPoint:point];
    XCTAssertNotNil(locationBack);

    XCTAssertTrue([location distanceFromLocation:locationBack] < 1);

    NSDate *parkDate = [NSDate date];
    ParkingSpot *spot = [[ParkingSpot alloc] initWithLocation:location
                                                         date:parkDate];
    manager.currentSpot = spot;
    XCTAssertNotNil(manager.currentSpot);
}

- (void)testParkingManagerGeocoding
{
#if !TARGET_OS_SIMULATOR
    ParkingManager *manager = [ParkingManager sharedManager];
    CLLocation *location = [[CLLocation alloc] initWithLatitude:47.649167
                                                      longitude:-122.347687];
    NSDate *parkDate = [NSDate date];
    ParkingSpot *spot = [[ParkingSpot alloc] initWithLocation:location
                                                         date:parkDate];

    [self keyValueObservingExpectationForObject:spot
                                        keyPath:@"address"
                                        handler:^BOOL(id  _Nonnull observedObject, NSDictionary * _Nonnull change) {
                                            if (spot.address.length)
                                            {
                                                NSLog(@"Succesful geocoding of %@", spot.address);
                                                return YES;
                                            }
                                            NSLog(@"Could not geocode %@", spot);
                                            return NO;
                                        }];
    manager.currentSpot = spot;
    [self waitForExpectationsWithTimeout:25
                                 handler:nil];
#endif
}

@end
