//
//  FindOperation.swift
//  Kinvey
//
//  Created by Victor Barros on 2016-02-15.
//  Copyright © 2016 Kinvey. All rights reserved.
//

import Foundation
import PromiseKit

private let MaxIdsPerQuery = 200
private let MaxSizePerResultSet = 10_000

internal class FindOperation<T: Persistable>: ReadOperation<T, AnyRandomAccessCollection<T>, Swift.Error>, ReadOperationType where T: NSObject {
    
    let query: Query
    let deltaSet: Bool
    let deltaSetCompletionHandler: ((AnyRandomAccessCollection<T>) -> Void)?
    let autoPagination: Bool
    
    lazy var isEmptyQuery: Bool = {
        return (self.query.predicate == nil || self.query.predicate == NSPredicate()) && self.query.skip == nil && self.query.limit == nil
    }()
    
    var mustRemoveCachedRecords: Bool {
        return isEmptyQuery
    }
    
    typealias ResultsHandler = ([JsonDictionary]) -> Void
    let resultsHandler: ResultsHandler?
    
    init(
        query: Query,
        deltaSet: Bool,
        deltaSetCompletionHandler: ((AnyRandomAccessCollection<T>) -> Void)? = nil,
        autoPagination: Bool,
        readPolicy: ReadPolicy,
        cache: AnyCache<T>?,
        options: Options?,
        resultsHandler: ResultsHandler? = nil
    ) {
        self.query = query
        self.deltaSet = deltaSet
        self.deltaSetCompletionHandler = deltaSetCompletionHandler
        self.autoPagination = autoPagination
        if autoPagination, query.limit == nil {
            query.limit = MaxSizePerResultSet
        }
        self.resultsHandler = resultsHandler
        super.init(
            readPolicy: readPolicy,
            cache: cache,
            options: options
        )
    }
    
    @discardableResult
    func executeLocal(_ completionHandler: CompletionHandler? = nil) -> Request {
        let request = LocalRequest()
        request.execute { () -> Void in
            if let cache = self.cache {
                let json = cache.find(byQuery: self.query)
                completionHandler?(.success(json))
            } else {
                completionHandler?(.success(AnyRandomAccessCollection<T>([])))
            }
        }
        return request
    }
    
    typealias ArrayCompletionHandler = ([Any]?, Error?) -> Void
    
    private func count(multiRequest: MultiRequest) -> Promise<Int?> {
        return Promise<Int?> { fulfill, reject in
            if autoPagination {
                let query = Query(self.query)
                query.skip = nil
                query.limit = nil
                let countOperation = CountOperation<T>(query: query, readPolicy: .forceNetwork, cache: nil, options: nil)
                let request = countOperation.execute { result in
                    switch result {
                    case .success(let count):
                        fulfill(count)
                    case .failure(let error):
                        reject(error)
                    }
                }
                multiRequest += request
            } else {
                fulfill(nil)
            }
        }
    }
    
    private func fetchAutoPagination(multiRequest: MultiRequest, count: Int) -> Promise<AnyRandomAccessCollection<T>> {
        return Promise<AnyRandomAccessCollection<T>> { fulfill, reject in
            var promises = [Promise<AnyRandomAccessCollection<T>>]()
            for offset in stride(from: 0, to: count, by: MaxSizePerResultSet) {
                let promise = Promise<AnyRandomAccessCollection<T>> { fulfill, reject in
                    let query = Query(self.query)
                    query.skip = offset
                    let operation = FindOperation(
                        query: query,
                        deltaSet: self.deltaSet,
                        autoPagination: false,
                        readPolicy: .forceNetwork,
                        cache: self.cache,
                        options: self.options
                    )
                    let request = operation.execute { result in
                        switch result {
                        case .success(let results):
                            fulfill(results)
                        case .failure(let error):
                            reject(error)
                        }
                    }
                    multiRequest += request
                }
                promises.append(promise)
            }
            when(fulfilled: promises).then { results -> Void in
                let results = AnyRandomAccessCollection(results.lazy.flatMap { $0 })
                fulfill(results)
            }.catch { error in
                reject(error)
            }
        }
    }
    
    private func fetch(multiRequest: MultiRequest) -> Promise<AnyRandomAccessCollection<T>> {
        return Promise<AnyRandomAccessCollection<T>> { fulfill, reject in
            let deltaSet = self.deltaSet && (cache != nil ? !cache!.isEmpty() : false)
            let fields: Set<String>? = deltaSet ? [Entity.Key.entityId, "\(Entity.Key.metadata).\(Metadata.Key.lastModifiedTime)"] : nil
            let request = client.networkRequestFactory.buildAppDataFindByQuery(
                collectionName: T.collectionName(),
                query: fields != nil ? Query(query) { $0.fields = fields } : query,
                options: options
            )
            multiRequest += request
            request.execute() { data, response, error in
                if let response = response, response.isOK,
                    let jsonArray = self.client.responseParser.parseArray(data)
                {
                    self.resultsHandler?(jsonArray)
                    if let cache = self.cache, deltaSet {
                        let refObjs = self.reduceToIdsLmts(jsonArray)
                        guard jsonArray.count == refObjs.count else {
                            let operation = FindOperation(
                                query: self.query,
                                deltaSet: false,
                                autoPagination: self.autoPagination,
                                readPolicy: self.readPolicy,
                                cache: cache,
                                options: self.options
                            )
                            let request = operation.executeNetwork {
                                switch $0 {
                                case .success(let results):
                                    fulfill(results)
                                case .failure(let error):
                                    reject(error)
                                }
                            }
                            multiRequest += request
                            return
                        }
                        let deltaSet = self.computeDeltaSet(self.query, refObjs: refObjs)
                        var allIds = Set<String>(minimumCapacity: deltaSet.created.count + deltaSet.updated.count + deltaSet.deleted.count)
                        allIds.formUnion(deltaSet.created)
                        allIds.formUnion(deltaSet.updated)
                        allIds.formUnion(deltaSet.deleted)
                        if allIds.count > MaxIdsPerQuery {
                            let allIds = Array<String>(allIds)
                            var promises = [Promise<AnyRandomAccessCollection<T>>]()
                            var newRefObjs = [String : String]()
                            for offset in stride(from: 0, to: allIds.count, by: MaxIdsPerQuery) {
                                let limit = min(offset + MaxIdsPerQuery, allIds.count - 1)
                                let allIds = Set<String>(allIds[offset...limit])
                                let promise = Promise<AnyRandomAccessCollection<T>> { fulfill, reject in
                                    let query = Query(format: "\(Entity.Key.entityId) IN %@", allIds)
                                    let operation = FindOperation<T>(
                                        query: query,
                                        deltaSet: false,
                                        autoPagination: self.autoPagination,
                                        readPolicy: .forceNetwork,
                                        cache: cache,
                                        options: self.options
                                    ) { jsonArray in
                                        for (key, value) in self.reduceToIdsLmts(jsonArray) {
                                            newRefObjs[key] = value
                                        }
                                    }
                                    operation.execute { (result) -> Void in
                                        switch result {
                                        case .success(let results):
                                            fulfill(results)
                                        case .failure(let error):
                                            reject(error)
                                        }
                                    }
                                }
                                promises.append(promise)
                            }
                            when(fulfilled: promises).then { results -> Void in
                                if self.mustRemoveCachedRecords {
                                    self.removeCachedRecords(
                                        cache,
                                        keys: refObjs.keys,
                                        deleted: deltaSet.deleted
                                    )
                                }
                                if let deltaSetCompletionHandler = self.deltaSetCompletionHandler {
                                    deltaSetCompletionHandler(AnyRandomAccessCollection(results.flatMap { $0 }))
                                }
                                self.executeLocal {
                                    switch $0 {
                                    case .success(let results):
                                        fulfill(results)
                                    case .failure(let error):
                                        reject(error)
                                    }
                                }
                                }.catch { error in
                                    reject(error)
                            }
                        } else if allIds.count > 0 {
                            let query = Query(format: "\(Entity.Key.entityId) IN %@", allIds)
                            var newRefObjs: [String : String]? = nil
                            let operation = FindOperation<T>(
                                query: query,
                                deltaSet: false,
                                autoPagination : self.autoPagination,
                                readPolicy: .forceNetwork,
                                cache: cache,
                                options: self.options
                            ) { jsonArray in
                                newRefObjs = self.reduceToIdsLmts(jsonArray)
                            }
                            operation.execute { (result) -> Void in
                                switch result {
                                case .success:
                                    if self.mustRemoveCachedRecords,
                                        let refObjs = newRefObjs
                                    {
                                        self.removeCachedRecords(
                                            cache,
                                            keys: refObjs.keys,
                                            deleted: deltaSet.deleted
                                        )
                                    }
                                    self.executeLocal {
                                        switch $0 {
                                        case .success(let results):
                                            fulfill(results)
                                        case .failure(let error):
                                            reject(error)
                                        }
                                    }
                                case .failure(let error):
                                    reject(error)
                                }
                            }
                        } else {
                            self.executeLocal {
                                switch $0 {
                                case .success(let results):
                                    fulfill(results)
                                case .failure(let error):
                                    reject(error)
                                }
                            }
                        }
                    } else {
                        func convert(_ jsonArray: [JsonDictionary]) -> AnyRandomAccessCollection<T> {
                            let startTime = CFAbsoluteTimeGetCurrent()
                            let entities = AnyRandomAccessCollection(jsonArray.lazy.map { (json) -> T in
                                guard let entity = T(JSON: json) else {
                                    fatalError("_id is required")
                                }
                                return entity
                            })
                            log.debug("Time elapsed: \(CFAbsoluteTimeGetCurrent() - startTime) s")
                            return entities
                        }
                        let entities = convert(jsonArray)
                        if let cache = self.cache {
                            if self.mustRemoveCachedRecords {
                                let refObjs = self.reduceToIdsLmts(jsonArray)
                                let deltaSet = self.computeDeltaSet(
                                    self.query,
                                    refObjs: refObjs
                                )
                                self.removeCachedRecords(
                                    cache,
                                    keys: refObjs.keys,
                                    deleted: deltaSet.deleted
                                )
                            }
                            if let cache = cache.dynamic {
                                cache.save(entities: AnyRandomAccessCollection(jsonArray))
                            } else {
                                cache.save(entities: entities)
                            }
                        }
                        fulfill(entities)
                    }
                } else {
                    reject(buildError(data, response, error, self.client))
                }
            }
        }
    }
    
    @discardableResult
    func executeNetwork(_ completionHandler: CompletionHandler? = nil) -> Request {
        let request = MultiRequest()
        count(multiRequest: request).then { (count) -> Promise<AnyRandomAccessCollection<T>> in
            if let count = count {
                return self.fetchAutoPagination(multiRequest: request, count: count)
            } else {
                return self.fetch(multiRequest: request)
            }
        }.then {
            completionHandler?(.success($0))
        }.catch { error in
            completionHandler?(.failure(error))
        }
        return request
    }
    
    fileprivate func removeCachedRecords<S : Sequence>(_ cache: AnyCache<T>, keys: S, deleted: Set<String>) where S.Iterator.Element == String {
        let refKeys = Set<String>(keys)
        let deleted = deleted.subtracting(refKeys)
        if deleted.count > 0 {
            let query = Query(format: "\(T.entityIdProperty()) IN %@", deleted as AnyObject)
            cache.remove(byQuery: query)
        }
    }
    
}
