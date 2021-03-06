//
//  EntityTestCase.swift
//  Kinvey
//
//  Created by Victor Hugo on 2017-05-17.
//  Copyright © 2017 Kinvey. All rights reserved.
//

import XCTest
@testable import Kinvey
import Nimble

class EntityTestCase: XCTestCase {
    
    func testCollectionName() {
        expect { () -> Void in
            let _ = Entity.collectionName()
        }.to(throwAssertion())
    }
    
    func testBoolValue() {
        let value = true
        XCTAssertEqual(BoolValue(booleanLiteral: true).value, value)
        XCTAssertEqual(BoolValue(true).value, value)
    }
    
    func testDoubleValue() {
        let value: Double = 3.14159
        XCTAssertEqual(DoubleValue(floatLiteral: value).value, value)
        XCTAssertEqual(DoubleValue(value).value, value)
    }
    
    func testFloatValue() {
        let value: Float = 3.14159
        XCTAssertEqual(FloatValue(floatLiteral: value).value, value)
        XCTAssertEqual(FloatValue(value).value, value)
    }
    
    func testIntValue() {
        let value = 314159
        XCTAssertEqual(IntValue(integerLiteral: value).value, value)
        XCTAssertEqual(IntValue(value).value, value)
    }
    
    func testStringValue() {
        let value = "314159"
        XCTAssertEqual(StringValue(unicodeScalarLiteral: value).value, value)
        XCTAssertEqual(StringValue(extendedGraphemeClusterLiteral: value).value, value)
        XCTAssertEqual(StringValue(stringLiteral: value).value, value)
        XCTAssertEqual(StringValue(value).value, value)
    }
    
    func testGeoPointValidationParse() {
        let latitude = 42.3133521
        let longitude = -71.1271963
        XCTAssertNotNil(GeoPoint(JSON: ["latitude" : latitude, "longitude" : longitude]))
        XCTAssertNil(GeoPoint(JSON: ["latitude" : latitude]))
        XCTAssertNil(GeoPoint(JSON: ["longitude" : longitude]))
    }
    
    func testGeoPointMapping() {
        var geoPoint = GeoPoint()
        let latitude = 42.3133521
        let longitude = -71.1271963
        geoPoint <- ("geoPoint", Map(mappingType: .fromJSON, JSON: ["location" : [longitude, latitude]])["location"])
        XCTAssertEqual(geoPoint.latitude, latitude)
        XCTAssertEqual(geoPoint.longitude, longitude)
    }
    
    func testGeoPointMapping2() {
        var geoPoint: GeoPoint!
        let latitude = 42.3133521
        let longitude = -71.1271963
        geoPoint <- ("geoPoint", Map(mappingType: .fromJSON, JSON: ["location" : [longitude, latitude]])["location"])
        XCTAssertEqual(geoPoint.latitude, latitude)
        XCTAssertEqual(geoPoint.longitude, longitude)
    }
    
    func testPropertyType() {
        var clazz: AnyClass? = ObjCRuntime.typeForPropertyName(Person.self, propertyName: "name")
        XCTAssertNotNil(clazz)
        if let clazz = clazz {
            let clazzName = NSStringFromClass(clazz)
            XCTAssertEqual(clazzName, "NSString")
        }
        
        clazz = ObjCRuntime.typeForPropertyName(Person.self, propertyName: "geolocation")
        XCTAssertNotNil(clazz)
        if let clazz = clazz {
            let clazzName = NSStringFromClass(clazz)
            XCTAssertEqual(clazzName, "Kinvey.GeoPoint")
        }
        
        clazz = ObjCRuntime.typeForPropertyName(Person.self, propertyName: "address")
        XCTAssertNotNil(clazz)
        if let clazz = clazz {
            let clazzName = NSStringFromClass(clazz)
            let testBundleName = type(of: self).description().components(separatedBy: ".").first!
            XCTAssertEqual(clazzName, "\(testBundleName).Address")
        }
        
        clazz = ObjCRuntime.typeForPropertyName(Person.self, propertyName: "age")
        XCTAssertNil(clazz)
    }
    
}
