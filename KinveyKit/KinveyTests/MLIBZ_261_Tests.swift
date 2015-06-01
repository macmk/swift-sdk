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

    override func setUp() {
        super.setUp()
        
        KCSClient.sharedClient().initializeKinveyServiceForAppKey("kid_-k8AUP2hw", withAppSecret: "baf2a70a7fc1497ba00614528be622dd", usingOptions: nil)
        
        let expectationLogin = expectationWithDescription("login")
        
        let info = ["token_type":"bearer","access_token":"077696cbe13ed6c9e9ff71ec496c627bdd68758b","expires_in":1209600,"refresh_token":"bbbdecd02e47953e220b24b56044fe15109f8a2f", "redirect_uri" : "http://us-staging.merial.com/kinvey/api/Authenticate"]
        KCSUser.loginWithSocialIdentity(KCSUserSocialIdentifyProvider.SocialIDKinvey, accessDictionary: info) { (user: KCSUser!, error: NSError!, actionResult: KCSUserActionResult) -> Void in
            NSLog("User ID: \(user.userId)")
            NSLog("Username: \(user.username)")
            
            XCTAssertNotNil(user)
            XCTAssertNil(error)
            
            expectationLogin.fulfill()
        }
        
        waitForExpectationsWithTimeout(30, handler: nil)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func test() {
        for _ in 1...10 {
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
            
            waitForExpectationsWithTimeout(30, handler: nil)
        }
    }

}
