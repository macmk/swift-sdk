//
//  Client.swift
//  Kinvey
//
//  Created by Victor Barros on 2015-12-08.
//  Copyright © 2015 Kinvey. All rights reserved.
//

import Foundation
import ObjectMapper
import PubNub

private let lockEncryptionKey = NSLock()

/// This class provides a representation of a Kinvey environment holding App ID and App Secret. Please *never* use a Master Secret in a client application.
@objc(__KNVClient)
open class Client: NSObject, NSCoding, Credential, PNObjectEventListener {

    /// Shared client instance for simplicity. Use this instance if *you don't need* to handle with multiple Kinvey environments.
    open static let sharedClient = Client()
    
    typealias UserChangedListener = (User?) -> Void
    var userChangedListener: UserChangedListener?
    
    /// It holds the `User` instance after logged in. If this variable is `nil` means that there's no logged user, which is necessary for some calls to in a Kinvey environment.
    open internal(set) var activeUser: User? {
        willSet (newActiveUser) {
            let userDefaults = Foundation.UserDefaults.standard
            if let activeUser = newActiveUser {
                var json = activeUser.toJSON()
                if var kmd = json[PersistableMetadataKey] as? [String : Any] {
                    kmd.removeValue(forKey: Metadata.AuthTokenKey)
                    json[PersistableMetadataKey] = kmd
                }
                userDefaults.set(json, forKey: appKey!)
                userDefaults.synchronize()
                
                KCSKeychain2.setKinveyToken(
                    activeUser.metadata?.authtoken,
                    user: activeUser.userId,
                    appKey: appKey,
                    accessible: KCSKeychain2.accessibleString(for: KCSDataProtectionLevel.completeUntilFirstLogin) //TODO: using default value for now
                )
                if let authtoken = activeUser.metadata?.authtoken {
                    keychain.authtoken = authtoken
                }
            } else if let appKey = appKey {
                userDefaults.removeObject(forKey: appKey)
                userDefaults.synchronize()
                
                KCSKeychain2.deleteTokens(
                    forUser: activeUser?.userId,
                    appKey: appKey
                )
                
                CacheManager(persistenceId: appKey, encryptionKey: encryptionKey as Data?).clearAll()
                do {
                    try Keychain(appKey: appKey).removeAll()
                } catch {
                    //do nothing
                }
                dataStoreInstances.removeAll()
            }
        }
        didSet {
            userChangedListener?(activeUser)
        }
    }
    
    fileprivate var keychain: Keychain {
        get {
            return Keychain(appKey: appKey!)
        }
    }
    
    internal var urlSession = URLSession(configuration: URLSessionConfiguration.default) {
        willSet {
            urlSession.invalidateAndCancel()
        }
    }
    
    /// Holds the App ID for a specific Kinvey environment.
    open fileprivate(set) var appKey: String?
    
    /// Holds the App Secret for a specific Kinvey environment.
    open fileprivate(set) var appSecret: String?
    
    /// Holds the `Host` for a specific Kinvey environment. The default value is `https://baas.kinvey.com/`
    open fileprivate(set) var apiHostName: URL
    
    /// Holds the `Authentication Host` for a specific Kinvey environment. The default value is `https://auth.kinvey.com/`
    open fileprivate(set) var authHostName: URL
    
    /// Cache policy for this client instance.
    open var cachePolicy: NSURLRequest.CachePolicy = .useProtocolCachePolicy
    
    /// Timeout interval for this client instance.
    open var timeoutInterval: TimeInterval = 60
    
    /// App version for this client instance.
    open var clientAppVersion: String?
    
    /// Custom request properties for this client instance.
    open var customRequestProperties: [String : String] = [:]
    
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
    open var logNetworkEnabled = false {
        didSet {
            KCSClient.configureLogging(
                withNetworkEnabled: logNetworkEnabled,
                debugEnabled: false,
                traceEnabled: false,
                warningEnabled: false,
                errorEnabled: false
            )
        }
    }
    
    /// Stores the MIC API Version to be used in MIC calls 
    open var micApiVersion: String? = "v1"
    
    /// Default constructor. The `initialize` method still need to be called after instanciate a new instance.
    public override init() {
        apiHostName = Client.defaultApiHostName
        authHostName = Client.defaultAuthHostName
        
        super.init()
        
        push = Push(client: self)
        networkRequestFactory = HttpRequestFactory(client: self)
        responseParser = JsonResponseParser(client: self)
    }
    
    /// Constructor that already initialize the client. The `initialize` method is called automatically.
    public convenience init(appKey: String, appSecret: String, apiHostName: URL = Client.defaultApiHostName, authHostName: URL = Client.defaultAuthHostName) {
        self.init()
        initialize(appKey: appKey, appSecret: appSecret, apiHostName: apiHostName, authHostName: authHostName)
    }
    
    /// Initialize a `Client` instance with all the needed parameters and requires a boolean to encrypt or not any store created using this client instance.
    open func initialize(appKey: String, appSecret: String, apiHostName: URL = Client.defaultApiHostName, authHostName: URL = Client.defaultAuthHostName, encrypted: Bool, schemaVersion: CUnsignedLongLong = 0, migrationHandler: Migration.MigrationHandler? = nil) {
        precondition((!appKey.isEmpty && !appSecret.isEmpty), "Please provide a valid appKey and appSecret. Your app's key and secret can be found on the Kinvey management console.")

        var encryptionKey: Data? = nil
        if encrypted {
            lockEncryptionKey.lock()
            
            let keychain = Keychain(appKey: appKey)
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
        
        initialize(appKey: appKey, appSecret: appSecret, apiHostName: apiHostName, authHostName: authHostName, encryptionKey: encryptionKey, schemaVersion: schemaVersion, migrationHandler: migrationHandler)
    }
    
    /// Initialize a `Client` instance with all the needed parameters.
    open func initialize(appKey: String, appSecret: String, apiHostName: URL = Client.defaultApiHostName, authHostName: URL = Client.defaultAuthHostName, encryptionKey: Data? = nil, schemaVersion: CUnsignedLongLong = 0, migrationHandler: Migration.MigrationHandler? = nil) {
        precondition((!appKey.isEmpty && !appSecret.isEmpty), "Please provide a valid appKey and appSecret. Your app's key and secret can be found on the Kinvey management console.")
        self.encryptionKey = encryptionKey
        self.schemaVersion = schemaVersion
        
        Migration.performMigration(persistenceId: appKey, encryptionKey: encryptionKey, schemaVersion: schemaVersion, migrationHandler: migrationHandler)
        
        cacheManager = CacheManager(persistenceId: appKey, encryptionKey: encryptionKey as Data?, schemaVersion: schemaVersion)
        syncManager = SyncManager(persistenceId: appKey, encryptionKey: encryptionKey as Data?, schemaVersion: schemaVersion)
        
        var apiHostName = apiHostName
        if let apiHostNameString = apiHostName.absoluteString as String? , apiHostNameString.characters.last == "/" {
            apiHostName = URL(string: apiHostNameString.substring(to: apiHostNameString.characters.index(before: apiHostNameString.characters.endIndex)))!
        }
        var authHostName = authHostName
        if let authHostNameString = authHostName.absoluteString as String? , authHostNameString.characters.last == "/" {
            authHostName = URL(string: authHostNameString.substring(to: authHostNameString.characters.index(before: authHostNameString.characters.endIndex)))!
        }
        self.apiHostName = apiHostName
        self.authHostName = authHostName
        self.appKey = appKey
        self.appSecret = appSecret
        
        //legacy initilization
        KCSClient.shared().initializeKinveyService(forAppKey: appKey, withAppSecret: appSecret, usingOptions: nil)
        
        if let json = Foundation.UserDefaults.standard.object(forKey: appKey) as? [String : AnyObject] {
            let user = Mapper<User>().map(JSON: json)
            if let user = user, let metadata = user.metadata, let authtoken = keychain.authtoken {
                user.client = self
                metadata.authtoken = authtoken
                activeUser = user
            }
        }
        
        // Initialize and configure PubNub client instance
        let configuration = PNConfiguration(publishKey: "pub-c-a43d9483-0340-45ea-83c5-6eb9badc0127", subscribeKey: "sub-c-13aebfae-ac4f-11e6-8319-02ee2ddab7fe")
        self.client = PubNub.clientWithConfiguration(configuration)
        self.client.addListener(self)
        
        // Subscribe to demo channel with presence observation
        self.client.subscribeToChannels(["my_channel"], withPresence: true)

    }
    
    /// Autorization header used for calls that don't requires a logged `User`.
    open var authorizationHeader: String? {
        get {
            var authorization: String? = nil
            if let appKey = appKey, let appSecret = appSecret {
                let appKeySecret = "\(appKey):\(appSecret)".data(using: String.Encoding.utf8)?.base64EncodedString(options: [])
                if let appKeySecret = appKeySecret {
                    authorization = "Basic \(appKeySecret)"
                }
            }
            return authorization
        }
    }

    internal func isInitialized () -> Bool {
        return self.appKey != nil && self.appSecret != nil
    }
    
    internal class func fileURL(appKey: String, tag: String = defaultTag) -> URL {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let path = paths.first! as NSString
        var filePath = URL(fileURLWithPath: path.appendingPathComponent(appKey))
        filePath.appendPathComponent("\(tag).realm")
        return filePath
    }
    
    internal func fileURL(_ tag: String = defaultTag) -> URL {
        return Client.fileURL(appKey: self.appKey!, tag: tag)
    }
    
    public convenience required init?(coder aDecoder: NSCoder) {
        guard
            let appKey = aDecoder.decodeObject(of: NSString.self, forKey: "appKey") as? String,
            let appSecret = aDecoder.decodeObject(of: NSString.self, forKey: "appSecret") as? String,
            let apiHostName = aDecoder.decodeObject(of: NSURL.self, forKey: "apiHostName") as? URL,
            let authHostName = aDecoder.decodeObject(of: NSURL.self, forKey: "authHostName") as? URL
        else {
                return nil
        }
        self.init(appKey: appKey, appSecret: appSecret, apiHostName: apiHostName, authHostName: authHostName)
    }
    
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(appKey, forKey: "appKey")
        aCoder.encode(appSecret, forKey: "appSecret")
        aCoder.encode(apiHostName, forKey: "apiHostName")
        aCoder.encode(authHostName, forKey: "authHostName")
    }
    
    
    
    // Stores reference on PubNub client to make sure what it won't be released.
    var client: PubNub!
    
    // Handle new message from one of channels on which client has been subscribed.
    public func client(_ client: PubNub, didReceiveMessage message: PNMessageResult) {
        
        // Handle new message stored in message.data.message
        if message.data.channel != message.data.subscription {
            
            // Message has been received on channel group stored in message.data.subscription.
        }
        else {
            
            // Message has been received on channel stored in message.data.channel.
        }
        
        print("Received message: \(message.data.message) on channel \(message.data.channel) " +
            "at \(message.data.timetoken)")
    }
    
    // New presence event handling.
    public func client(_ client: PubNub, didReceivePresenceEvent event: PNPresenceEventResult) {
        
        // Handle presence event event.data.presenceEvent (one of: join, leave, timeout, state-change).
        if event.data.channel != event.data.subscription {
            
            // Presence event has been received on channel group stored in event.data.subscription.
        }
        else {
            
            // Presence event has been received on channel stored in event.data.channel.
        }
        
        if event.data.presenceEvent != "state-change" {
            
            print("\(event.data.presence.uuid) \"\(event.data.presenceEvent)'ed\"\n" +
                "at: \(event.data.presence.timetoken) on \(event.data.channel) " +
                "(Occupancy: \(event.data.presence.occupancy))");
        }
        else {
            
            print("\(event.data.presence.uuid) changed state at: " +
                "\(event.data.presence.timetoken) on \(event.data.channel) to:\n" +
                "\(event.data.presence.state)");
        }
    }
    
    // Handle subscription status change.
    public func client(_ client: PubNub, didReceive status: PNStatus) {
        
        if status.operation == .subscribeOperation {
            
            // Check whether received information about successful subscription or restore.
            if status.category == .PNConnectedCategory || status.category == .PNReconnectedCategory {
                
                let subscribeStatus: PNSubscribeStatus = status as! PNSubscribeStatus
                if subscribeStatus.category == .PNConnectedCategory {
                    
                    // This is expected for a subscribe, this means there is no error or issue whatsoever.
                    
                    // Select last object from list of channels and send message to it.
                    let targetChannel = client.channels().last!
                    client.publish("Hello from the PubNub Swift SDK", toChannel: targetChannel,
                                   compressed: false, withCompletion: { (publishStatus) -> Void in
                                    
                                    if !publishStatus.isError {
                                        
                                        // Message successfully published to specified channel.
                                    }
                                    else {
                                        
                                        /**
                                         Handle message publish error. Check 'category' property to find out
                                         possible reason because of which request did fail.
                                         Review 'errorData' property (which has PNErrorData data type) of status
                                         object to get additional information about issue.
                                         
                                         Request can be resent using: publishStatus.retry()
                                         */
                                    }
                    })
                }
                else {
                    
                    /**
                     This usually occurs if subscribe temporarily fails but reconnects. This means there was
                     an error but there is no longer any issue.
                     */
                }
            }
            else if status.category == .PNUnexpectedDisconnectCategory {
                
                /**
                 This is usually an issue with the internet connection, this is an error, handle
                 appropriately retry will be called automatically.
                 */
            }
                // Looks like some kind of issues happened while client tried to subscribe or disconnected from
                // network.
            else {
                
                let errorStatus: PNErrorStatus = status as! PNErrorStatus
                if errorStatus.category == .PNAccessDeniedCategory {
                    
                    /**
                     This means that PAM does allow this client to subscribe to this channel and channel group
                     configuration. This is another explicit error.
                     */
                }
                else {
                    
                    /**
                     More errors can be directly specified by creating explicit cases for other error categories
                     of `PNStatusCategory` such as: `PNDecryptionErrorCategory`,
                     `PNMalformedFilterExpressionCategory`, `PNMalformedResponseCategory`, `PNTimeoutCategory`
                     or `PNNetworkIssuesCategory`
                     */
                }
            }
        }
    }

}
