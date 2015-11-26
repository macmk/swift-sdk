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

#import "KCSClientMetadataRealm.h"
#import "KCSUserRealm.h"

#import <UIKit/UIKit.h>

@interface KCSRealmEntityPersistence ()

@property (nonatomic, readonly) RLMRealmConfiguration* realmConfiguration;
@property (nonatomic, readonly) RLMRealm* realm;

@end

@implementation KCSRealmEntityPersistence

@synthesize persistenceId = _persistenceId;

static NSMutableDictionary<NSString*, NSString*>* realGeneratedMap = nil;

+(void)initialize
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        realGeneratedMap = [NSMutableDictionary dictionary];
        realGeneratedMap[@"NSArray"] = @"RLMArray";
        realGeneratedMap[@"NSMutableArray"] = @"RLMArray";
        realGeneratedMap[@"NSSet"] = @"RLMArray";
        realGeneratedMap[@"NSMutableSet"] = @"RLMArray";
        realGeneratedMap[@"NSOrderedSet"] = @"RLMArray";
        realGeneratedMap[@"NSMutableOrderedSet"] = @"RLMArray";
        realGeneratedMap[@"KCSUser"] = @"KCSUserRealm";
        realGeneratedMap[@"KCSFile"] = @"KCSFileRealm";
        realGeneratedMap[@"KCSMetadata"] = @"KCSMetadataRealm";
        realGeneratedMap[@"CLLocation"] = @"KCS_CLLocation_Realm";
        realGeneratedMap[@"UIImage"] = @"NSData";
        
        unsigned int classesCount;
        Class* classes = objc_copyClassList(&classesCount);
        Class class = nil;
        NSSet<NSString*>* ignoreClasses = [NSSet setWithArray:@[@"NSObject", @"KCSFile", @"KCSUser", @"KCSMetadata"]];
        NSString* className = nil;
        for (unsigned int i = 0; i < classesCount; i++) {
            class = classes[i];
            className = [NSString stringWithUTF8String:class_getName(class)];
            if (!class_conformsToProtocol(class, @protocol(KCSPersistable))) continue;
            if ([ignoreClasses containsObject:className]) continue;
            if (realGeneratedMap[className]) continue;
            
            [self createRealmClass:class];
        }
        free(classes);
    });
}

-(instancetype)initWithPersistenceId:(NSString *)key
{
    self = [super init];
    if (self) {
        _persistenceId = key;
    }
    return self;
}

-(RLMRealmConfiguration *)realmConfiguration
{
    static RLMRealmConfiguration* configuration = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        configuration = [RLMRealmConfiguration defaultConfiguration];
        
        NSMutableArray<NSString*>* pathComponents = [configuration.path pathComponents].mutableCopy;
        pathComponents[pathComponents.count - 1] = [NSString stringWithFormat:@"com.kinvey.%@_cache.realm", self.persistenceId];
        configuration.path = [NSString pathWithComponents:pathComponents];
    });
    return configuration;
}

-(RLMRealm *)realm
{
    NSError* error = nil;
    RLMRealm* realm = [RLMRealm realmWithConfiguration:self.realmConfiguration
                                                 error:&error];
    if (error) {
        @throw error;
    }
    return realm;
}

+(void)createRealmClass:(Class)class
{
    NSString* className = [NSString stringWithUTF8String:class_getName(class)];
    
    NSString* realmClassName = [NSString stringWithFormat:@"%@KinveyRealm", className];
    Class realmClass = objc_allocateClassPair([RLMObject class], realmClassName.UTF8String, 0);
    
    if (realGeneratedMap[className]) return;
    
    realGeneratedMap[NSStringFromClass(class)] = NSStringFromClass(realmClass);
    
    [self copyPropertiesFromClass:class
                          toClass:realmClass];
    
    objc_registerClassPair(realmClass);
}

+(void)copyPropertiesFromClass:(Class)fromClass toClass:(Class)toClass
{
    unsigned int propertyCount;
    objc_property_t *properties = class_copyPropertyList(fromClass, &propertyCount);
    NSMutableDictionary<NSString*, NSObject*>* defaultPropertyValues = [NSMutableDictionary dictionaryWithCapacity:propertyCount];
    NSSet<NSString*>* ignoreClasses = [NSSet setWithArray:@[@"NSURL", @"NSDictionary", @"NSMutableDictionary", @"NSString", @"NSMutableAttributedString", @"NSDate", @"NSNumber"]];
    NSRegularExpression* regexClassName = [NSRegularExpression regularExpressionWithPattern:@"@\"(\\w+)(?:<(\\w+)>)?\""
                                                                                    options:0
                                                                                      error:nil];
    NSArray<NSTextCheckingResult*>* matches = nil;
    NSString *attributeValue = nil, *propertyName = nil, *className = nil, *realmClassName;
    objc_property_t property;
    unsigned int attributeCount;
    objc_property_attribute_t *attributes = nil;
    objc_property_attribute_t attribute;
    BOOL isReadOnly;
    NSException* exception = nil;
    for (int i = 0; i < propertyCount; i++) {
        property = properties[i];
        propertyName = [NSString stringWithUTF8String:property_getName(property)];
        attributeCount = 0;
        attributes = property_copyAttributeList(property, &attributeCount);
        isReadOnly = NO;
        className = nil;
        for (unsigned int i = 0; i < attributeCount; i++) {
            attribute = attributes[i];
            switch (attribute.name[0]) {
                case 'T':
                    switch (attribute.value[0]) {
                        case 'c':
                            defaultPropertyValues[propertyName] = @((char) 0);
                            break;
                        case 'i':
                            defaultPropertyValues[propertyName] = @((int) 0);
                            break;
                        case 's':
                            defaultPropertyValues[propertyName] = @((short) 0);
                            break;
                        case 'l':
                            defaultPropertyValues[propertyName] = @((long) 0);
                            break;
                        case 'q':
                            defaultPropertyValues[propertyName] = @((long long) 0);
                            break;
                        case 'C':
                            defaultPropertyValues[propertyName] = @((unsigned char) 0);
                            break;
                        case 'I':
                            defaultPropertyValues[propertyName] = @((unsigned int) 0);
                            break;
                        case 'S':
                            defaultPropertyValues[propertyName] = @((unsigned short) 0);
                            break;
                        case 'L':
                            defaultPropertyValues[propertyName] = @((unsigned long) 0);
                            break;
                        case 'Q': { //unsigned long long
                            NSString* reason = [NSString stringWithFormat:@"Type not supported: [%@ %@]", NSStringFromClass(fromClass), propertyName];
                            exception = [NSException exceptionWithName:@"KinveyException"
                                                                reason:reason
                                                              userInfo:@{NSLocalizedDescriptionKey : reason,
                                                                         NSLocalizedFailureReasonErrorKey : reason}];
                            break;
                        }
                        case 'f':
                            defaultPropertyValues[propertyName] = @((float) 0);
                            break;
                        case 'd':
                            defaultPropertyValues[propertyName] = @((double) 0);
                            break;
                        case 'B':
                            defaultPropertyValues[propertyName] = @((bool) NO);
                            break;
                        case '@':
                            attributeValue = [NSString stringWithUTF8String:attribute.value];
                            matches = [regexClassName matchesInString:attributeValue
                                                              options:0
                                                                range:NSMakeRange(0, attributeValue.length)];
                            if (matches.count > 0 &&
                                matches.firstObject.numberOfRanges > 1 &&
                                [matches.firstObject rangeAtIndex:1].location != NSNotFound)
                            {
                                className = [attributeValue substringWithRange:[matches.firstObject rangeAtIndex:1]];
                                if (![ignoreClasses containsObject:className]) {
                                    if (realGeneratedMap[className] == nil) {
                                        [self createRealmClass:NSClassFromString(className)];
                                    }
                                    realmClassName = realGeneratedMap[className];
                                    if (realmClassName) {
                                        attribute.value = [NSString stringWithFormat:@"@\"%@\"", realmClassName].UTF8String;
                                        attributes[i] = attribute;
                                    }
                                }
                            }
                            break;
                        default:
                            break;
                    }
                    break;
                case 'R':
                    isReadOnly = YES;
                    break;
                default:
                    break;
            }
        }
        if (exception != nil || isReadOnly || (className != nil && [ignoreClasses containsObject:className])) {
            free(attributes);
            if (exception) {
                @throw exception;
            }
            continue;
        }
        BOOL added = class_addProperty(toClass, propertyName.UTF8String, attributes, attributeCount);
        assert(added);
        free(attributes);
    }
    free(properties);
}

-(NSDictionary *)clientMetadata
{
    RLMRealm* realm = self.realm;
    NSDictionary* clientMetadata = nil;
    KCSClientMetadataRealm* metadata = [KCSClientMetadataRealm allObjectsInRealm:realm].lastObject;
    if (metadata) {
        clientMetadata = @{ @"appkey" : metadata.appkey };
    }
    return clientMetadata;
}

-(BOOL)setClientMetadata:(NSDictionary *)metadata
{
    RLMRealm* realm = self.realm;
    [realm transactionWithBlock:^{
        [realm deleteObjects:[KCSClientMetadataRealm allObjectsInRealm:realm]];
        [KCSClientMetadataRealm createOrUpdateInRealm:realm
                                            withValue:metadata];
    }];
    return YES;
}

-(BOOL)updateObject:(id<KCSPersistable>)object
             entity:(NSDictionary *)entity
              route:(NSString *)route
         collection:(NSString *)collection
{
    BOOL (*updateEntity)(id, SEL, id<KCSPersistable>, NSDictionary*, NSString*, NSString*) = (BOOL (*)(id, SEL, id<KCSPersistable>, NSDictionary*, NSString*, NSString*)) objc_msgSend;
    return updateEntity(self, NSSelectorFromString([NSString stringWithFormat:@"updateObject:entity:%@Route:collection:", route]), object, entity, route, collection);
}

-(BOOL)updateObject:(id<KCSPersistable>)object
             entity:(NSDictionary*)entity
          userRoute:(NSString*)route
         collection:(NSString*)collection
{
    __block BOOL result = NO;
    RLMRealm* realm = self.realm;
    [realm transactionWithBlock:^{
        KCSUserRealm* user = [KCSUserRealm createOrUpdateInRealm:realm
                                                       withValue:entity];
        result = user != nil;
    }];
    return result;
}

-(BOOL)updateObject:(id<KCSPersistable>)object
             entity:(NSDictionary*)entity
       appdataRoute:(NSString*)route
         collection:(NSString*)collection
{
    return NO;
}

-(void)clearCaches
{
    RLMRealm* realm = self.realm;
    [realm transactionWithBlock:^{
        [realm deleteAllObjects];
    }];
}

@end
