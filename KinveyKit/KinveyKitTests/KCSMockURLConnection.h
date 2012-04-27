//
//  KCSMockURLConnection.h
//  KinveyKit
//
//  Created by Brian Wilson on 12/12/11.
//  Copyright (c) 2011 Kinvey. All rights reserved.
//

#import <Foundation/Foundation.h>

// Fake connection object
@interface KCSMockURLConnection : NSURLConnection

@property (unsafe_unretained, nonatomic) id delegate;
@property ( nonatomic) NSURLRequest *request;

@end
