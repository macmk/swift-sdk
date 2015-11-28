//
//  KCSRealmEntityPersistence.m
//  KinveyKit
//
//  Created by Victor Barros on 2015-11-23.
//  Copyright © 2015 Kinvey. All rights reserved.
//

#import "KCSRealmEntityPersistence.h"

#import <objc/runtime.h>
#import <objc/message.h>

#import <Realm/Realm.h>

#import "KinveyCoreInternal.h"
#import "KinveyPersistable.h"
#import "KCSClientMetadataRealm.h"
#import "KCSUserRealm.h"
#import "KCSAppdataStore.h"
#import "KCSHiddenMethods.h"
#import "KCSDataModel.h"

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
        realGeneratedMap[@"NSDictionary"] = @"NSDictionary";
        realGeneratedMap[@"NSMutableDictionary"] = @"NSMutableDictionary";
        
        realGeneratedMap[@"CLLocation"] = @"KCS_CLLocation_Realm";
        realGeneratedMap[@"UIImage"] = @"NSData";
        realGeneratedMap[@"NSString"] = @"NSString";
        realGeneratedMap[@"NSMutableString"] = @"NSString";
        realGeneratedMap[@"NSDate"] = @"NSDate";
        realGeneratedMap[@"NSNumber"] = @"NSNumber";
        
        realGeneratedMap[@"KCSUser"] = @"KCSUserRealm";
        realGeneratedMap[@"KCSFile"] = @"KCSFileRealm";
        realGeneratedMap[@"KCSMetadata"] = @"KCSMetadataRealm";
        
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
    
    NSString* realmClassName = [NSString stringWithFormat:@"%@_KinveyRealm", className];
    Class realmClass = objc_allocateClassPair([RLMObject class], realmClassName.UTF8String, 0);
    
    if (realGeneratedMap[className]) return;
    
    realGeneratedMap[NSStringFromClass(class)] = NSStringFromClass(realmClass);
    
    [self copyPropertiesFromClass:class
                          toClass:realmClass];
    
    objc_registerClassPair(realmClass);
    
    [self createPrimaryKeyMethodFromClass:class
                                  toClass:realmClass];
}

+(void)copyPropertiesFromClass:(Class)fromClass
                       toClass:(Class)toClass
{
    unsigned int propertyCount;
    objc_property_t *properties = class_copyPropertyList(fromClass, &propertyCount);
    NSMutableDictionary<NSString*, NSObject*>* defaultPropertyValues = [NSMutableDictionary dictionaryWithCapacity:propertyCount];
    NSSet<NSString*>* ignoreClasses = [NSSet setWithArray:@[@"NSURL", @"NSDictionary", @"NSMutableDictionary", @"NSAttributedString", @"NSMutableAttributedString"]];
    NSSet<NSString*>* subtypeRequiredClasses = [NSSet setWithArray:@[@"NSArray", @"NSMutableArray", @"NSSet", @"NSMutableSet", @"NSOrderedSet", @"NSMutableOrderedSet", @"NSNumber"]];
    NSRegularExpression* regexClassName = [NSRegularExpression regularExpressionWithPattern:@"@\"(\\w+)(?:<(\\w+)>)?\""
                                                                                    options:0
                                                                                      error:nil];
    NSArray<NSTextCheckingResult*>* matches = nil;
    NSTextCheckingResult* textCheckingResult = nil;
    NSRange range;
    NSString *attributeValue = nil, *propertyName = nil, *className = nil, *subtypeName = nil, *realmClassName = nil;
    objc_property_t property;
    unsigned int attributeCount;
    objc_property_attribute_t *attributes = nil;
    objc_property_attribute_t attribute;
    BOOL ignoreProperty;
    for (int i = 0; i < propertyCount; i++) {
        property = properties[i];
        propertyName = [NSString stringWithUTF8String:property_getName(property)];
        attributeCount = 0;
        attributes = property_copyAttributeList(property, &attributeCount);
        ignoreProperty = NO;
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
                            ignoreProperty = YES;
                            KCSLogWarn(KCS_LOG_CONTEXT_DATA, @"Data type not supported: [%@ %@]", NSStringFromClass(fromClass), propertyName);
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
                                textCheckingResult = matches.firstObject;
                                className = [attributeValue substringWithRange:[textCheckingResult rangeAtIndex:1]];
                                range = [textCheckingResult rangeAtIndex:2];
                                subtypeName = range.location != NSNotFound ? [attributeValue substringWithRange:range] : nil;
                                if ([ignoreClasses containsObject:className]) {
                                    ignoreProperty = YES;
                                    KCSLogWarn(KCS_LOG_CONTEXT_DATA, @"Data type not supported: [%@ %@] (%@)", NSStringFromClass(fromClass), propertyName, className);
                                } else if ([subtypeRequiredClasses containsObject:className] &&
                                           subtypeName == nil)
                                {
                                    ignoreProperty = YES;
                                    KCSLogWarn(KCS_LOG_CONTEXT_DATA, @"Data type requires a subtype: [%@ %@] (%@)", NSStringFromClass(fromClass), propertyName, className);
                                } else {
                                    if (realGeneratedMap[className] == nil) {
                                        [self createRealmClass:NSClassFromString(className)];
                                    }
                                    realmClassName = realGeneratedMap[className];
                                    if (realmClassName) {
                                        if (subtypeName) {
                                            attribute.value = [NSString stringWithFormat:@"@\"%@<%@>\"", realmClassName, realGeneratedMap[subtypeName]].UTF8String;
                                        } else {
                                            attribute.value = [NSString stringWithFormat:@"@\"%@\"", realmClassName].UTF8String;
                                        }
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
                    ignoreProperty = YES;
                    break;
                default:
                    break;
            }
        }
        if (!ignoreProperty) {
            BOOL added = class_addProperty(toClass, propertyName.UTF8String, attributes, attributeCount);
            assert(added);
        }
        free(attributes);
    }
    free(properties);
}

+(void)createPrimaryKeyMethodFromClass:(Class)fromClass
                               toClass:(Class)toClass
{
    NSString* primaryKey = nil;
    @try {
        id<KCSPersistable> sampleObj = [[fromClass alloc] init];
        NSDictionary* propertyMapping = [sampleObj hostToKinveyPropertyMapping];
        NSString* value;
        for (NSString* key in propertyMapping) {
            value = propertyMapping[key];
            if ([value isEqualToString:KCSEntityKeyId]) {
                primaryKey = key;
                break;
            }
        }
    } @catch (NSException *exception) {
        //do nothing!
    }
    
    if (!primaryKey) {
        primaryKey = KCSEntityKeyId;
        objc_property_attribute_t type = { "T", "@\"NSString\"" };
        objc_property_attribute_t ownership = { "C", "" }; // C = copy
        objc_property_attribute_t backingivar  = { "V", [NSString stringWithFormat:@"_%@", primaryKey].UTF8String };
        objc_property_attribute_t attrs[] = { type, ownership, backingivar };
        BOOL added = class_addProperty(toClass, primaryKey.UTF8String, attrs, 3);
        if (!added) {
            class_replaceProperty(toClass, primaryKey.UTF8String, attrs, 3);
        }
    }
    
    SEL sel = @selector(primaryKey);
    IMP imp = imp_implementationWithBlock(^NSString*(Class class) {
        return primaryKey;
    });
    Method method = class_getClassMethod(toClass, sel);
    const char* className = class_getName(toClass);
    Class metaClass = objc_getMetaClass(className);
    BOOL added = class_addMethod(metaClass, sel, imp, method_getTypeEncoding(method));
    assert(added);
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

+(NSMutableDictionary<NSString*, NSObject*>*)createEntity:(NSDictionary<NSString*, NSObject*>*)entity
                                      withPropertyMapping:(NSDictionary<NSString*, NSString*>*)propertyMapping
{
    if (!entity) return nil;
    NSMutableDictionary<NSString*, NSObject*>* newEntity = [NSMutableDictionary dictionaryWithCapacity:entity.count];
    [entity enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSObject * _Nonnull obj, BOOL * _Nonnull stop) {
        NSString* keyMap = propertyMapping[key];
        if (keyMap) {
            newEntity[keyMap] = entity[key];
        }
    }];
    return newEntity;
}

-(BOOL)updateObject:(id<KCSPersistable>)object
             entity:(NSDictionary*)entity
       appdataRoute:(NSString*)route
         collection:(NSString*)collection
{
    __block BOOL result = NO;
    Class class = [[KCSAppdataStore caches].dataModel classForCollection:collection];
    NSString* realmClassName = realGeneratedMap[NSStringFromClass(class)];
    Class realmClass = NSClassFromString(realmClassName);
    NSDictionary* propertyMapping = [object hostToKinveyPropertyMapping];
    NSMutableDictionary<NSString*, NSObject*>* newEntity = [KCSRealmEntityPersistence createEntity:entity
                                                                               withPropertyMapping:propertyMapping.invert];
    
    RLMRealm* realm = self.realm;
    [realm transactionWithBlock:^{
        id realmObj = [realmClass createOrUpdateInRealm:realm
                                              withValue:newEntity];
        result = realmObj != nil;
    }];
    return result;
}

-(NSArray<NSDictionary *> *)entitiesForQuery:(KCSQuery2 *)query
                                       route:(NSString *)route
                                  collection:(NSString *)collection
{
    Class class = [[KCSAppdataStore caches].dataModel classForCollection:collection];
    NSString* realmClassName = realGeneratedMap[NSStringFromClass(class)];
    Class realmClass = NSClassFromString(realmClassName);
    RLMRealm* realm = self.realm;
    id realmObj = [realmClass objectsInRealm:realm
                               withPredicate:query.query.predicate];
    return nil;
}

-(NSArray *)idsForQuery:(KCSQuery2 *)query
                  route:(NSString *)route
             collection:(NSString *)collection
{
    return nil;
}

-(NSDictionary *)entityForId:(NSString *)_id route:(NSString *)route collection:(NSString *)collection
{
    return nil;
}

-(void)clearCaches
{
    RLMRealm* realm = self.realm;
    [realm transactionWithBlock:^{
        [realm deleteAllObjects];
    }];
}

@end
