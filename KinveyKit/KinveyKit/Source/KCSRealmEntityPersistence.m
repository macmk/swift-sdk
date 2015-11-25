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

@interface KCSRealmEntityPersistence ()

@property RLMRealm *realm;
@property NSThread* thread;
@property CFRunLoopRef runLoop;

@end

@implementation KCSRealmEntityPersistence

@synthesize persistenceId = _persistenceId;

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

-(instancetype)initWithPersistenceId:(NSString *)key
{
    self = [super init];
    if (self) {
        self.persistenceId = key;
        
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        
        self.thread = [[NSThread alloc] initWithTarget:self
                                              selector:@selector(run:)
                                                object:semaphore];
        self.thread.name = @"com.kinvey.KinveyRealm";
        [self.thread start];
        
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    }
    return self;
}

-(void)run:(dispatch_semaphore_t)semaphore
{
    @autoreleasepool {
        self.runLoop = CFRunLoopGetCurrent();
        RLMRealmConfiguration* configuration = [RLMRealmConfiguration defaultConfiguration];
        
        NSMutableArray<NSString*>* pathComponents = [configuration.path pathComponents].mutableCopy;
        pathComponents[pathComponents.count - 1] = [NSString stringWithFormat:@"com.kinvey.%@_cache.realm", self.persistenceId];
        configuration.path = [NSString pathWithComponents:pathComponents];
        
        NSError* error = nil;
        self.realm = [RLMRealm realmWithConfiguration:configuration
                                                error:&error];
        dispatch_semaphore_signal(semaphore);
        if (error) {
            @throw error;
        }
        
        while (YES) @autoreleasepool {
            CFRunLoopRun();
        }
    }
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

-(void)performBlock:(void (^)(void))block
{
    CFRunLoopPerformBlock(self.runLoop, kCFRunLoopDefaultMode, block);
}

-(void)performBlockAndWait:(void (^)(void))block
{
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    CFRunLoopPerformBlock(self.runLoop, kCFRunLoopDefaultMode, ^{
        block();
        dispatch_semaphore_signal(semaphore);
    });
    CFRunLoopWakeUp(self.runLoop);
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
}

-(NSDictionary *)clientMetadata
{
    __block NSDictionary* clientMetadata = nil;
    [self performBlockAndWait:^{
        KCSClientMetadataRealm* metadata = [KCSClientMetadataRealm allObjectsInRealm:self.realm].lastObject;
        if (metadata) {
            clientMetadata = @{@"appkey" : metadata.appkey};
        }
    }];
    return clientMetadata;
    
}

-(BOOL)setClientMetadata:(NSDictionary *)metadata
{
    [self performBlockAndWait:^{
        [self.realm transactionWithBlock:^{
            [self.realm deleteObjects:[KCSClientMetadataRealm allObjectsInRealm:self.realm]];
            [KCSClientMetadataRealm createOrUpdateInRealm:self.realm
                                                withValue:metadata];
        }];
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
    [self performBlockAndWait:^{
        [self.realm transactionWithBlock:^{
            KCSUserRealm* user = [KCSUserRealm createOrUpdateInRealm:self.realm
                                                           withValue:entity];
            result = user != nil;
        }];
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
    [self performBlockAndWait:^{
        [self.realm transactionWithBlock:^{
            [self.realm deleteAllObjects];
        }];
    }];
}

@end
