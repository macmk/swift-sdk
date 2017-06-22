//
//  BuilderType.swift
//  Kinvey
//
//  Created by Victor Barros on 2016-08-12.
//  Copyright © 2016 Kinvey. All rights reserved.
//

import Foundation

/// Enables a type to be able to have a builder constructor.
public protocol BuilderType {
    
    /// Default Constructor.
    init()
    
    /// Builder Constructor.
    init(_ block: (Self) -> Void)
    
}

/// Builder constructor implementation.
extension BuilderType {
    
    /// Builder Constructor.
    public init(_ block: (Self) -> Void) {
        var obj: Self!
        if let clazz = Self.self as? NSObject.Type {
            obj = (clazz.init() as! Self)
        } else {
            obj = Self.self.init()
        }
        self = obj
        block(self)
    }
    
}
