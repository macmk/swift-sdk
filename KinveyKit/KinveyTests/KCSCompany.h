//
//  KCSCompany.h
//  KinveyKit
//
//  Created by Victor Barros on 2015-11-30.
//  Copyright © 2015 Kinvey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <KinveyKit/KinveyKit.h>

@interface KCSCompany : NSObject <KCSPersistable>

@property NSString* companyId;
@property NSString* name;
@property NSURL* url;
@property CLLocation* location;
@property KCSMetadata* metadata;

@end
