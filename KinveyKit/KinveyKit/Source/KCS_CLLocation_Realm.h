//
//  KCSCLLocationRealm.h
//  KinveyKit
//
//  Created by Victor Barros on 2015-11-25.
//  Copyright © 2015 Kinvey. All rights reserved.
//

#import <Realm/Realm.h>
#import "KCS_CLLocationCoordinate2D_Realm.h"
#import "KCS_CLFloor_Realm.h"

@interface KCS_CLLocation_Realm : RLMObject

@property KCS_CLLocationCoordinate2D_Realm* coordinate;
@property double altitude;
@property KCS_CLFloor_Realm* floor;
@property double horizontalAccuracy;
@property double verticalAccuracy;
@property NSDate* timestamp;
@property double speed;
@property double course;

@end
