//
//  KCSCallbacksInMainThreadTests.swift
//  KinveyKit
//
//  Created by Victor Barros on 2015-06-12.
//  Copyright (c) 2015 Kinvey. All rights reserved.
//

import XCTest

class KCSCallbacksInMainThreadTests: XCTestCase {
    
    var collection: KCSCollection!
    var store: KCSCachedStore!
    
    var objectId: String!

    override func setUp() {
        super.setUp()
        
        KCSClient.sharedClient().initializeKinveyServiceForAppKey(
            "kid_-1WAs8Rh2",
            withAppSecret: "2f355bfaa8cb4f7299e914e8e85d8c98",
            usingOptions: nil
        )
        
        weak var expectationLogin = expectationWithDescription("login")
        
        KCSUser.createAutogeneratedUser(nil, completion: { (user: KCSUser!, error: NSError!, actionResult: KCSUserActionResult) -> Void in
            expectationLogin?.fulfill()
        })
        
        waitForExpectationsWithTimeout(30, handler: nil)
        
        collection = KCSCollection(fromString: "city", ofClass: NSMutableDictionary.self)
        store = KCSCachedStore(collection: collection, options: [
            KCSStoreKeyCachePolicy : KCSCachePolicy.NetworkFirst.rawValue
        ])
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testLoadObjectID() {
        saveObject()
        loadObjectID()
    }
    
    func testLoadObjectIDWithCachePolicyNetworkFirst() {
        saveObject()
        loadObjectIDWithCachePolicy(.NetworkFirst)
    }
    
    func testLoadObjectIDWithCachePolicyLocalFirst() {
        saveObject()
        loadObjectIDWithCachePolicy(.LocalFirst)
    }
    
    func testLoadObjectIDWithCachePolicyLocalOnly() {
        saveObject()
        loadObjectIDWithCachePolicy(.LocalOnly)
    }
    
    func testLoadObjectIDWithCachePolicyNone() {
        saveObject()
        loadObjectIDWithCachePolicy(.None)
    }
    
    func testLoadObjectIDWithCachePolicyBoth() {
        saveObject()
        loadObjectIDWithCachePolicy(.Both)
    }
    
    func testSaveObject() {
        saveObject()
    }
    
    func testRemoveObject() {
        saveObject()
        removeObject()
    }
    
    func testQuery() {
        saveObject()
        query()
    }
    
    func testCount() {
        saveObject()
        count()
    }
    
    func loadObjectID() {
        weak var expectationCallback = expectationWithDescription("callback")
        
        store.loadObjectWithID(
            self.objectId,
            withCompletionBlock: { (results: [AnyObject]!, error: NSError!) -> Void in
                XCTAssertTrue(NSThread.isMainThread())
                
                expectationCallback?.fulfill()
            },
            withProgressBlock: { (results: [AnyObject]!, percentage: Double) -> Void in
                XCTAssertTrue(NSThread.isMainThread())
            }
        )
        
        waitForExpectationsWithTimeout(30, handler: nil)
    }
    
    func loadObjectIDWithCachePolicy(cachePolicy: KCSCachePolicy) {
        weak var expectationCallback = expectationWithDescription("callback")
        
        store.loadObjectWithID(
            self.objectId,
            withCompletionBlock: { (results: [AnyObject]!, error: NSError!) -> Void in
                XCTAssertTrue(NSThread.isMainThread())
                
                expectationCallback?.fulfill()
            },
            withProgressBlock: { (results: [AnyObject]!, percentage: Double) -> Void in
                XCTAssertTrue(NSThread.isMainThread())
            },
            cachePolicy: cachePolicy
        )
        
        waitForExpectationsWithTimeout(30, handler: nil)
    }
    
    func saveObject() {
        weak var expectationCallback = expectationWithDescription("callback")
        
        store.saveObject(
            ["name":"Boston"],
            withCompletionBlock: { (results: [AnyObject]!, error: NSError!) -> Void in
                XCTAssertTrue(NSThread.isMainThread())
                
                self.objectId = (results?.first as! NSDictionary)["_id"] as? String
                
                expectationCallback?.fulfill()
            },
            withProgressBlock: { (results: [AnyObject]!, percentage: Double) -> Void in
                XCTAssertTrue(NSThread.isMainThread())
            }
        )
        
        waitForExpectationsWithTimeout(30, handler: nil)
    }
    
    func removeObject() {
        weak var expectationCallback = expectationWithDescription("callback")
        
        store.removeObject(
            self.objectId,
            withCompletionBlock: { (count: UInt, error: NSError!) -> Void in
                XCTAssertTrue(NSThread.isMainThread())
                
                expectationCallback?.fulfill()
            },
            withProgressBlock: { (results: [AnyObject]!, percentage: Double) -> Void in
                XCTAssertTrue(NSThread.isMainThread())
            }
        )
        
        waitForExpectationsWithTimeout(30, handler: nil)
    }
    
    func query() {
        weak var expectationCallback = expectationWithDescription("callback")
        
        store.queryWithQuery(
            KCSQuery(),
            withCompletionBlock: { (results: [AnyObject]!, error: NSError!) -> Void in
                XCTAssertTrue(NSThread.isMainThread())
                
                expectationCallback?.fulfill()
            },
            withProgressBlock: { (results: [AnyObject]!, percentage: Double) -> Void in
                XCTAssertTrue(NSThread.isMainThread())
            }
        )
        
        waitForExpectationsWithTimeout(30, handler: nil)
    }
    
    func count() {
        weak var expectationCallback = expectationWithDescription("callback")
        
        store.countWithBlock { (count: UInt, error: NSError!) -> Void in
            XCTAssertTrue(NSThread.isMainThread())
            
            expectationCallback?.fulfill()
        }
        
        waitForExpectationsWithTimeout(30, handler: nil)
    }

}
