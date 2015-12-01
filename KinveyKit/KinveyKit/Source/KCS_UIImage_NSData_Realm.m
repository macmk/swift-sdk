//
//  KCS_UIImage_NSDate_Realm.m
//  KinveyKit
//
//  Created by Victor Barros on 2015-11-30.
//  Copyright © 2015 Kinvey. All rights reserved.
//

#import "KCS_UIImage_NSData_Realm.h"
#import <UIKit/UIKit.h>

@implementation KCS_UIImage_NSData_Realm

+(Class)transformedValueClass
{
    return [NSData class];
}

-(id)transformedValue:(id)value
{
    if ([value isKindOfClass:[UIImage class]]) {
        return UIImagePNGRepresentation(value);
    }
    return nil;
}

-(id)reverseTransformedValue:(id)value
{
    if ([value isKindOfClass:[NSData class]]) {
        return [UIImage imageWithData:value];
    }
    return nil;
}

@end
