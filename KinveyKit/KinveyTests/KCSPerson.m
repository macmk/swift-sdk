//
//  KCSPerson.m
//  KinveyKit
//
//  Created by Victor Barros on 2015-11-23.
//  Copyright © 2015 Kinvey. All rights reserved.
//

#import "KCSPerson.h"

@implementation KCSPerson

@synthesize address = _address;

-(NSDictionary *)hostToKinveyPropertyMapping
{
    return @{@"personId" : KCSEntityKeyId,
             @"metadata" : KCSEntityKeyMetadata,
             @"name"     : @"name",
             @"address"  : @"address",
             @"company"  : @"company",
             @"picture"  : @"picture",
             @"age"      : @"age"};
}

+(NSDictionary *)kinveyPropertyToCollectionMapping
{
    return @{ @"company" : @"Company",
              @"picture" : KCSFileStoreCollectionName };
}

+(NSDictionary *)kinveyObjectBuilderOptions
{
    return @{ KCS_REFERENCE_MAP_KEY : @{ @"company" : [KCSCompany class] } };
}

-(NSArray *)referenceKinveyPropertiesOfObjectsToSave
{
    return @[@"company"];
}

@end
