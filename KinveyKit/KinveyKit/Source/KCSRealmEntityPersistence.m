//
//  KCSRealmEntityPersistence.m
//  KinveyKit
//
//  Created by Victor Barros on 2015-11-23.
//  Copyright © 2015 Kinvey. All rights reserved.
//

#import "KCSRealmEntityPersistence.h"

#import "KinveyPersistable.h"

#import <objc/runtime.h>
#import <objc/message.h>

#import <Realm/Realm.h>

@implementation KCSRealmEntityPersistence

+(void)initialize
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        unsigned int classesCount;
        Class* classes = objc_copyClassList(&classesCount);
        Class class = nil;
        for (unsigned int i = 0; i < classesCount; i++) {
            class = classes[i];
            if (!class_conformsToProtocol(class, @protocol(KCSPersistable))) continue;
            
            [self createRealmClass:class];
        }
        free(classes);
    });
}

+(void)createRealmClass:(Class)class
{
    NSString* className = [NSString stringWithUTF8String:class_getName(class)];
    
    Class realmClass = objc_allocateClassPair([RLMObject class], [NSString stringWithFormat:@"%@__RLMObject", className].UTF8String, 0);
    
    objc_registerClassPair(realmClass);
}

+(void)copyPropertiesFromClass:(Class)fromClass toClass:(Class)toClass
{
    unsigned int propertyCount;
    objc_property_t *properties = class_copyPropertyList(fromClass, &propertyCount);
    NSMutableSet<NSString*>* propertyMethods = [NSMutableSet setWithCapacity:propertyCount * 2];
    NSMutableDictionary<NSString*, NSObject*>* defaultPropertyValues = [NSMutableDictionary dictionaryWithCapacity:propertyCount];
    objc_property_t property = nil;
    const char* name = nil;
    unsigned int attributeCount = 0;
    objc_property_attribute_t *attributes = nil;
    objc_property_attribute_t attribute;
    BOOL added = NO;
    NSString *nameStr = nil, *attributeName = nil, *attributeValue = nil;
    for (int i = 0; i < propertyCount; i++) {
        property = properties[i];
        name = property_getName(property);
        attributeCount = 0;
        attributes = property_copyAttributeList(property, &attributeCount);
        added = class_addProperty(toClass, name, attributes, attributeCount);
        assert(added);
        nameStr = [NSString stringWithUTF8String:name];
        for (unsigned int i = 0; i < attributeCount; i++) {
            attribute = attributes[i];
            attributeName = [NSString stringWithUTF8String:attribute.name];
            attributeValue = [NSString stringWithUTF8String:attribute.value];
            if ([attributeName isEqualToString:@"T"]) {
                switch ([attributeValue characterAtIndex:0]) {
                    case 'c':
                        defaultPropertyValues[nameStr] = @((char) 0);
                        break;
                    case 'i':
                        defaultPropertyValues[nameStr] = @((int) 0);
                        break;
                    case 's':
                        defaultPropertyValues[nameStr] = @((short) 0);
                        break;
                    case 'l':
                        defaultPropertyValues[nameStr] = @((long) 0);
                        break;
                    case 'q':
                        defaultPropertyValues[nameStr] = @((long long) 0);
                        break;
                    case 'C':
                        defaultPropertyValues[nameStr] = @((unsigned char) 0);
                        break;
                    case 'I':
                        defaultPropertyValues[nameStr] = @((unsigned int) 0);
                        break;
                    case 'S':
                        defaultPropertyValues[nameStr] = @((unsigned short) 0);
                        break;
                    case 'L':
                        defaultPropertyValues[nameStr] = @((unsigned long) 0);
                        break;
                    case 'Q':
                        defaultPropertyValues[nameStr] = @((unsigned long long) 0);
                        break;
                    case 'f':
                        defaultPropertyValues[nameStr] = @((float) 0);
                        break;
                    case 'd':
                        defaultPropertyValues[nameStr] = @((double) 0);
                        break;
                    case 'B':
                        defaultPropertyValues[nameStr] = @((bool) NO);
                        break;
                    default:
                        break;
                }
            }
        }
        
        [propertyMethods addObject:[NSString stringWithFormat:@"set%c%@:", [[nameStr uppercaseString] characterAtIndex:0], [nameStr substringFromIndex:1]]];
        [propertyMethods addObject:nameStr];
        free(attributes);
    }
    free(properties);
}

@end
