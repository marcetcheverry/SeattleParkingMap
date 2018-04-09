//
//  ParkingManager.m
//  SeattleParkingMap
//
//  Created by Marc on 12/21/15.
//  Copyright © 2015 Tap Light Software. All rights reserved.
//

#import "ParkingManager.h"

#import "ParkingSpot.h"
#import "ParkingTimeLimit.h"

#import "NSDate+SPM.h"

static void *ParkingManagerContext = &ParkingManagerContext;

@interface ParkingManager ()

@property (nonatomic, nullable) CLGeocoder *geocoder;

@end

@implementation ParkingManager

@dynamic userDefinedParkingTimeLimit;

+ (instancetype)sharedManager
{
    static ParkingManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[ParkingManager alloc] init];
    });
    return sharedManager;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidFinishLaunching:)
                                                     name:UIApplicationDidFinishLaunchingNotification
                                                   object:[UIApplication sharedApplication]];

        _currentSpot = [self parkingSpotFromUserDefaults];
        
        [self addObserver:self
                       forKeyPath:@"currentSpot.timeLimit"
                          options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld)
                          context:ParkingManagerContext];
        [self geocodeCurrentSpot];
        [self updateQuickActions];
    }
    return self;
}

- (void)dealloc
{
    [self removeObserver:self
                      forKeyPath:@"currentSpot.timeLimit"
                         context:ParkingManagerContext];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidFinishLaunchingNotification
                                                  object:[UIApplication sharedApplication]];
}

#pragma mark - Notifications

- (void)applicationDidFinishLaunching:(NSNotification *)notificiation
{
    [self updateQuickActions];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context == ParkingManagerContext)
    {
        if ([keyPath isEqualToString:@"currentSpot.timeLimit"])
        {
            if (![change[NSKeyValueChangeOldKey] isEqual:change[NSKeyValueChangeNewKey]])
            {
                [self setParkingTimeLimitOnUserDefaults:self.currentSpot.timeLimit];
                if (!self.currentSpot.timeLimit)
                {
                    [[UIApplication sharedApplication] cancelAllLocalNotifications];
                }
                else
                {
                    NSAssert([self.currentSpot.timeLimit.startDate SPMIsEqualOrAfterDate:self.currentSpot.date], @"The time limit start date must be equal or after");

                    if ([UIApplication sharedApplication].currentUserNotificationSettings.types != UIUserNotificationTypeNone)
                    {
                        [self scheduleTimeLimitNotifications];
                    }
                    else
                    {
                        UIUserNotificationType notificationTypes = UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound;

                        UIMutableUserNotificationCategory *notificationCategory = [[UIMutableUserNotificationCategory alloc] init];
                        notificationCategory.identifier = SPMNotificationCategoryTimeLimit;

                        UIMutableUserNotificationAction *actionRemoveSpot = [[UIMutableUserNotificationAction alloc] init];
                        actionRemoveSpot.identifier = SPMNotificationActionRemoveSpot;
                        actionRemoveSpot.title = NSLocalizedString(@"Remove Spot", nil);
                        actionRemoveSpot.destructive = YES;
                        actionRemoveSpot.activationMode = UIUserNotificationActivationModeBackground;
                        actionRemoveSpot.authenticationRequired = NO;

                        [notificationCategory setActions:@[actionRemoveSpot]
                                              forContext:UIUserNotificationActionContextDefault];

                        // Since "Remove Parking Spot" looks bad on notification center
                        //            UIMutableUserNotificationAction *actionRemoveSpotMinimal = [actionRemoveSpot mutableCopy];
                        //            actionRemoveSpot.title = NSLocalizedString(@"Remove Spot", nil);
                        //            [notificationCategory setActions:@[actionRemoveSpotMinimal]
                        //                                  forContext:UIUserNotificationActionContextMinimal];

                        NSSet *notificationCategories = [NSSet setWithObject:notificationCategory];
                        UIUserNotificationSettings *notificationSettings = [UIUserNotificationSettings settingsForTypes:notificationTypes
                                                                                                             categories:notificationCategories];
                        
                        [[UIApplication sharedApplication] registerUserNotificationSettings:notificationSettings];
                    }
                }
            }
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath
                             ofObject:object
                               change:change
                              context:context];
    }
}

#pragma mark - ArcGIS Support

- (nullable CLLocation *)locationFromAGSPoint:(nonnull AGSPoint *)parkingPoint
{
    NSParameterAssert(parkingPoint);

    if (!parkingPoint)
    {
        return nil;
    }

    // WGS_1984_Web_Mercator_Auxiliary_Sphere
    // 102100 is a Mercator projection in meters, where WGS-84 is in decimal degrees (4326)

    AGSGeometryEngine *engine = [AGSGeometryEngine defaultGeometryEngine];
    AGSPoint *coreLocationPoint = (AGSPoint *)[engine projectGeometry:parkingPoint
                                                   toSpatialReference:[AGSSpatialReference wgs84SpatialReference]];

    CLLocation *location = [[CLLocation alloc] initWithLatitude:coreLocationPoint.y
                                                      longitude:coreLocationPoint.x];
    return location;
}

- (nullable CLLocation *)locationFromAGSPointJSON:(nonnull id)JSON
{
    NSParameterAssert(JSON);
    if (!JSON)
    {
        return nil;
    }

    AGSPoint *parkingPoint = (AGSPoint *)AGSGeometryWithJSON(JSON);
    if (parkingPoint)
    {
        return [self locationFromAGSPoint:parkingPoint];
    }

    return nil;
}

/// In SPMSpatialReferenceWKIDSDOT
- (nullable AGSPoint *)pointFromLocation:(nonnull CLLocation *)location
{
    NSParameterAssert(location);
    if (!location)
    {
        return nil;
    }

    AGSGeometryEngine *engine = [AGSGeometryEngine defaultGeometryEngine];

    AGSPoint *point = [AGSPoint pointWithX:location.coordinate.longitude
                                         y:location.coordinate.latitude
                          spatialReference:[AGSSpatialReference wgs84SpatialReference]];

    AGSSpatialReference *spatialReference = [AGSSpatialReference spatialReferenceWithWKID:SPMSpatialReferenceWKIDSDOT];
    return (AGSPoint *)[engine projectGeometry:point
                            toSpatialReference:spatialReference];
}

#pragma mark - NSUserDefaults

- (nullable ParkingSpot *)parkingSpotFromUserDefaults
{
    NSDictionary *serializedParkingPoint = [[NSUserDefaults standardUserDefaults] objectForKey:SPMDefaultsLastParkingPoint];
    if (serializedParkingPoint)
    {
        CLLocation *parkingLocation = [self locationFromAGSPointJSON:serializedParkingPoint];

        if (parkingLocation)
        {
            NSDate *date = [[NSUserDefaults standardUserDefaults] objectForKey:SPMDefaultsLastParkingDate];
            if (date)
            {
                ParkingSpot *parkingSpot = [[ParkingSpot alloc] initWithLocation:parkingLocation
                                                                            date:date];
                parkingSpot.timeLimit = [self parkingTimeLimitFromUserDefaults];
                parkingSpot.address = [[NSUserDefaults standardUserDefaults] stringForKey:SPMDefaultsLastParkingAddress];
                return parkingSpot;
            }
        }
    }
    else
    {
        // Assure that our data store is sane, this has happened before when we could not serialize our point
        NSAssert([[NSUserDefaults standardUserDefaults] objectForKey:SPMDefaultsLastParkingDate] == nil, @"If we have no parking point, we must not have a parking date");
    }

    return nil;
}

- (nullable ParkingTimeLimit *)parkingTimeLimitFromUserDefaults
{
    NSNumber *timeLimit = [[NSUserDefaults standardUserDefaults] objectForKey:SPMDefaultsLastParkingTimeLimit];
    NSDate *startDate = [[NSUserDefaults standardUserDefaults] objectForKey:SPMDefaultsLastParkingTimeLimitStartDate];
    NSNumber *reminderThreshold = [[NSUserDefaults standardUserDefaults] objectForKey:SPMDefaultsLastParkingTimeLimitReminderThreshold];
    if (timeLimit &&
        startDate &&
        reminderThreshold)
    {
        return [[ParkingTimeLimit alloc] initWithStartDate:startDate
                                                    length:timeLimit
                                         reminderThreshold:reminderThreshold];
    }

    return nil;
}

- (BOOL)setParkingSpotOnUserDefaults:(nullable ParkingSpot *)parkingSpot
{
    if (parkingSpot == nil)
    {
        [[NSUserDefaults standardUserDefaults] setObject:nil
                                                  forKey:SPMDefaultsLastParkingPoint];
        [[NSUserDefaults standardUserDefaults] setObject:nil
                                                  forKey:SPMDefaultsLastParkingDate];

        [[NSUserDefaults standardUserDefaults] setObject:nil
                                                  forKey:SPMDefaultsLastParkingAddress];

        [self setParkingTimeLimitOnUserDefaults:nil];
    }
    else
    {
        AGSPoint *point = [self pointFromLocation:parkingSpot.location];
        id parkingPointJSON = [point encodeToJSON];
        NSAssert(parkingPointJSON != nil, @"We must have a parking point to encode");
        if (!parkingPointJSON)
        {
            return NO;
        }

        [[NSUserDefaults standardUserDefaults] setObject:parkingPointJSON
                                                  forKey:SPMDefaultsLastParkingPoint];
        [[NSUserDefaults standardUserDefaults] setObject:parkingSpot.date
                                                  forKey:SPMDefaultsLastParkingDate];

        [[NSUserDefaults standardUserDefaults] setObject:parkingSpot.address
                                                  forKey:SPMDefaultsLastParkingAddress];

        [self setParkingTimeLimitOnUserDefaults:parkingSpot.timeLimit];
    }

    return YES;
}

- (void)setParkingTimeLimitOnUserDefaults:(nullable ParkingTimeLimit *)timeLimit
{
    if (timeLimit == nil)
    {
        [[NSUserDefaults standardUserDefaults] setObject:nil
                                                  forKey:SPMDefaultsLastParkingTimeLimit];
        [[NSUserDefaults standardUserDefaults] setObject:nil
                                                  forKey:SPMDefaultsLastParkingTimeLimitReminderThreshold];
        [[NSUserDefaults standardUserDefaults] setObject:nil
                                                  forKey:SPMDefaultsLastParkingTimeLimitStartDate];
    }
    else
    {
        [[NSUserDefaults standardUserDefaults] setObject:timeLimit.length
                                                  forKey:SPMDefaultsLastParkingTimeLimit];
        [[NSUserDefaults standardUserDefaults] setObject:timeLimit.reminderThreshold
                                                  forKey:SPMDefaultsLastParkingTimeLimitReminderThreshold];
        [[NSUserDefaults standardUserDefaults] setObject:timeLimit.startDate
                                                  forKey:SPMDefaultsLastParkingTimeLimitStartDate];
    }
}

#pragma mark - Parking Spot

- (void)setCurrentSpot:(nullable ParkingSpot *)currentSpot
{
    if (_currentSpot != currentSpot)
    {
        [self cancelGeocoding];

        if (![self setParkingSpotOnUserDefaults:currentSpot])
        {
            NSLog(@"Warning, could not save parking spot!");
            _currentSpot = nil;
            return;
        }

        _currentSpot = currentSpot;

        [self geocodeCurrentSpot];
        [self updateQuickActions];

        if (!_currentSpot)
        {
            [[UIApplication sharedApplication] cancelAllLocalNotifications];
        }
    }
}

#pragma mark - Geocoding

- (void)cancelGeocoding
{
    [self.geocoder cancelGeocode];
    self.geocoder = nil;
}

- (void)geocodeCurrentSpot
{
    if (!self.currentSpot.location)
    {
        return;
    }

    BOOL shouldGeocode = [WCSession isSupported] && [WCSession defaultSession].isReachable;

    if (!shouldGeocode)
    {
        return;
    }

    [self cancelGeocoding];

    if (self.currentSpot.address)
    {
        return;
    }

    self.geocoder = [[CLGeocoder alloc] init];

    [self.geocoder reverseGeocodeLocation:self.currentSpot.location
                        completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {
                            if (error)
                            {
                                NSLog(@"Reverse geocoding error: %@", error);
                            }
                            else
                            {
                                CLPlacemark *firstPlacemark = placemarks.firstObject;
                                if (firstPlacemark)
                                {
                                    NSString *address = firstPlacemark.thoroughfare;
                                    if ([address length])
                                    {
                                        if ([firstPlacemark.subThoroughfare length])
                                        {
                                            address = [NSString stringWithFormat:@"%@ %@", firstPlacemark.subThoroughfare, firstPlacemark.thoroughfare];
                                        }
                                    }
                                    else
                                    {
                                        address = firstPlacemark.name;
                                    }

                                    self.currentSpot.address = address;

                                    if ([WCSession isSupported] && [WCSession defaultSession].isReachable)
                                    {
                                        [[WCSession defaultSession] sendMessage:@{SPMWatchAction: SPMWatchActionUpdateGeocoding,
                                                                                  SPMWatchObjectParkingSpotAddress: self.currentSpot.address}
                                                                   replyHandler:nil
                                                                   errorHandler:^(NSError * _Nonnull sessionError) {
                                                                       NSLog(@"Could not send watch message %@", sessionError);
                                                                   }];
                                    }
                                }
                                else
                                {
                                    NSLog(@"No placemarks found for reverse geocoding!");
                                }
                            }
                        }];
}

#pragma mark - Time Limit

- (NSNumber *)userDefinedParkingTimeLimit
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:SPMDefaultsUserDefinedParkingTimeLimit];
}

- (void)setUserDefinedParkingTimeLimit:(NSNumber *)userDefinedParkingTimeLimit
{
    // Note that we use the setter. Test case: have a spot stored in defaults, and the first thing you do is try to set this to nil
    if (self.userDefinedParkingTimeLimit != userDefinedParkingTimeLimit)
    {
        [[NSUserDefaults standardUserDefaults] setObject:userDefinedParkingTimeLimit
                                                  forKey:SPMDefaultsUserDefinedParkingTimeLimit];

        NSError *error;
        [[WCSession defaultSession] updateApplicationContext:@{SPMWatchContextUserDefinedParkingTimeLimit: userDefinedParkingTimeLimit}
                                                       error:&error];
        if (error)
        {
            NSLog(@"Could not update application context from device to watch: %@", error);
        }
    }
}

#pragma mark - Quick Actions

- (void)updateQuickActions
{
    if ([UIMutableApplicationShortcutItem class])
    {
        NSArray <UIApplicationShortcutItem *> *existingShortcutItems = [UIApplication sharedApplication].shortcutItems;
        UIApplicationShortcutItem *shortcutItem = [existingShortcutItems firstObject];
        if (self.currentSpot)
        {
            if (!shortcutItem || ![shortcutItem.type isEqualToString:SPMShortcutItemTypeRemoveParkingSpot])
            {
                NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                // Since this can persist, let us not use relative
                dateFormatter.dateFormat = [NSDateFormatter dateFormatFromTemplate:@"MMM d, hh:mm a"
                                                                           options:0
                                                                            locale:[NSLocale currentLocale]];
                NSString *localizedSubtitle = [dateFormatter stringFromDate:self.currentSpot.date];

                UIApplicationShortcutIcon *icon = [UIApplicationShortcutIcon iconWithType:UIApplicationShortcutIconTypeProhibit];
                NSString *bundleVersionKey = (NSString *)kCFBundleVersionKey;
                UIMutableApplicationShortcutItem *item = [[UIMutableApplicationShortcutItem alloc] initWithType:SPMShortcutItemTypeRemoveParkingSpot
                                                                                                 localizedTitle:NSLocalizedString(@"Remove Parking Spot", nil)
                                                                                              localizedSubtitle:localizedSubtitle
                                                                                                           icon:icon
                                                                                                       userInfo:@{bundleVersionKey: [NSBundle mainBundle].infoDictionary[bundleVersionKey]}];
                [UIApplication sharedApplication].shortcutItems = @[item];
            }
        }
        else
        {
            if (![shortcutItem.type isEqualToString:SPMShortcutItemTypeParkInCurrentLocation])
            {
                UIApplicationShortcutIcon *icon = [UIApplicationShortcutIcon iconWithType:UIApplicationShortcutIconTypeMarkLocation];
                NSString *bundleVersionKey = (NSString *)kCFBundleVersionKey;
                UIMutableApplicationShortcutItem *item = [[UIMutableApplicationShortcutItem alloc] initWithType:SPMShortcutItemTypeParkInCurrentLocation
                                                                                                 localizedTitle:NSLocalizedString(@"Park", nil)
                                                                                              localizedSubtitle:NSLocalizedString(@"In Current Location", nil)
                                                                                                           icon:icon
                                                                                                       userInfo:@{bundleVersionKey: [NSBundle mainBundle].infoDictionary[bundleVersionKey]}];
                [UIApplication sharedApplication].shortcutItems = @[item];
            }
        }
    }
}

#pragma mark - Local Notifications

- (void)scheduleTimeLimitNotifications
{
    NSAssert([UIApplication sharedApplication].scheduledLocalNotifications, @"Must not have previously scheduled notifications");
    if ([[UIApplication sharedApplication].scheduledLocalNotifications count] > 0)
    {
        [[UIApplication sharedApplication] cancelAllLocalNotifications];
    }

    NSAssert(self.currentSpot.timeLimit != nil, @"Must have a parking spot with a time limit set");
    if (!self.currentSpot.timeLimit)
    {
        return;
    }

    [self scheduleParkingTimeExpiringLocalNotification];
    [self scheduleParkingTimeExpiredLocalNotification];
}

- (void)scheduleParkingTimeExpiringLocalNotification
{
    NSDate *limitStartDate = self.currentSpot.timeLimit.startDate;
    NSTimeInterval timeInterval = [self.currentSpot.timeLimit.length doubleValue];
    NSTimeInterval reminderThreshold = [self.currentSpot.timeLimit.reminderThreshold doubleValue];

    NSParameterAssert(limitStartDate);
    if (!limitStartDate)
    {
        return;
    }

    NSDate *fireDate = [limitStartDate dateByAddingTimeInterval:timeInterval - reminderThreshold];
    // Testing
    //    fireDate = [[NSDate date] dateByAddingTimeInterval:5];

    UILocalNotification *notification = [[UILocalNotification alloc] init];

    NSAssert([[NSDate date] compare:fireDate] == NSOrderedAscending, @"Fire date must be in the future");

    if ([[NSDate date] compare:fireDate] != NSOrderedAscending)
    {
        NSLog(@"Not scheduling local notification because it is in the past. %@", fireDate);
        return;
    }

    notification.userInfo = @{SPMNotificationUserInfoKeyIdentifier: SPMNotificationIdentifierTimeLimitExpiring,
                              SPMNotificationUserInfoKeyParkingSpot: [[NSUserDefaults standardUserDefaults] objectForKey:SPMDefaultsLastParkingPoint]};
    notification.fireDate = fireDate;
    notification.alertTitle = NSLocalizedString(@"Parking Spot Expiring", nil);

    NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
    formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
    formatter.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorDropAll;

    NSString *timeString = [formatter stringFromTimeInterval:reminderThreshold];
    notification.alertBody = [NSString stringWithFormat:NSLocalizedString(@"%@ remaining on parking spot", nil), timeString];
    notification.hasAction = YES;
    notification.alertAction = NSLocalizedString(@"View Parking Spot", nil);
    // http://soundbible.com/2081-Coin-Drop.html (Cut to 3 drops - 2 seconds in GarageBand)
    notification.soundName = @"Expiring.caf";

    //    double minutes = timeInterval / 60;
    //    if (minutes <= 60)
    //    {
    //        notification.applicationIconBadgeNumber = floor(minutes);
    //    }

    notification.category = SPMNotificationCategoryTimeLimit;

    [[UIApplication sharedApplication] scheduleLocalNotification:notification];
}

- (void)scheduleParkingTimeExpiredLocalNotification
{
    NSDate *parkDate = self.currentSpot.date;
    NSDate *expireDate = self.currentSpot.timeLimit.endDate;
    NSTimeInterval timeInterval = [self.currentSpot.timeLimit.length doubleValue];

    NSParameterAssert(parkDate);
    if (!parkDate)
    {
        return;
    }

    NSParameterAssert(expireDate);
    if (!expireDate)
    {
        return;
    }

    // Testing
    //    expireDate = [[NSDate date] dateByAddingTimeInterval:10];

    UILocalNotification *notification = [[UILocalNotification alloc] init];

    NSAssert([[NSDate date] compare:expireDate] == NSOrderedAscending, @"Fire date must be in the future");

    if ([[NSDate date] compare:expireDate] != NSOrderedAscending)
    {
        NSLog(@"Not scheduling local notification because it is in the past. %@", expireDate);
        return;
    }

    notification.userInfo = @{SPMNotificationUserInfoKeyIdentifier: SPMNotificationIdentifierTimeLimitExpired,
                              SPMNotificationUserInfoKeyParkingSpot: [[NSUserDefaults standardUserDefaults] objectForKey:SPMDefaultsLastParkingPoint]};
    notification.fireDate = expireDate;
    notification.alertTitle = NSLocalizedString(@"Parking Spot Expired", nil);

    NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
    formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
    formatter.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorDropAll;

    NSString *timeString = [formatter stringFromTimeInterval:timeInterval];
    NSString *expireDateString = [self.currentSpot localizedDateString];

    notification.alertBody = [NSString stringWithFormat:NSLocalizedString(@"Time limit of %@ has expired for vehicle parked %@", nil),
                              timeString,
                              expireDateString];
    notification.hasAction = YES;
    notification.alertAction = NSLocalizedString(@"View Parking Spot", nil);

    // @"https://freesound.org/people/OtisJames/sounds/215774/"
    notification.soundName = @"Expired.caf";
    
    notification.category = SPMNotificationCategoryTimeLimit;
    
    [[UIApplication sharedApplication] scheduleLocalNotification:notification];
}

@end
