//
//  KCSAddress.m
//  KinveyKit
//
//  Created by Victor Barros on 2015-11-23.
//  Copyright © 2015 Kinvey. All rights reserved.
//

#import "KCSAddress.h"

@implementation KCSAddress

-(NSDictionary *)hostToKinveyPropertyMapping
{
    return @{@"addressId" : KCSEntityKeyId,
             @"metadata"  : KCSEntityKeyMetadata,
             @"city"      : @"city",
             @"province"  : @"province",
             @"country"   : @"country"};
}

@end
