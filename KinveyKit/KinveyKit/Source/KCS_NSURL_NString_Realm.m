//
//  KCS_NSURL_NString_Realm.m
//  KinveyKit
//
//  Created by Victor Barros on 2015-11-30.
//  Copyright © 2015 Kinvey. All rights reserved.
//

#import "KCS_NSURL_NString_Realm.h"

@implementation KCS_NSURL_NString_Realm

+(Class)transformedValueClass
{
    return [NSString class];
}

+(BOOL)allowsReverseTransformation
{
    return YES;
}

-(id)transformedValue:(id)value
{
    if ([value isKindOfClass:[NSURL class]]) {
        return ((NSURL*) value).absoluteString;
    }
    return nil;
}

-(id)reverseTransformedValue:(id)value
{
    if ([value isKindOfClass:[NSString class]]) {
        return [NSURL URLWithString:(NSString*)value];
    }
    return nil;
}

@end
