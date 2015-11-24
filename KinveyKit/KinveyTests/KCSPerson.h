//
//  KCSPerson.h
//  KinveyKit
//
//  Created by Victor Barros on 2015-11-23.
//  Copyright © 2015 Kinvey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <KinveyKit/KinveyKit.h>
#import "KCSAddress.h"

@interface KCSPerson : NSObject <KCSPersistable>

@property (nonatomic, strong) NSString* personId;
@property (nonatomic, strong) NSString* name;
@property (nonatomic, assign) NSUInteger age;
@property (nonatomic, strong) KCSAddress* address;

@property (nonatomic, strong) KCSMetadata* metadata;

@end
