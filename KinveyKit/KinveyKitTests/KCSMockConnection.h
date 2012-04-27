//
//  KCSMockConnection.h
//  KinveyKit
//
//  Created by Brian Wilson on 12/12/11.
//  Copyright (c) 2011 Kinvey. All rights reserved.
//

#import "KCSConnection.h"

@class KCSConnectionResponse;

@interface KCSMockConnection : KCSConnection

@property (nonatomic) BOOL connectionShouldFail;
@property (nonatomic) BOOL connectionShouldReturnNow;

@property ( nonatomic) KCSConnectionResponse *responseForSuccess;
@property ( nonatomic) NSArray *progressActions;
@property ( nonatomic) NSError *errorForFailure;

// Delay in MSecs betwen each action...
@property (nonatomic) double delayInMSecs;

@property ( nonatomic) NSURLRequest *providedRequest;
@property ( nonatomic) NSURLCredential *providedCredentials;



@end
