//
//  KCSEntityPersistence.h
//  KinveyKit
//
//  Created by Victor Barros on 2015-11-23.
//  Copyright © 2015 Kinvey. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "KinveyPersistable.h"
#import "KCSQuery2.h"

@protocol KCSEntityPersistence <NSObject>

@property (nonatomic, retain) NSString* persistenceId;

-(instancetype)initWithPersistenceId:(NSString*)key;

-(NSArray*)allIds:(NSString*)route
       collection:(NSString*)collection;

-(NSArray*)idsForQuery:(id)query
                 route:(NSString*)route
            collection:(NSString*)collection;

-(BOOL)setIds:(NSArray*)theseIds
     forQuery:(NSString*)query
        route:(NSString*)route
   collection:(NSString*)collection;

-(NSDictionary*)entityForId:(NSString*)_id
                      route:(NSString*)route
                 collection:(NSString*)collection;

-(BOOL)removeQuery:(KCSQuery2*)query
             route:(NSString*)route
        collection:(NSString*)collection;

-(BOOL)removeEntity:(NSString*)_id
              route:(NSString*)route
         collection:(NSString*)collection;

-(BOOL)updateObject:(id<KCSPersistable>)object
             entity:(NSDictionary*)entity
              route:(NSString*)route
         collection:(NSString*)collection;

-(NSString*)addUnsavedEntity:(NSDictionary*)entity
                       route:(NSString*)route
                  collection:(NSString*)collection
                      method:(NSString*)method
                     headers:(NSDictionary*)headers;

-(BOOL)addUnsavedDelete:(NSString*)key
                  route:(NSString*)route
             collection:(NSString*)collection
                 method:(NSString*)method
                headers:(NSDictionary*)headers;

-(BOOL)removeUnsavedEntity:(NSString*)unsavedId
                     route:(NSString*)route
                collection:(NSString*)collection
                   headers:(NSDictionary*)headers;

-(NSArray*)unsavedEntities;

-(int)unsavedCount;

-(BOOL)setClientMetadata:(NSDictionary*)metadata;

-(NSDictionary*)clientMetadata;

/*
 This is not transactional, returns on first failure, but will still hold any previouslly passed objects.
 */
-(BOOL)import:(NSArray*)entities
        route:(NSString*)route
   collection:(NSString*)collection;

-(NSArray*)export:(NSString*)route
collection:(NSString*)collection;

#pragma mark - Management
- (void) clearCaches;

@optional

-(NSArray<NSObject<KCSPersistable>*>*)entitiesForQuery:(KCSQuery2*)query
                                                 route:(NSString*)route
                                            collection:(NSString*)collection;

-(NSObject<KCSPersistable>*)objectForId:(NSString*)_id
                                  route:(NSString*)route
                             collection:(NSString*)collection;

@end
