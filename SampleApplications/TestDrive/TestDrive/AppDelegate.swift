//
//  AppDelegate.swift
//  TestDrive
//
//  Created by Victor Barros on 2016-01-27.
//  Copyright © 2016 Kinvey. All rights reserved.
//

import UIKit
import Kinvey
import PromiseKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    var client: Client!

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        
        client = Kinvey.sharedClient.initialize(appKey: "kid_WJg0WNTX5e", appSecret: "b321ba722b1c4dc4a084ad03a361a45a")
        
        let store = DataStore<Recipe>.getInstance()
        let chocolateCake = Recipe(name: "Chocolate Cake")
        
        Promise<User> { fulfill, reject in
            if let user = client.activeUser {
                fulfill(user)
            } else {
                User.exists(username: "test") { exists, error in
                    if exists {
                        User.login(username: "test", password: "test") { user, error in
                            if let user = user {
                                fulfill(user)
                            } else if let error = error {
                                reject(error)
                            }
                        }
                    } else {
                        User.signup(username: "test", password: "test") { user, error in
                            if let user = user {
                                fulfill(user)
                            } else if let error = error {
                                reject(error)
                            }
                        }
                    }
                }
            }
        }.then { _ in
            return Promise<Recipe> { fulfill, reject in
                store.save(chocolateCake) { recipe, error in
                    if let recipe = recipe {
                        print("Recipe: \(recipe.name!) (\(recipe.id!))")
                        fulfill(recipe)
                    } else if let error = error {
                        reject(error)
                    } else {
                        abort()
                    }
                }
            }
        }.then { recipe in
            return Promise<Recipe> { fulfill, reject in
                guard let recipeId = recipe.id else {
                    reject(Kinvey.Error.ObjectIdMissing)
                    return
                }
                store.findById(recipeId) { recipe, error in
                    if let recipe = recipe {
                        print("Recipe found by ID: \(recipe.toJson())")
                        fulfill(recipe)
                    } else if let error = error {
                        reject(error)
                    } else {
                        abort()
                    }
                }
            }
        }.then { recipe in
            return Promise<[Recipe]> { fulfill, reject in
                store.find() { recipes, error in
                    if let recipes = recipes {
                        print("Recipes found: \(recipes.count)")
                        fulfill(recipes)
                    } else if let error = error {
                        reject(error)
                    } else {
                        abort()
                    }
                }
            }
        }.then { _ in
            return Promise<UInt> { fulfill, reject in
                try store.push { count, error in
                    if let error = error {
                        reject(error)
                    } else if let count = count {
                        fulfill(count)
                    } else {
                        abort()
                    }
                }
            }
//        }.then { recipe in
//            return Promise<UInt> { fulfill, reject in
//                store.removeAll() { count, error in
//                    if let count = count {
//                        print("Recipes deleted: \(count)")
//                        fulfill(count)
//                    } else if let error = error {
//                        reject(error)
//                    } else {
//                        abort()
//                    }
//                }
//            }
        }.error { error in
            print("Error: \(error)")
        }
        
        // Override point for customization after application launch.
        return true
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

