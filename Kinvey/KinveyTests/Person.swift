//
//  Person.swift
//  Kinvey
//
//  Created by Victor Barros on 2016-04-05.
//  Copyright © 2016 Kinvey. All rights reserved.
//

@testable import Kinvey
import RealmSwift
import ObjectiveC

class Person: Entity {
    
    dynamic var personId: String?
    dynamic var name: String?
    dynamic var age: Int = 0
    
    dynamic var address: Address?
    
    dynamic var color: UIColor?
    
    override class func collectionName() -> String {
        return "Person"
    }
    
    override func propertyMapping(map: Map) {
        super.propertyMapping(map)
        
        personId <- ("personId", map[PersistableIdKey])
        name <- map["name"]
        age <- map["age"]
        address <- ("address", map["address"])
        color <- ("color", map["color"], ColorTransform())
    }
    
}

class ColorTransform: TransformType {
    
    typealias Object = UIColor
    typealias JSON = [String : CGFloat]
    
    func transformFromJSON(value: AnyObject?) -> Object? {
        if let value = value as? JSON,
            let red = value["red"],
            let green = value["green"],
            let blue = value["blue"],
            let alpha = value["alpha"]
        {
            return UIColor(red: red, green: green, blue: blue, alpha: alpha)
        }
        return nil
    }
    
    func transformToJSON(value: Object?) -> JSON? {
        if let value = value {
            var red = CGFloat(0)
            var green = CGFloat(0)
            var blue = CGFloat(0)
            var alpha = CGFloat(0)
            if value.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
                return [
                    "red" : red,
                    "green" : green,
                    "blue" : blue,
                    "alpha" : alpha
                ]
            }
        }
        return nil
    }
    
}

class Address: Entity {
    
    dynamic var city: String?
    
    override func propertyMapping(map: Map) {
        super.propertyMapping(map)
        
        city <- map["city"]
    }
    
}
