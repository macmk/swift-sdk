//
//  KCSCompany.m
//  KinveyKit
//
//  Created by Victor Barros on 2015-11-30.
//  Copyright © 2015 Kinvey. All rights reserved.
//

#import "KCSCompany.h"

@implementation KCSCompany

-(NSDictionary *)hostToKinveyPropertyMapping
{
    return @{@"companyId" : KCSEntityKeyId,
             @"metadata"  : KCSEntityKeyMetadata,
             @"name"      : @"name",
             @"url"       : @"url",
             @"location"  : KCSEntityKeyGeolocation};
}

@end
