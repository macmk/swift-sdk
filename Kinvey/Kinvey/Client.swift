//
//  Client.swift
//  Kinvey
//
//  Created by Victor Barros on 2015-12-08.
//  Copyright © 2015 Kinvey. All rights reserved.
//

import Foundation
import ObjectMapper
import PromiseKit

private let lockEncryptionKey = NSLock()

/// This class provides a representation of a Kinvey environment holding App ID and App Secret. Please *never* use a Master Secret in a client application.
open class Client: Credential {

    /// Shared client instance for simplicity. Use this instance if *you don't need* to handle with multiple Kinvey environments.
    open static let sharedClient = Client()
    
    typealias UserChangedListener = (User?) -> Void
    var userChangedListener: UserChangedListener?
    
    /// It holds the `User` instance after logged in. If this variable is `nil` means that there's no logged user, which is necessary for some calls to in a Kinvey environment.
    open internal(set) var activeUser: User? {
        willSet (newActiveUser) {
            if let activeUser = newActiveUser {
                keychain.user = activeUser
                if let sharedKeychain = sharedKeychain, let socialIdentity = activeUser.socialIdentity, let kinveyAuth = socialIdentity.kinvey {
                    sharedKeychain.kinveyAuth = kinveyAuth
                }
            } else if let appKey = appKey {
                CacheManager(persistenceId: appKey, encryptionKey: encryptionKey as Data?).clearAll()
                try! Keychain(appKey: appKey, client: self).removeAll()
                if let sharedKeychain = sharedKeychain {
                    try! sharedKeychain.removeAll()
                }
                dataStoreInstances.removeAll()
            } else {
                if let sharedKeychain = sharedKeychain {
                    try! sharedKeychain.removeAll()
                }
            }
        }
        didSet {
            userChangedListener?(activeUser)
        }
    }
    
    internal var clientId: String? {
        willSet {
            keychain.clientId = clientId
        }
    }
    
    private var accessGroup: String?
    
    private var keychain: Keychain {
        return Keychain(appKey: appKey!, client: self)
    }
    
    private var sharedKeychain: Keychain? {
        if let accessGroup = accessGroup {
            return Keychain(accessGroup: accessGroup, client: self)
        }
        return nil
    }
    
    internal static let urlSessionConfiguration = URLSessionConfiguration.default
    
    internal var urlSession = URLSession(configuration: urlSessionConfiguration) {
        willSet {
            urlSession.invalidateAndCancel()
        }
    }
    
    /// Holds the App ID for a specific Kinvey environment.
    open fileprivate(set) var appKey: String?
    
    /// Holds the App Secret for a specific Kinvey environment.
    open fileprivate(set) var appSecret: String?
    
    /// Holds the `Host` for a specific Kinvey environment. The default value is `https://baas.kinvey.com/`
    open private(set) var apiHostName: URL
    
    /// Holds the `Authentication Host` for a specific Kinvey environment. The default value is `https://auth.kinvey.com/`
    open private(set) var authHostName: URL
    
    /// Cache policy for this client instance.
    open var cachePolicy: NSURLRequest.CachePolicy = .useProtocolCachePolicy
    
    /// Timeout interval for this client instance.
    open var timeoutInterval: TimeInterval = 60
    
    /**
     Hold default optional values for all calls made by this `Client` instance
     */
    open var options: Options?
    
    /// The default value for `apiHostName` variable.
    open static let defaultApiHostName = URL(string: "https://baas.kinvey.com/")!
    
    /// The default value for `authHostName` variable.
    open static let defaultAuthHostName = URL(string: "https://auth.kinvey.com/")!
    
    var networkRequestFactory: RequestFactory!
    var responseParser: ResponseParser!
    
    var encryptionKey: Data?
    
    /// Set a different schema version to perform migrations in your local cache.
    open fileprivate(set) var schemaVersion: CUnsignedLongLong = 0
    
    internal fileprivate(set) var cacheManager: CacheManager!
    internal fileprivate(set) var syncManager: SyncManager!
    
    /// Use this variable to handle push notifications.
    open fileprivate(set) var push: Push!
    
    /// Set a different type if you need a custom `User` class. Extends from `User` allows you to have custom properties in your `User` instances.
    open var userType = User.self
    
    ///Default Value for DataStore tag
    open static let defaultTag = Kinvey.defaultTag
    
    var dataStoreInstances = [DataStoreTypeTag : AnyObject]()
    
    /// Enables logging for any network calls.
    open var logNetworkEnabled = false
    
    /// Stores the MIC API Version to be used in MIC calls 
    open var micApiVersion: MICApiVersion? = .v1
    
    /// Default constructor. The `initialize` method still need to be called after instanciate a new instance.
    public init() {
        apiHostName = Client.defaultApiHostName
        authHostName = Client.defaultAuthHostName
        
        push = Push(client: self)
        networkRequestFactory = HttpRequestFactory(client: self)
        responseParser = JsonResponseParser(client: self)
    }
    
    /// Constructor that already initialize the client. The `initialize` method is called automatically.
    public convenience init(appKey: String, appSecret: String, accessGroup: String? = nil, apiHostName: URL = Client.defaultApiHostName, authHostName: URL = Client.defaultAuthHostName) {
        self.init()
        initialize(appKey: appKey, appSecret: appSecret, accessGroup: accessGroup, apiHostName: apiHostName, authHostName: authHostName) { activerUser, error in
        }
    }
    
    private func validateInitialize(appKey: String, appSecret: String) {
        if appKey.isEmpty || appSecret.isEmpty {
            fatalError("Please provide a valid appKey and appSecret. Your app's key and secret can be found on the Kinvey management console.")
        }
    }
    
    /// Initialize a `Client` instance with all the needed parameters and requires a boolean to encrypt or not any store created using this client instance.
    @available(*, deprecated: 3.3.3, message: "Please use initialize(appKey:appSecret:accessGroup:apiHostName:authHostName:encrypted:schema:completionHandler:)")
    open func initialize(appKey: String, appSecret: String, accessGroup: String? = nil, apiHostName: URL = Client.defaultApiHostName, authHostName: URL = Client.defaultAuthHostName, encrypted: Bool, schemaVersion: CUnsignedLongLong = 0, migrationHandler: Migration.MigrationHandler? = nil) {
        initialize(appKey: appKey, appSecret: appSecret, accessGroup: accessGroup, apiHostName: apiHostName, authHostName: authHostName, encrypted: encrypted, schema: Schema(schemaVersion, migrationHandler: migrationHandler)) { activeUser, error in
        }
    }
    
    /// Initialize a `Client` instance with all the needed parameters and requires a boolean to encrypt or not any store created using this client instance.
    open func initialize<U: User>(appKey: String, appSecret: String, accessGroup: String? = nil, apiHostName: URL = Client.defaultApiHostName, authHostName: URL = Client.defaultAuthHostName, encrypted: Bool, schema: Schema? = nil, completionHandler: User.UserHandler<U>) {
        initialize(
            appKey: appKey,
            appSecret: appSecret,
            accessGroup: accessGroup,
            apiHostName: apiHostName,
            authHostName: authHostName,
            encrypted: encrypted,
            schema: schema
        ) { (result: Result<U, Swift.Error>) in
            switch result {
            case .success(let user):
                completionHandler(user, nil)
            case .failure(let error):
                completionHandler(nil, error)
            }
        }
    }
    
    /// Initialize a `Client` instance with all the needed parameters and requires a boolean to encrypt or not any store created using this client instance.
    open func initialize<U: User>(appKey: String, appSecret: String, accessGroup: String? = nil, apiHostName: URL = Client.defaultApiHostName, authHostName: URL = Client.defaultAuthHostName, encrypted: Bool, schema: Schema? = nil, completionHandler: (Result<U, Swift.Error>) -> Void) {
        validateInitialize(appKey: appKey, appSecret: appSecret)

        var encryptionKey: Data? = nil
        if encrypted {
            lockEncryptionKey.lock()
            
            let keychain = Keychain(appKey: appKey, client: self)
            if let key = keychain.defaultEncryptionKey {
                encryptionKey = key as Data
            } else {
                let numberOfBytes = 64
                var bytes = [UInt8](repeating: 0, count: numberOfBytes)
                let result = SecRandomCopyBytes(kSecRandomDefault, numberOfBytes, &bytes)
                if result == 0 {
                    let key = Data(bytes: bytes)
                    keychain.defaultEncryptionKey = key
                    encryptionKey = key
                }
            }
            
            lockEncryptionKey.unlock()
        }
        
        initialize(appKey: appKey, appSecret: appSecret, apiHostName: apiHostName, authHostName: authHostName, encryptionKey: encryptionKey, schema: Schema(version: schema?.version ?? 0, migrationHandler: schema?.migrationHandler)) { activeUser, error in
        }
    }
    
    /// Initialize a `Client` instance with all the needed parameters.
    @available(*, deprecated: 3.3.3, message: "Please use initialize(appKey:appSecret:accessGroup:apiHostName:authHostName:encryptionKey:schema:completionHandler:)")
    open func initialize(appKey: String, appSecret: String, accessGroup: String? = nil, apiHostName: URL = Client.defaultApiHostName, authHostName: URL = Client.defaultAuthHostName, encryptionKey: Data? = nil, schemaVersion: CUnsignedLongLong = 0, migrationHandler: Migration.MigrationHandler? = nil) {
        initialize(appKey: appKey, appSecret: appSecret, accessGroup: accessGroup, apiHostName: apiHostName, authHostName: authHostName, encryptionKey: encryptionKey, schema: Schema(version: schemaVersion, migrationHandler: migrationHandler)) { activeUser, error in
        }
    }
    
    /// Initialize a `Client` instance with all the needed parameters.
    open func initialize<U: User>(appKey: String, appSecret: String, accessGroup: String? = nil, apiHostName: URL = Client.defaultApiHostName, authHostName: URL = Client.defaultAuthHostName, encryptionKey: Data? = nil, schema: Schema? = nil, completionHandler: @escaping User.UserHandler<U>) {
        initialize(
            appKey: appKey,
            appSecret: appSecret,
            accessGroup: accessGroup,
            apiHostName: apiHostName,
            authHostName: authHostName,
            encryptionKey: encryptionKey,
            schema: schema
        ) { (result: Result<U?, Swift.Error>) in
            switch result {
            case .success(let user):
                completionHandler(user, nil)
            case .failure(let error):
                completionHandler(nil, error)
            }
        }
    }
    
    /// Initialize a `Client` instance with all the needed parameters.
    open func initialize<U: User>(appKey: String, appSecret: String, accessGroup: String? = nil, apiHostName: URL = Client.defaultApiHostName, authHostName: URL = Client.defaultAuthHostName, encryptionKey: Data? = nil, schema: Schema? = nil, completionHandler: @escaping (Result<U?, Swift.Error>) -> Void) {
        validateInitialize(appKey: appKey, appSecret: appSecret)
        self.encryptionKey = encryptionKey
        self.schemaVersion = schema?.version ?? 0
        
        Migration.performMigration(persistenceId: appKey, encryptionKey: encryptionKey, schemaVersion: schemaVersion, migrationHandler: schema?.migrationHandler)
        
        cacheManager = CacheManager(persistenceId: appKey, encryptionKey: encryptionKey as Data?, schemaVersion: schemaVersion)
        syncManager = SyncManager(persistenceId: appKey, encryptionKey: encryptionKey as Data?, schemaVersion: schemaVersion)
        
        var apiHostName = apiHostName
        if let apiHostNameString = apiHostName.absoluteString as String?, apiHostNameString.characters.last == "/" {
            apiHostName = URL(string: apiHostNameString.substring(to: apiHostNameString.characters.index(before: apiHostNameString.characters.endIndex)))!
        }
        var authHostName = authHostName
        if let authHostNameString = authHostName.absoluteString as String?, authHostNameString.characters.last == "/" {
            authHostName = URL(string: authHostNameString.substring(to: authHostNameString.characters.index(before: authHostNameString.characters.endIndex)))!
        }
        self.apiHostName = apiHostName
        self.authHostName = authHostName
        self.appKey = appKey
        self.appSecret = appSecret
        self.accessGroup = accessGroup
        
        let userDefaults = UserDefaults.standard
        if let json = userDefaults.dictionary(forKey: appKey) {
            keychain.user = userType.init(JSON: json)
            userDefaults.removeObject(forKey: appKey)
            userDefaults.synchronize()
        }
        
        if let user = keychain.user {
            user.client = self
            activeUser = user
            clientId = keychain.clientId
            let customUser = user as! U
            completionHandler(.success(customUser))
        } else if let kinveyAuth = sharedKeychain?.kinveyAuth {
            User.login(authSource: .kinvey, kinveyAuth, client: self) { (result: Result<U, Swift.Error>) in
                switch result {
                case .success(let user):
                    completionHandler(.success(user))
                case .failure(let error):
                    completionHandler(.failure(error))
                }
            }
        } else {
            completionHandler(.success(nil))
        }
    }
    
    /// Autorization header used for calls that don't requires a logged `User`.
    open var authorizationHeader: String? {
        get {
            var authorization: String? = nil
            if let appKey = appKey, let appSecret = appSecret {
                let appKeySecret = "\(appKey):\(appSecret)".data(using: String.Encoding.utf8)?.base64EncodedString()
                if let appKeySecret = appKeySecret {
                    authorization = "Basic \(appKeySecret)"
                }
            }
            return authorization
        }
    }

    internal func isInitialized() -> Bool {
        return self.appKey != nil && self.appSecret != nil
    }
    
    internal func validate() -> Swift.Error? {
        guard isInitialized() else {
            return Error.clientNotInitialized
        }
        return nil
    }
    
    internal class func fileURL(appKey: String, tag: String = defaultTag) -> URL {
        let path = cacheBasePath as NSString
        var filePath = URL(fileURLWithPath: path.appendingPathComponent(appKey))
        filePath.appendPathComponent("\(tag).realm")
        return filePath
    }
    
    internal func fileURL(_ tag: String = defaultTag) -> URL {
        return Client.fileURL(appKey: self.appKey!, tag: tag)
    }
    
    /**
     Check if the `appKey` and `appSecret` properties are correct doing a ping
     call to the server.
     */
    @discardableResult
    public func ping(completionHandler: @escaping (EnvironmentInfo?, Swift.Error?) -> Void) -> Request {
        return ping() { (result: Result<EnvironmentInfo, Swift.Error>) in
            switch result {
            case .success(let envInfo):
                completionHandler(envInfo, nil)
            case .failure(let error):
                completionHandler(nil, error)
            }
        }
    }
    
    /**
     Checks connectivity to your backend. A successful response returns a
     summary of your backend environment and confirms that the app can talk to
     the backend.
     */
    @discardableResult
    public func ping(completionHandler: @escaping (Result<EnvironmentInfo, Swift.Error>) -> Void) -> Request {
        guard let _ = appKey, let _ = appSecret else {
            DispatchQueue.main.async {
                completionHandler(.failure(Error.invalidOperation(description: "Please initialize your client calling the initialize() method before call ping()")))
            }
            return LocalRequest()
        }
        let request = networkRequestFactory.buildAppDataPing(options: options)
        Promise<EnvironmentInfo> { fulfill, reject in
            request.execute() { data, response, error in
                if let response = response,
                    response.isOK,
                    let data = data,
                    let json = try? JSONSerialization.jsonObject(with: data),
                    let result = json as? [String : String],
                    let environmentInfo = EnvironmentInfo(JSON: result)
                {
                    fulfill(environmentInfo)
                } else {
                    reject(buildError(data, response, error, self))
                }
            }
        }.then {
            completionHandler(.success($0))
        }.catch {
            completionHandler(.failure($0))
        }
        return request
    }
}

/// Environment Information for a specific `appKey` and `appSecret`
public struct EnvironmentInfo: StaticMappable {
    
    /// Version of the backend
    public let version: String
    
    /// Hello message from Kinvey
    public let kinvey: String
    
    /// Application Name
    public let appName: String
    
    /// Environment Name
    public let environmentName: String
    
    public static func objectForMapping(map: Map) -> BaseMappable? {
        guard let version: String = map["version"].value(),
            let kinvey: String = map["kinvey"].value(),
            let appName: String = map["appName"].value(),
            let environmentName: String = map["environmentName"].value()
            else {
                return nil
        }
        return EnvironmentInfo(
            version: version,
            kinvey: kinvey,
            appName: appName,
            environmentName: environmentName
        )
    }
    
    public mutating func mapping(map: Map) {
    }
    
}
