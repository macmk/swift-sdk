//
//  DataTypeTestCase.swift
//  Kinvey
//
//  Created by Victor Barros on 2016-04-22.
//  Copyright © 2016 Kinvey. All rights reserved.
//

import XCTest
@testable import Kinvey
import ObjectMapper
import Foundation

#if os(macOS)
    typealias Color = NSColor
    typealias FontDescriptor = NSFontDescriptor
#else
    typealias Color = UIColor
    typealias FontDescriptor = UIFontDescriptor
#endif

class DataTypeTestCase: StoreTestCase {
    
    func testSave() {
        signUp()
        
        let store = DataStore<DataType>.collection(.network)
        let dataType = DataType()
        dataType.boolValue = true
        dataType.colorValue = Color.orange
        
        
        let fullName = FullName()
        fullName.firstName = "Victor"
        fullName.lastName = "Barros"
        dataType.fullName = fullName
        
        let fullName2 = FullName2()
        fullName2.firstName = "Victor"
        fullName2.lastName = "Barros"
        fullName2.fontDescriptor = FontDescriptor(name: "Arial", size: 12)
        dataType.fullName2 = fullName2
        
        let tuple = save(dataType, store: store) {
            var json = $0
            var fullName = json["fullName"] as! JsonDictionary
            fullName["_id"] = UUID().uuidString
            json["fullName"] = fullName
            return json
        }
        
        XCTAssertNotNil(tuple.savedPersistable)
        if let savedPersistable = tuple.savedPersistable {
            XCTAssertTrue(savedPersistable.boolValue)
        }
        
        let query = Query(format: "acl.creator == %@", client.activeUser!.userId)
        
        mockResponse(json: [
            [
                "_id" : UUID().uuidString,
                "fullName2" : [
                    "lastName" : "Barros",
                    "fontDescriptor" : [
                        "NSFontSizeAttribute" : 12,
                        "NSFontNameAttribute" : "Arial"
                    ],
                    "firstName" : "Victor"
                ],
                "boolValue" : true,
                "fullName" : [
                    "_id" : UUID().uuidString,
                    "lastName" : "Barros",
                    "firstName" : "Victor"
                ],
                "colorValue" : [
                    "green" : 0.5,
                    "alpha" : 1,
                    "red" : 1,
                    "blue" : 0
                ],
                "_acl" : [
                    "creator" : UUID().uuidString
                ],
                "_kmd" : [
                    "lmt" : Date().toString(),
                    "ect" : Date().toString()
                ]
            ]
        ])
        
        weak var expectationFind = expectation(description: "Find")
        
        store.find(query) { results, error in
            XCTAssertNotNil(results)
            XCTAssertNil(error)
            
            if let results = results {
                XCTAssertEqual(results.count, 1)
                
                if let dataType = results.first {
                    XCTAssertTrue(dataType.boolValue)
                    XCTAssertEqual(dataType.colorValue, Color.orange)
                    
                    XCTAssertNotNil(dataType.fullName)
                    if let fullName = dataType.fullName {
                        XCTAssertEqual(fullName.firstName, "Victor")
                        XCTAssertEqual(fullName.lastName, "Barros")
                    }
                    
                    XCTAssertNotNil(dataType.fullName2)
                    if let fullName = dataType.fullName2 {
                        XCTAssertEqual(fullName.firstName, "Victor")
                        XCTAssertEqual(fullName.lastName, "Barros")
                        XCTAssertEqual(fullName.fontDescriptor, FontDescriptor(name: "Arial", size: 12))
                    }
                }
            }
            
            expectationFind?.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout) { (error) in
            expectationFind = nil
        }
    }
    
    func testDate() {
        signUp()
        
        let store = DataStore<EntityWithDate>.collection(.network)
        
        let dateEntity = EntityWithDate()
        dateEntity.date = Date()

        let tuple = save(dateEntity, store: store)
        XCTAssertNotNil(tuple.savedPersistable)

        if let savedPersistable = tuple.savedPersistable {
            XCTAssertTrue((savedPersistable.date != nil))
        }
        
        if useMockData {
            mockResponse(json: [
                [
                    "_id" : UUID().uuidString,
                    "date" : Date().toString(),
                    "_acl" : [
                        "creator" : UUID().uuidString
                    ],
                    "_kmd" : [
                        "lmt" : Date().toString(),
                        "ect" : Date().toString()
                    ]
                ]
            ])
        }
        defer {
            if useMockData {
                setURLProtocol(nil)
            }
        }

        weak var expectationFind = expectation(description: "Find")
        
        let query = Query(format: "acl.creator == %@", client.activeUser!.userId)
        
        store.find(query) { results, error in
            XCTAssertNotNil(results)
            XCTAssertNil(error)
            
            if let results = results {
                XCTAssertGreaterThan(results.count, 0)
                
                if let dataType = results.first {
                    XCTAssertNotNil(dataType.date)
                }
            }
            
            expectationFind?.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout) { (error) in
            expectationFind = nil
        }

    }
    
    func testDateReadFormats() {
        let transform = KinveyDateTransform()
        XCTAssertEqual(transform.transformFromJSON("ISODate(\"2016-11-14T10:05:55.787Z\")"), Date(timeIntervalSince1970: 1479117955.787))
        XCTAssertEqual(transform.transformFromJSON("2016-11-14T10:05:55.787Z"), Date(timeIntervalSince1970: 1479117955.787))
        XCTAssertEqual(transform.transformFromJSON("2016-11-14T10:05:55.787-0500"), Date(timeIntervalSince1970: 1479135955.787))
        XCTAssertEqual(transform.transformFromJSON("2016-11-14T10:05:55.787+0100"), Date(timeIntervalSince1970: 1479114355.787))
        
        XCTAssertEqual(transform.transformFromJSON("ISODate(\"2016-11-14T10:05:55Z\")"), Date(timeIntervalSince1970: 1479117955))
        XCTAssertEqual(transform.transformFromJSON("2016-11-14T10:05:55Z"), Date(timeIntervalSince1970: 1479117955))
        XCTAssertEqual(transform.transformFromJSON("2016-11-14T10:05:55-0500"), Date(timeIntervalSince1970: 1479135955))
        XCTAssertEqual(transform.transformFromJSON("2016-11-14T10:05:55+0100"), Date(timeIntervalSince1970: 1479114355))
    }
    
    func testDateWriteFormats() {
        let transform = KinveyDateTransform()
        XCTAssertEqual(transform.transformToJSON(Date(timeIntervalSince1970: 1479117955.787)), "2016-11-14T10:05:55.787Z")
        XCTAssertEqual(transform.transformToJSON(Date(timeIntervalSince1970: 1479135955.787)), "2016-11-14T15:05:55.787Z")
        XCTAssertEqual(transform.transformToJSON(Date(timeIntervalSince1970: 1479114355.787)), "2016-11-14T09:05:55.787Z")
    }
    
    func testPropertyMapping() {
        let propertyMapping = Book.propertyMapping()
        var entityId = false,
        metadata = false,
        acl = false,
        title = false,
        authorNames = false,
        editions = false,
        editionsYear = false,
        editionsRetailPrice = false,
        editionsRating = false,
        editionsAvailable = false
        for (left, (right, _)) in propertyMapping {
            switch left {
            case "entityId":
                XCTAssertEqual(right, "_id")
                entityId = true
            case "metadata":
                XCTAssertEqual(right, "_kmd")
                metadata = true
            case "acl":
                XCTAssertEqual(right, "_acl")
                acl = true
            case "title":
                XCTAssertEqual(right, "title")
                title = true
            case "authorNames":
                XCTAssertEqual(right, "authorNames")
                authorNames = true
            case "editions":
                XCTAssertEqual(right, "editions")
                editions = true
            case "editionsYear":
                XCTAssertEqual(right, "editionsYear")
                editionsYear = true
            case "editionsRetailPrice":
                XCTAssertEqual(right, "editionsRetailPrice")
                editionsRetailPrice = true
            case "editionsRating":
                XCTAssertEqual(right, "editionsRating")
                editionsRating = true
            case "editionsAvailable":
                XCTAssertEqual(right, "editionsAvailable")
                editionsAvailable = true
            default:
                XCTFail()
            }
        }
        
        XCTAssertTrue(entityId)
        XCTAssertTrue(metadata)
        XCTAssertTrue(acl)
        XCTAssertTrue(title)
        XCTAssertTrue(authorNames)
        XCTAssertTrue(editions)
        XCTAssertTrue(editionsYear)
        XCTAssertTrue(editionsRetailPrice)
        XCTAssertTrue(editionsRating)
        XCTAssertTrue(editionsAvailable)
    }
    
}

class EntityWithDate : Entity {
    dynamic var date:Date?
    
    override class func collectionName() -> String {
        return "DataType"
    }
    
    override func propertyMapping(_ map: Map) {
        super.propertyMapping(map)
        
        date <- ("date", map["date"], KinveyDateTransform())
    }
}

class ColorTransformType : TransformType {
    
    typealias Object = Color
    typealias JSON = JsonDictionary
    
    func transformFromJSON(_ value: Any?) -> Color? {
        if let value = value as? JsonDictionary,
            let red = value["red"] as? CGFloat,
            let green = value["green"] as? CGFloat,
            let blue = value["blue"] as? CGFloat,
            let alpha = value["alpha"] as? CGFloat
        {
            #if os(macOS)
                if #available(OSX 10.13, *) {
                    return Color(srgbRed: red, green: green, blue: blue, alpha: alpha)
                } else {
                    return Color(calibratedRed: red, green: green, blue: blue, alpha: alpha).usingColorSpaceName(NSCalibratedRGBColorSpace)
                }
            #else
                return Color(red: red, green: green, blue: blue, alpha: alpha)
            #endif
        }
        return nil
    }
    
    func transformToJSON(_ value: Color?) -> JsonDictionary? {
        if let value = value {
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 9
            value.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            return [
                "red" : red,
                "green" : green,
                "blue" : blue,
                "alpha" : alpha
            ]
        }
        return nil
    }
    
}

class DataType: Entity {
    
    dynamic var boolValue: Bool = false
    dynamic var fullName: FullName?
    
    fileprivate dynamic var fullName2Value: String?
    dynamic var fullName2: FullName2?
    
    dynamic var objectValue: NSObject?
    dynamic var stringValueNotOptional: String! = ""
    dynamic var fullName2DefaultValue = FullName2()
    dynamic var fullName2DefaultValueNotOptional: FullName2! = FullName2()
    dynamic var fullName2DefaultValueTransformed = FullName2()
    dynamic var fullName2DefaultValueNotOptionalTransformed: FullName2! = FullName2()
    
    fileprivate dynamic var colorValueString: String?
    dynamic var colorValue: Color? {
        get {
            if let colorValueString = colorValueString,
                let data = colorValueString.data(using: String.Encoding.utf8),
                let json = try? JSONSerialization.jsonObject(with: data)
            {
                return ColorTransformType().transformFromJSON(json as AnyObject?)
            }
            return nil
        }
        set {
            if let newValue = newValue,
                let json = ColorTransformType().transformToJSON(newValue),
                let data = try? JSONSerialization.data(withJSONObject: json),
                let stringValue = String(data: data, encoding: String.Encoding.utf8)
            {
                colorValueString = stringValue
            } else {
                colorValueString = nil
            }
        }
    }
    
    override class func collectionName() -> String {
        return "DataType"
    }
    
    override func propertyMapping(_ map: Map) {
        super.propertyMapping(map)
        
        boolValue <- map["boolValue"]
        colorValue <- (map["colorValue"], ColorTransformType())
        fullName <- map["fullName"]
        fullName2 <- ("fullName2", map["fullName2"], FullName2TransformType())
        stringValueNotOptional <- ("stringValueNotOptional", map["stringValueNotOptional"])
        fullName2DefaultValue <- ("fullName2DefaultValue", map["fullName2DefaultValue"])
        fullName2DefaultValueNotOptional <- ("fullName2DefaultValueNotOptional", map["fullName2DefaultValueNotOptional"])
        fullName2DefaultValueTransformed <- ("fullName2DefaultValueTransformed", map["fullName2DefaultValueTransformed"], FullName2TransformType())
        fullName2DefaultValueNotOptionalTransformed <- ("fullName2DefaultValueNotOptionalTransformed", map["fullName2DefaultValueNotOptionalTransformed"], FullName2TransformType())
    }
    
    override class func ignoredProperties() -> [String] {
        return [
            "objectValue",
            "colorValue",
            "fullName2",
            "fullName2DefaultValue",
            "fullName2DefaultValueNotOptional",
            "fullName2DefaultValueTransformed",
            "fullName2DefaultValueNotOptionalTransformed"
        ]
    }
    
}

class FullName: Entity {
    
    dynamic var firstName: String?
    dynamic var lastName: String?
    
    override class func collectionName() -> String {
        return "FullName"
    }
    
    override func propertyMapping(_ map: Map) {
        super.propertyMapping(map)
        
        firstName <- map["firstName"]
        lastName <- map["lastName"]
    }
    
}

class FullName2TransformType: TransformType {
    
    typealias Object = FullName2
    typealias JSON = JsonDictionary
    
    func transformFromJSON(_ value: Any?) -> FullName2? {
        if let value = value as? JsonDictionary {
            return FullName2(JSON: value)
        }
        return nil
    }
    
    func transformToJSON(_ value: FullName2?) -> JsonDictionary? {
        if let value = value {
            return value.toJSON()
        }
        return nil
    }
    
}

class FullName2: NSObject, Mappable {
    
    dynamic var firstName: String?
    dynamic var lastName: String?
    dynamic var fontDescriptor: FontDescriptor?
    
    override init() {
    }
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        firstName <- map["firstName"]
        lastName <- map["lastName"]
        fontDescriptor <- (map["fontDescriptor"], FontDescriptorTransformType())
    }
    
}

class FontDescriptorTransformType: TransformType {
    
    typealias Object = FontDescriptor
    typealias JSON = JsonDictionary
    
    struct Attribute {
        
        #if !os(macOS)
            static let name = UIFontDescriptorNameAttribute
            static let size = UIFontDescriptorSizeAttribute
        #else
            static let name = NSFontNameAttribute
            static let size = NSFontSizeAttribute
        #endif
        
    }
    
    func transformFromJSON(_ value: Any?) -> Object? {
        if let value = value as? JsonDictionary,
            let fontName = value[Attribute.name] as? String,
            let fontSize = value[Attribute.size] as? CGFloat
        {
            return FontDescriptor(name: fontName, size: fontSize)
        }
        return nil
    }
    
    func transformToJSON(_ value: Object?) -> JSON? {
        if let value = value {
            return [
                Attribute.name : value.fontAttributes[Attribute.name]!,
                Attribute.size : value.fontAttributes[Attribute.size]!
            ]
        }
        return nil
    }
    
}
