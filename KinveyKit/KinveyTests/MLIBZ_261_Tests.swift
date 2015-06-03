//
//  MLIBZ_261_Tests.swift
//  KinveyKit
//
//  Created by Victor Barros on 2015-06-01.
//  Copyright (c) 2015 Kinvey. All rights reserved.
//

import UIKit
import XCTest

class MLIBZ_261_Tests: XCTestCase {
    
    let n = 100
    
    func login(#appKey: String, appSecret: String, username: String, password: String) {
        KCSClient.sharedClient().initializeKinveyServiceForAppKey(appKey, withAppSecret: appSecret, usingOptions: nil)
        
        let expectationLogin = expectationWithDescription("login")
        
        let params = [
            KCSUsername : username,
            KCSPassword : password
        ]
        KCSUser.loginWithAuthorizationCodeAPI("http://us-staging.merial.com/kinvey/api/Authenticate", options: params) { (user: KCSUser!, error: NSError!, actionResult: KCSUserActionResult) -> Void in
            XCTAssertNotNil(user)
            XCTAssertNil(error)
            
            if (user != nil) {
                NSLog("User ID: \(user.userId)")
                NSLog("Username: \(user.username)")
            }
            
            expectationLogin.fulfill()
        }
        
        waitForExpectationsWithTimeout(30, handler: nil)
    }
    
    func runTest() {
        let params = [
            "access" : "feed",
            "limit" : "7",
            "skip" : "7"
        ]
        
        let expectationCall = expectationWithDescription("call")
        
        KCSCustomEndpoints.callEndpoint("Feed", params: params) { (results: AnyObject!, error: NSError!) -> Void in
            XCTAssertNotNil(results)
            XCTAssertNil(error)
            
            expectationCall.fulfill()
        }
    }
    
    func runTest(n: Int) {
        for _ in 1...n {
            runTest()
        }
        
        waitForExpectationsWithTimeout(NSTimeInterval(30 * n), handler: nil)
    }
    
    func testDevelopment() {
        login(appKey: "kid_-k8AUP2hw", appSecret: "baf2a70a7fc1497ba00614528be622dd", username: "chicksabcs@gmail.com", password: "cowboy43")
        
        runTest(n)
        
        KCSUser.activeUser().logout()
    }
    
    func testStaging() {
        login(appKey: "kid_bk8DBVAao", appSecret: "db250c3456d148579d79b2852c773f19", username: "chicksabcs@gmail.com", password: "cowboy43")
        
        runTest(n)
        
        KCSUser.activeUser().logout()
    }

}
