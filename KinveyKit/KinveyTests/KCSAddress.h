//
//  KCSAddress.h
//  KinveyKit
//
//  Created by Victor Barros on 2015-11-23.
//  Copyright © 2015 Kinvey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <KinveyKit/KinveyKit.h>

@interface KCSAddress : NSObject <KCSPersistable>

@property (nonatomic, strong) NSString* city;
@property (nonatomic, strong) NSString* province;
@property (nonatomic, strong) NSString* country;

@end
