//
//  KCSPerson.m
//  KinveyKit
//
//  Created by Victor Barros on 2015-11-23.
//  Copyright © 2015 Kinvey. All rights reserved.
//

#import "KCSPerson.h"

@implementation KCSPerson

-(NSDictionary *)hostToKinveyPropertyMapping
{
    return @{@"personId" : KCSEntityKeyId,
             @"metadata" : KCSEntityKeyMetadata,
             @"name"     : @"name",
             @"address"  : @"address",
             @"age"      : @"age"};
}

+(NSDictionary *)kinveyPropertyToCollectionMapping
{
    return @{ @"address" : @"Address" };
}

+(NSDictionary *)kinveyObjectBuilderOptions
{
    return @{ KCS_REFERENCE_MAP_KEY : @{ @"address" : [KCSAddress class] } };
}

-(NSArray *)referenceKinveyPropertiesOfObjectsToSave
{
    return @[@"address"];
}

@end
