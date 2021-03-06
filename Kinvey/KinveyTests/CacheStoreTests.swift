//
//  CachedStoreTests.swift
//  Kinvey
//
//  Created by Victor Barros on 2015-12-15.
//  Copyright © 2015 Kinvey. All rights reserved.
//

import XCTest
@testable import Kinvey
import RealmSwift

class CacheStoreTests: StoreTestCase {
    
    override func setUp() {
        super.setUp()
        
        signUp()
        
        store = DataStore<Person>.collection(.cache)
    }
    
    func testSaveAddress() {
        let person = Person()
        person.name = "Victor Barros"
        
        weak var expectationSaveLocal = expectation(description: "Save Local")
        weak var expectationSaveNetwork = expectation(description: "Save Network")
        
        var runCount = 0
        var temporaryObjectId: String? = nil
        var finalObjectId: String? = nil
        
        if useMockData {
            mockResponse {
                let json = try! JSONSerialization.jsonObject(with: $0) as? JsonDictionary
                return HttpResponse(statusCode: 201, json: [
                    "_id" : json?["_id"] as? String ?? UUID().uuidString,
                    "name" : "Victor Barros",
                    "age" : 0,
                    "_acl" : [
                        "creator" : UUID().uuidString
                    ],
                    "_kmd" : [
                        "lmt" : Date().toString(),
                        "ect" : Date().toString()
                    ]
                ])
            }
        }
        defer {
            if useMockData {
                setURLProtocol(nil)
            }
        }
        
        store.save(person) { person, error in
            XCTAssertNotNil(person)
            XCTAssertNil(error)
            
            switch runCount {
            case 0:
                if let person = person {
                    XCTAssertNotNil(person.personId)
                    if let personId = person.personId {
                        XCTAssertTrue(personId.hasPrefix(ObjectIdTmpPrefix))
                        temporaryObjectId = personId
                    }
                }
                
                expectationSaveLocal?.fulfill()
            case 1:
                if let person = person {
                    XCTAssertNotNil(person.personId)
                    if let personId = person.personId {
                        XCTAssertFalse(personId.hasPrefix(ObjectIdTmpPrefix))
                        finalObjectId = personId
                    }
                }
                
                expectationSaveNetwork?.fulfill()
            default:
                break
            }
            
            runCount += 1
        }
        
        waitForExpectations(timeout: defaultTimeout) { error in
            expectationSaveLocal = nil
            expectationSaveNetwork = nil
        }
        
        XCTAssertEqual(store.syncCount(), 0)
        
        XCTAssertNotNil(temporaryObjectId)
        if let temporaryObjectId = temporaryObjectId {
            weak var expectationFind = expectation(description: "Find")
            
            store.find(byId: temporaryObjectId, readPolicy: .forceLocal) { (person, error) in
                XCTAssertNil(person)
                XCTAssertNotNil(error)
                
                expectationFind?.fulfill()
            }
            
            waitForExpectations(timeout: defaultTimeout) { error in
                expectationFind = nil
            }
        }
        
        XCTAssertNotNil(finalObjectId)
        if let finalObjectId = finalObjectId {
            weak var expectationRemove = expectation(description: "Remove")
            
            store.removeById(finalObjectId, writePolicy: .forceLocal) { (count, error) in
                XCTAssertNotNil(count)
                XCTAssertNil(error)
                
                XCTAssertEqual(count, 1)
                
                expectationRemove?.fulfill()
            }
            
            waitForExpectations(timeout: defaultTimeout) { error in
                expectationRemove = nil
            }
        }
    }
    
    func testArrayProperty() {
        let book = Book()
        book.title = "Swift for the win!"
        book.authorNames.append("Victor Barros")
        
        do {
            if useMockData {
                mockResponse(completionHandler: { request in
                    var json = try! JSONSerialization.jsonObject(with: request) as! JsonDictionary
                    json += [
                        "_id" : UUID().uuidString,
                        "_acl" : [
                            "creator" : UUID().uuidString
                        ],
                        "_kmd" : [
                            "lmt" : Date().toString(),
                            "ect" : Date().toString()
                        ]
                    ]
                    return HttpResponse(json: json)
                })
            }
            defer {
                if useMockData {
                    setURLProtocol(nil)
                }
            }
            
            do {
                weak var expectationSaveNetwork = expectation(description: "Save Network")
                weak var expectationSaveLocal = expectation(description: "Save Local")
                
                let store = DataStore<Book>.collection(.cache)
                store.save(book) { book, error in
                    XCTAssertNotNil(book)
                    XCTAssertNil(error)
                    
                    if let book = book {
                        XCTAssertEqual(book.title, "Swift for the win!")
                        
                        XCTAssertEqual(book.authorNames.count, 1)
                        XCTAssertEqual(book.authorNames.first?.value, "Victor Barros")
                    }
                    
                    if expectationSaveLocal != nil {
                        expectationSaveLocal?.fulfill()
                        expectationSaveLocal = nil
                    } else {
                        expectationSaveNetwork?.fulfill()
                    }
                }
                
                waitForExpectations(timeout: defaultTimeout) { error in
                    expectationSaveNetwork = nil
                    expectationSaveLocal = nil
                }
            }
            
            do {
                weak var expectationFind = expectation(description: "Find")
                
                let store = DataStore<Book>.collection(.sync)
                store.find { books, error in
                    XCTAssertNotNil(books)
                    XCTAssertNil(error)
                    
                    if let books = books {
                        XCTAssertEqual(books.count, 1)
                        if let book = books.first {
                            XCTAssertEqual(book.title, "Swift for the win!")
                            
                            XCTAssertEqual(book.authorNames.count, 1)
                            XCTAssertEqual(book.authorNames.first?.value, "Victor Barros")
                        }
                    }
                    
                    expectationFind?.fulfill()
                }
                
                waitForExpectations(timeout: defaultTimeout) { error in
                    expectationFind = nil
                }
            }
            
            do {
                weak var expectationFind = expectation(description: "Find")
                
                let store = DataStore<Book>.collection(.sync)
                let query = Query(format: "authorNames contains %@", "Victor Barros")
                store.find(query) { books, error in
                    XCTAssertNotNil(books)
                    XCTAssertNil(error)
                    
                    if let books = books {
                        XCTAssertEqual(books.count, 1)
                        if let book = books.first {
                            XCTAssertEqual(book.title, "Swift for the win!")
                            
                            XCTAssertEqual(book.authorNames.count, 1)
                            XCTAssertEqual(book.authorNames.first?.value, "Victor Barros")
                        }
                    }
                    
                    expectationFind?.fulfill()
                }
                
                waitForExpectations(timeout: defaultTimeout) { error in
                    expectationFind = nil
                }
            }
            
            do {
                weak var expectationFind = expectation(description: "Find")
                
                let store = DataStore<Book>.collection(.sync)
                let query = Query(format: "subquery(authorNames, $authorNames, $authorNames like[c] %@).@count > 0", "Vic*")
                store.find(query) { books, error in
                    XCTAssertNotNil(books)
                    XCTAssertNil(error)
                    
                    if let books = books {
                        XCTAssertEqual(books.count, 1)
                        if let book = books.first {
                            XCTAssertEqual(book.title, "Swift for the win!")
                            
                            XCTAssertEqual(book.authorNames.count, 1)
                            XCTAssertEqual(book.authorNames.first?.value, "Victor Barros")
                        }
                    }
                    
                    expectationFind?.fulfill()
                }
                
                waitForExpectations(timeout: defaultTimeout) { error in
                    expectationFind = nil
                }
            }
        }
    }
    
    func testFindCache() {
        let book = Book()
        book.title = "Swift for the win!"
        book.authorNames.append("Victor Barros")
        
        let book1stEdition = BookEdition()
        book1stEdition.year = 2017
        book.editions.append(book1stEdition)
        
        let book2ndEdition = BookEdition()
        book2ndEdition.year = 2016
        book.editions.append(book2ndEdition)
        
        if useMockData {
            var mockJson: JsonDictionary? = nil
            var count = 0
            mockResponse { request in
                defer {
                    count += 1
                }
                switch count {
                case 0:
                    var json = try! JSONSerialization.jsonObject(with: request) as! JsonDictionary
                    json += [
                        "_id" : UUID().uuidString,
                        "_acl" : [
                            "creator" : UUID().uuidString
                        ],
                        "_kmd" : [
                            "lmt" : Date().toString(),
                            "ect" : Date().toString()
                        ]
                    ]
                    mockJson = json
                    return HttpResponse(json: json)
                case 1:
                    return HttpResponse(json: [mockJson!])
                default:
                    Swift.fatalError()
                }
            }
        }
        defer {
            if useMockData {
                setURLProtocol(nil)
            }
        }
        
        do {
            weak var expectationSaveNetwork = expectation(description: "Save Network")
            weak var expectationSaveLocal = expectation(description: "Save Local")
            
            let store = DataStore<Book>.collection(.cache)
            store.save(book) { book, error in
                XCTAssertNotNil(book)
                XCTAssertNil(error)
                
                if let book = book {
                    XCTAssertEqual(book.title, "Swift for the win!")
                    
                    XCTAssertEqual(book.authorNames.count, 1)
                    XCTAssertEqual(book.authorNames.first?.value, "Victor Barros")
                }
                
                if expectationSaveLocal != nil {
                    expectationSaveLocal?.fulfill()
                    expectationSaveLocal = nil
                } else {
                    expectationSaveNetwork?.fulfill()
                }
            }
            
            waitForExpectations(timeout: defaultTimeout) { error in
                expectationSaveNetwork = nil
                expectationSaveLocal = nil
            }
        }
        
        do {
            weak var expectationFindLocal = expectation(description: "Save Local")
            weak var expectationFindNetwork = expectation(description: "Save Network")
            
            let store = DataStore<Book>.collection(.cache)
            store.find { books, error in
                XCTAssertNotNil(books)
                XCTAssertNil(error)
                
                if let books = books {
                    if expectationFindLocal != nil {
                        expectationFindLocal?.fulfill()
                        expectationFindLocal = nil
                    } else {
                        expectationFindNetwork?.fulfill()
                    }
                    
                    XCTAssertEqual(books.count, 1)
                    if let book = books.first {
                        XCTAssertEqual(book.title, "Swift for the win!")
                        
                        XCTAssertEqual(book.authorNames.count, 1)
                        XCTAssertEqual(book.authorNames.first?.value, "Victor Barros")
                    }
                }
            }
            
            waitForExpectations(timeout: defaultTimeout) { error in
                expectationFindLocal = nil
                expectationFindNetwork = nil
            }
        }
        
        do {
            let basePath = Kinvey.cacheBasePath
            var url = URL(fileURLWithPath: basePath)
            url = url.appendingPathComponent(sharedClient.appKey!)
            url = url.appendingPathComponent("kinvey.realm")
            let realm = try! Realm(fileURL: url)
            XCTAssertEqual(realm.objects(Acl.self).count, 1)
            XCTAssertEqual(realm.objects(StringValue.self).count, 1)
            XCTAssertEqual(realm.objects(BookEdition.self).count, 2)
        }
    }
    
}
