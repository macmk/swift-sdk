//
//  KCSPush.m
//  KinveyKit
//
//  Created by Brian Wilson on 11/28/11.
//  Copyright (c) 2011-2013 Kinvey. All rights reserved.
//
#ifndef NO_URBAN_AIRSHIP_PUSH

#import "KCSPush.h"
#import "KCSClient.h"
#import "KinveyUser.h"

#import "UAirship.h"
#import "UAPush.h"

#import "KinveyErrorCodes.h"
#import "KCSDevice.h"

@interface KCSPush()
- (BOOL)initializeUrbanAirshipWithOptions: (NSDictionary *)options error:(NSError**)error;
@property (nonatomic, retain, readwrite) NSData  *deviceToken;

@end

@implementation KCSPush

- (instancetype)init
{
    self = [super init];
    if (self) {
        _deviceToken = nil;
    }
    return self;
}


#pragma mark UA Init
+ (KCSPush *)sharedPush
{
    static KCSPush *sKCSPush;
    // This can be called on any thread, so we synchronise.  We only do this in 
    // the sKCSClient case because, once sKCSClient goes non-nil, it can 
    // never go nil again.
    
    if (sKCSPush == nil) {
        @synchronized (self) {
            sKCSPush = [[KCSPush alloc] init];
            assert(sKCSPush != nil);
        }
    }
    
    return sKCSPush;
}

- (void) onLoadHelper:(NSDictionary *)options
{
    (void)[self initializeUrbanAirshipWithOptions:options error:NULL];
}

- (BOOL) onLoadHelper:(NSDictionary *)options error:(NSError**)error
{
    return [self initializeUrbanAirshipWithOptions:options error:error];
}

- (void)onUnloadHelper
{
    [UAirship land];
}

- (BOOL) initializeUrbanAirshipWithOptions:(NSDictionary *)options error:(NSError**)error
{
    NSNumber *val = [options valueForKey:KCS_PUSH_IS_ENABLED_KEY];

    if ([val boolValue] == NO){
        // We don't want any of this code, so... we're done.
        return NO;
    }
    
    // Set up the UA stuff
    //Init Airship launch options
    
    NSMutableDictionary *airshipConfigOptions = [NSMutableDictionary dictionary];
    NSMutableDictionary *takeOffOptions = [NSMutableDictionary dictionary];
    
    NSString* pushKey = [options valueForKey:KCS_PUSH_KEY_KEY];
    NSString* pushSecret = [options valueForKey:KCS_PUSH_SECRET_KEY];
    
    NSPredicate *matchPred = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"^\\S{22}+$"]; //borrowed from UAirship.m
    if (pushKey == nil || pushSecret == nil || [matchPred evaluateWithObject:pushKey] == NO || [matchPred evaluateWithObject:pushSecret] == NO) {
        //error - key not set or not set properly
        if (error != NULL) {
            NSDictionary *errorDictionary = @{ NSLocalizedDescriptionKey : @"KCS_PUSH_KEY_KEY and/or KCS_PUSH_SECRET KEY not set properly in options dictionary."};
            *error = [[NSError alloc] initWithDomain:KCSPushErrorDomain code:KCSPrecondFailedError userInfo:errorDictionary];
        }
        return NO;
    }
    
    if ([[options valueForKey:KCS_PUSH_MODE_KEY] isEqualToString:KCS_PUSH_DEVELOPMENT]){
        [airshipConfigOptions setValue:@"NO" forKey:@"APP_STORE_OR_AD_HOC_BUILD"];
        [airshipConfigOptions setValue:pushKey forKey:@"DEVELOPMENT_APP_KEY"];
        [airshipConfigOptions setValue:pushSecret forKey:@"DEVELOPMENT_APP_SECRET"];
    } else {
        [airshipConfigOptions setValue:@"YES" forKey:@"APP_STORE_OR_AD_HOC_BUILD"];
        [airshipConfigOptions setValue:pushKey forKey:@"PRODUCTION_APP_KEY"];
        [airshipConfigOptions setValue:pushSecret forKey:@"PRODUCTION_APP_SECRET"];
    }
    
    [takeOffOptions setValue:airshipConfigOptions forKey:UAirshipTakeOffOptionsAirshipConfigKey];
    
    // Create Airship singleton that's used to talk to Urban Airship servers.
    // Please replace these with your info from http://go.urbanairship.com
    [UAirship takeOff:takeOffOptions];
    
    // Register for notifications through UAPush for notification type tracking
    [[UAPush shared] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge |
                                                         UIRemoteNotificationTypeSound |
                                                         UIRemoteNotificationTypeAlert)];
    
    
    [[UAPush shared] setAutobadgeEnabled:YES];
    [[UAPush shared] resetBadge];//zero badge
    
    return YES;
}

- (void) removeDeviceToken
{
    [UAPush shared].pushEnabled = NO;
    self.deviceToken = nil;
    [KCSDevice currentDevice].deviceToken = nil;
}

#pragma mark Push
// Push helpers

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    UALOG(@"Received remote notification: %@", userInfo);
    
    [[UAPush shared] handleNotification:userInfo applicationState:application.applicationState];
    [[UAPush shared] resetBadge]; // zero badge after push received
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    
    // Capture the token for us to use later
    self.deviceToken = deviceToken;
    [KCSDevice currentDevice].deviceToken = deviceToken;
    // Updates the device token and registers the token with UA
    [[UAPush shared] registerDeviceToken:deviceToken];
    
    if ([[KCSClient sharedClient] currentUser] != nil) {
        //if we have a current user, saving it will register the device token with the user collection on the backend
        //nil delegate because this is a silent try, and there's nothing to do if error
        [[[KCSClient sharedClient] currentUser] saveWithDelegate:nil];
    }
}

- (void)setPushBadgeNumber: (int)number
{
    [[UAPush shared] setBadgeNumber:number];
}

- (void)resetPushBadge
{
    [[UAPush shared] resetBadge];//zero badge
}

- (void) exposeSettingsViewInView: (UIViewController *)parentViewController
{
    [UAPush openApnsSettings:parentViewController animated:YES];
}

@end
#endif /* NO_URBAN_AIRSHIP_PUSH */

