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
#import "WCSession+SPM.h"

@import UserNotifications;

static void *ParkingManagerContext = &ParkingManagerContext;

@interface ParkingManager ()

@property (nonatomic, nullable) CLGeocoder *geocoder;
@property (nonatomic, nullable) NSUserActivity *currentActivity;

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
        
        [self setInternalCurrentSpot:[self parkingSpotFromUserDefaults]];
        
        [self addObserver:self
               forKeyPath:@"currentSpot.timeLimit"
                  options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld)
                  context:ParkingManagerContext];
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
                
                [self updateUserActivity];
                
                if (!self.currentSpot.timeLimit)
                {
                    [UNUserNotificationCenter.currentNotificationCenter removeAllPendingNotificationRequests];
                }
                else
                {
                    NSAssert([self.currentSpot.timeLimit.startDate SPMIsEqualOrAfterDate:self.currentSpot.date], @"The time limit start date must be equal or after");

                    [UNUserNotificationCenter.currentNotificationCenter getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
                        if (settings.authorizationStatus == UNAuthorizationStatusNotDetermined)
                        {
                            [UNUserNotificationCenter.currentNotificationCenter requestAuthorizationWithOptions:UNAuthorizationOptionAlert | UNAuthorizationOptionBadge | UNAuthorizationOptionCarPlay | UNAuthorizationOptionSound
                                                                                              completionHandler:^(BOOL granted, NSError * _Nullable error) {
                                                                                                  if (granted)
                                                                                                  {
                                                                                                      [[NSUserDefaults standardUserDefaults] setBool:YES
                                                                                                                                              forKey:SPMDefaultsRegisteredForLocalNotifications];

                                                                                                      [[ParkingManager sharedManager] scheduleTimeLimitNotifications];

                                                                                                      [WCSession.defaultSession SPMSendMessage:@{SPMWatchAction: SPMWatchActionDismissWarningMessage,
                                                                                                                                                 SPMWatchObjectWarningMessage: WCSession.defaultSession.SPMWatchWarningMessageEnableNotifications}];
                                                                                                  }
                                                                                                  else
                                                                                                  {
                                                                                                      [[NSUserDefaults standardUserDefaults] setBool:NO
                                                                                                                                              forKey:SPMDefaultsRegisteredForLocalNotifications];

                                                                                                  }
                                                                                              }];

                        }
                        else if (settings.authorizationStatus == UNAuthorizationStatusDenied)
                        {
                            [NSNotificationCenter.defaultCenter postNotificationName:SPMNotificationAuthorizationDeniedNotification
                                                                              object:nil];
                        }
                        else if (settings.authorizationStatus == UNAuthorizationStatusAuthorized)
                        {
                            [self scheduleTimeLimitNotifications];
                        }
                    }];
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
    
    AGSPoint *coreLocationPoint = (AGSPoint *)[AGSGeometryEngine projectGeometry:parkingPoint
                                                              toSpatialReference:[AGSSpatialReference WGS84]];
    
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
    
    NSError *error;
    AGSPoint *parkingPoint = (AGSPoint *)[AGSGeometry fromJSON:JSON error:&error];
    if (error)
    {
        NSLog(@"Could not decode AGSGeometry from JSON: %@", error);
    }
    
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
    
    AGSPoint *point = [AGSPoint pointWithX:location.coordinate.longitude
                                         y:location.coordinate.latitude
                          spatialReference:[AGSSpatialReference WGS84]];
    
    AGSSpatialReference *spatialReference = [AGSSpatialReference spatialReferenceWithWKID:SPMSpatialReferenceWKIDSDOT];
    return (AGSPoint *)[AGSGeometryEngine projectGeometry:point
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
        NSAssert([[NSUserDefaults standardUserDefaults] objectForKey:SPMDefaultsLastParkingDate] == nil, @"If we have no parking spot, we must not have a parking date");
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
        NSError *error;
        id parkingPointJSON = [point toJSON:&error];
        NSAssert(parkingPointJSON != nil, @"We must have a parking spot to encode");
        if (!parkingPointJSON)
        {
            NSLog(@"Could not decode JSON: %@", error);
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
        if (![self setParkingSpotOnUserDefaults:currentSpot])
        {
            [self cancelGeocoding];
            NSLog(@"Warning, could not save parking spot!");
            _currentSpot = nil;
            return;
        }
        
        [self setInternalCurrentSpot:currentSpot];
    }
}

- (void)setInternalCurrentSpot:(ParkingSpot *)currentSpot
{
    _currentSpot = currentSpot;
    
    [self updateQuickActions];
    
    if (!_currentSpot)
    {
        [UNUserNotificationCenter.currentNotificationCenter removeAllPendingNotificationRequests];
    }
    else
    {
        [self geocodeCurrentSpot];
    }
    
    [self updateUserActivity];
}

- (void)updateUserActivity
{
    if (!_currentSpot)
    {
        [self.currentActivity invalidate];
        self.currentActivity = nil;
    }
    else
    {
        [self.currentActivity invalidate];
        
        NSString *identifier = [NSBundle mainBundle].infoDictionary[(NSString *)kCFBundleIdentifierKey];
        
        self.currentActivity = [[NSUserActivity alloc] initWithActivityType:[NSString stringWithFormat:@"%@.currentParkingSpot", identifier]];
        
        NSString *title;
        NSString *when = [_currentSpot localizedAbsoluteDateString];
        NSString *where;
        NSString *timeLimit;
        
        if (_currentSpot.address)
        {
            where = [NSString stringWithFormat:NSLocalizedString(@"Parked around %@", nil), _currentSpot.address];
        }
        
        if (_currentSpot.timeLimit)
        {
            timeLimit = [NSString stringWithFormat:NSLocalizedString(@"with a time limit of %@ ending %@.", nil), [_currentSpot.timeLimit localizedLengthString], [_currentSpot.timeLimit localizedEndDateString]];
        }
        
        if (where)
        {
            title = [NSString stringWithFormat:NSLocalizedString(@"%@ on %@", nil), where, when];
            if (timeLimit)
            {
                title = [NSString stringWithFormat:@"%@ %@", title, timeLimit];
            }
        }
        else
        {
            title = [NSString stringWithFormat:NSLocalizedString(@"Parked on %@", nil), when];
            if (timeLimit)
            {
                title = [NSString stringWithFormat:@"%@ %@", title, timeLimit];
            }
        }
        
        NSParameterAssert(title);
        
        self.currentActivity.title = title;
        self.currentActivity.userInfo = [self.currentSpot watchConnectivityDictionaryRepresentation];
        [self.currentActivity becomeCurrent];
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
    
    // For Siri Reminders, not only for the watch
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
                                    
                                    [self updateUserActivity];
                                    
                                    NSMutableDictionary *replyDictionary = [[NSMutableDictionary alloc] initWithCapacity:4];
                                    replyDictionary[SPMWatchAction] = SPMWatchActionUpdateGeocoding;
                                    replyDictionary[SPMWatchNeedsComplicationUpdate] = @YES;
                                    NSNumber *userDefinedTimeLimit = [NSUserDefaults.standardUserDefaults objectForKey:SPMDefaultsUserDefinedParkingTimeLimit];
                                    if (userDefinedTimeLimit)
                                    {
                                        replyDictionary[SPMWatchObjectUserDefinedParkingTimeLimit] = userDefinedTimeLimit;
                                    }
                                    
                                    NSDictionary *parkingObject = [self.currentSpot watchConnectivityDictionaryRepresentation];
                                    if (parkingObject)
                                    {
                                        replyDictionary[SPMWatchObjectParkingSpot] = parkingObject;
                                    }
                                    
                                    // There are some cases in which the watch may not get a reply to GetParkingSpot, but geocoding first, so lets send them all the data instead of just an address update
                                    [WCSession.defaultSession SPMSendMessage:replyDictionary];
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
        [NSUserDefaults.standardUserDefaults setObject:userDefinedParkingTimeLimit
                                                forKey:SPMDefaultsUserDefinedParkingTimeLimit];
        
        
        if (WCSession.defaultSession.activationState == WCSessionActivationStateActivated)
        {
            NSError *error;
            
            [WCSession.defaultSession updateApplicationContext:@{SPMWatchContextUserDefinedParkingTimeLimit: userDefinedParkingTimeLimit}
                                                         error:&error];
            if (error)
            {
                NSLog(@"Could not update application context from device to watch: %@", error);
            }
        }
        else
        {
            NSLog(@"Device->Watch: could not update application context because activationState is %lu", (unsigned long)WCSession.defaultSession.activationState);
        }
    }
}

#pragma mark - Quick Actions

- (void)updateQuickActions
{
    // This may be called outside of the main thread!
    dispatch_async(dispatch_get_main_queue(), ^{
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
    });
}

#pragma mark - Local Notifications

- (void)scheduleTimeLimitNotifications
{
    [UNUserNotificationCenter.currentNotificationCenter getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> * _Nonnull requests) {
        NSAssert(requests, @"Must not have previously scheduled notifications");
        if (requests.count)
        {
            [UNUserNotificationCenter.currentNotificationCenter removeAllPendingNotificationRequests];
        }
        
        NSAssert(self.currentSpot.timeLimit != nil, @"Must have a parking spot with a time limit set");
        if (!self.currentSpot.timeLimit)
        {
            return;
        }
        
        [self scheduleParkingTimeExpiringLocalNotification];
        [self scheduleParkingTimeExpiredLocalNotification];
    }];
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
    
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    
    NSAssert([[NSDate date] compare:fireDate] == NSOrderedAscending, @"Fire date must be in the future");
    
    if ([[NSDate date] compare:fireDate] != NSOrderedAscending)
    {
        NSLog(@"Not scheduling local notification because it is in the past. %@", fireDate);
        return;
    }
    
    content.userInfo = @{SPMNotificationUserInfoKeyIdentifier: SPMNotificationIdentifierTimeLimitExpiring,
                         SPMNotificationUserInfoKeyParkingSpot: [[NSUserDefaults standardUserDefaults] objectForKey:SPMDefaultsLastParkingPoint]};
    content.title = NSLocalizedString(@"Parking Spot Expiring", nil);
    
    NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
    formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
    formatter.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorDropAll;
    
    NSString *timeString = [formatter stringFromTimeInterval:reminderThreshold];
    content.body = [NSString stringWithFormat:NSLocalizedString(@"%@ remaining on parking spot", nil), timeString];
    // http://soundbible.com/2081-Coin-Drop.html (Cut to 3 drops - 2 seconds in GarageBand)
    content.sound = [UNNotificationSound soundNamed:@"Expiring.caf"];
    
    //    double minutes = timeInterval / 60;
    //    if (minutes <= 60)
    //    {
    //        notification.applicationIconBadgeNumber = floor(minutes);
    //    }
    
    content.categoryIdentifier = SPMNotificationCategoryTimeLimit;
    
    UNNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:fireDate.timeIntervalSinceNow
                                                                                        repeats:NO];
    
    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:SPMNotificationTimeLimitExpiring
                                                                          content:content
                                                                          trigger:trigger];
    
    [UNUserNotificationCenter.currentNotificationCenter addNotificationRequest:request
                                                         withCompletionHandler:^(NSError * _Nullable error) {
                                                             if (error)
                                                             {
                                                                 SPMLog(@"Could not schedule local notification: %@", error);
                                                             }
                                                         }];
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
    
    
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    
    NSAssert([[NSDate date] compare:expireDate] == NSOrderedAscending, @"Fire date must be in the future");
    
    if ([[NSDate date] compare:expireDate] != NSOrderedAscending)
    {
        NSLog(@"Not scheduling local notification because it is in the past. %@", expireDate);
        return;
    }
    
    content.userInfo = @{SPMNotificationUserInfoKeyIdentifier: SPMNotificationIdentifierTimeLimitExpired,
                         SPMNotificationUserInfoKeyParkingSpot: [[NSUserDefaults standardUserDefaults] objectForKey:SPMDefaultsLastParkingPoint]};
    content.title = NSLocalizedString(@"Parking Spot Expired", nil);
    
    NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
    formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
    formatter.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorDropAll;
    
    NSString *timeString = [formatter stringFromTimeInterval:timeInterval];
    NSString *expireDateString = [self.currentSpot localizedDateString];
    
    content.body = [NSString stringWithFormat:NSLocalizedString(@"Time limit of %@ has expired for vehicle parked %@", nil),
                    timeString,
                    expireDateString];
    
    // @"https://freesound.org/people/OtisJames/sounds/215774/"
    content.sound = [UNNotificationSound soundNamed:@"Expired.caf"];
    
    content.categoryIdentifier = SPMNotificationCategoryTimeLimit;
    
    UNNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:expireDate.timeIntervalSinceNow
                                                                                        repeats:NO];
    
    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:SPMNotificationIdentifierTimeLimitExpired
                                                                          content:content
                                                                          trigger:trigger];
    
    [UNUserNotificationCenter.currentNotificationCenter addNotificationRequest:request
                                                         withCompletionHandler:^(NSError * _Nullable error) {
                                                             if (error)
                                                             {
                                                                 SPMLog(@"Could not schedule local notification: %@", error);
                                                             }
                                                         }];
}

@end
