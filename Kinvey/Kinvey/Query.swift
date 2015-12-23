//
//  Query.swift
//  Kinvey
//
//  Created by Victor Barros on 2015-12-08.
//  Copyright © 2015 Kinvey. All rights reserved.
//

import Foundation

public class Query: NSObject {
    
    private var _predicate: NSPredicate
    public var predicate: NSPredicate {
        get {
            return _predicate
        }
    }
    
    private var _sortDescriptors: [NSSortDescriptor]?
    public var sortDescriptors: [NSSortDescriptor]? {
        get {
            return _sortDescriptors
        }
    }
    
    public init(predicate: NSPredicate, sortDescriptors: [NSSortDescriptor]? = nil) {
        _predicate = predicate
        _sortDescriptors = sortDescriptors
    }
    
    public override convenience init() {
        self.init(predicate: NSPredicate())
    }
    
    public convenience init(format: String, _ args: AnyObject...) {
        self.init(format: format, argumentArray: args)
    }
    
    public convenience init(format: String, args: CVarArgType) {
        self.init(predicate: NSPredicate(format: format, args))
    }
    
    public convenience init(format: String, argumentArray: [AnyObject]?) {
        self.init(predicate: NSPredicate(format: format, argumentArray: argumentArray))
    }
    
    public convenience init(format: String, arguments: CVaListPointer) {
        self.init(predicate: NSPredicate(format: format, arguments: arguments))
    }

}
