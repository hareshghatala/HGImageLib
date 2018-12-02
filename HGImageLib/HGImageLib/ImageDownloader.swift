//
//  ImageDownloader.swift
//  HGImageLib
//
//  Created by Haresh on 02/12/18.
//  Copyright © 2018 Haresh. All rights reserved.
//

import Foundation
import UIKit

open class RequestReceipt {
    /// The download request created by the `ImageDownloader`.
    public let request: Request

    /// The unique identifier for the image filters and completion handlers when duplicate requests are made.
    public let receiptID: String

    init(request: Request, receiptID: String) {
        self.request = request
        self.receiptID = receiptID
    }
}

// MARK: -

open class ImageDownloader {
    
    /// The completion handler closure used when an image download completes.
    public typealias CompletionHandler = (DataResponse<Image>) -> Void
    
    /// The progress handler closure called periodically during an image download.
    public typealias ProgressHandler = DataRequest.ProgressHandler
    
    // MARK: Helper Types
    
    public enum DownloadPrioritization {
        case fifo, lifo
    }
    
    class ResponseHandler {
        let urlID: String
        let handlerID: String
        let request: DataRequest
        var operations: [(receiptID: String, filter: ImageFilter?, completion: CompletionHandler?)]
        
        init(
            request: DataRequest,
            handlerID: String,
            receiptID: String,
            filter: ImageFilter?,
            completion: CompletionHandler?)
        {
            self.request = request
            self.urlID = ImageDownloader.urlIdentifier(for: request.request!)
            self.handlerID = handlerID
            self.operations = [(receiptID: receiptID, filter: filter, completion: completion)]
        }
    }
    
    // MARK: Properties
    
    /// The image cache used to store all downloaded images in.
    public let imageCache: ImageRequestCache?
    
    /// The credential used for authenticating each download request.
    open private(set) var credential: URLCredential?
    
    /// Response serializer used to convert the image data to UIImage.
    public var imageResponseSerializer = DataRequest.imageResponseSerializer()
    
    /// The underlying HGNetworkLib `Manager` instance used to handle all download requests.
    public let sessionManager: SessionManager
    
    let downloadPrioritization: DownloadPrioritization
    let maximumActiveDownloads: Int
    
    var activeRequestCount = 0
    var queuedRequests: [Request] = []
    var responseHandlers: [String: ResponseHandler] = [:]
    
    private let synchronizationQueue: DispatchQueue = {
        let name = String(format: "org.hgnetworklib.imagedownloader.synchronizationqueue-%08x%08x", arc4random(), arc4random())
        return DispatchQueue(label: name)
    }()
    
    private let responseQueue: DispatchQueue = {
        let name = String(format: "org.hgnetworklib.imagedownloader.responsequeue-%08x%08x", arc4random(), arc4random())
        return DispatchQueue(label: name, attributes: .concurrent)
    }()
    
    // MARK: Initialization
    
    /// The default instance of `ImageDownloader` initialized with default values.
    public static let `default` = ImageDownloader()
    
    open class func defaultURLSessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        
        configuration.httpAdditionalHeaders = SessionManager.defaultHTTPHeaders
        configuration.httpShouldSetCookies = true
        configuration.httpShouldUsePipelining = false
        
        configuration.requestCachePolicy = .useProtocolCachePolicy
        configuration.allowsCellularAccess = true
        configuration.timeoutIntervalForRequest = 60
        
        configuration.urlCache = ImageDownloader.defaultURLCache()
        
        return configuration
    }
    
    open class func defaultURLCache() -> URLCache {
        return URLCache(
            memoryCapacity: 20 * 1024 * 1024, // 20 MB
            diskCapacity: 150 * 1024 * 1024,  // 150 MB
            diskPath: "org.hgnetworklib.imagedownloader"
        )
    }
    
    public init(
        configuration: URLSessionConfiguration = ImageDownloader.defaultURLSessionConfiguration(),
        downloadPrioritization: DownloadPrioritization = .fifo,
        maximumActiveDownloads: Int = 4,
        imageCache: ImageRequestCache? = AutoPurgingImageCache())
    {
        self.sessionManager = SessionManager(configuration: configuration)
        self.sessionManager.startRequestsImmediately = false
        
        self.downloadPrioritization = downloadPrioritization
        self.maximumActiveDownloads = maximumActiveDownloads
        self.imageCache = imageCache
    }
    
    public init(
        sessionManager: SessionManager,
        downloadPrioritization: DownloadPrioritization = .fifo,
        maximumActiveDownloads: Int = 4,
        imageCache: ImageRequestCache? = AutoPurgingImageCache())
    {
        self.sessionManager = sessionManager
        self.sessionManager.startRequestsImmediately = false
        
        self.downloadPrioritization = downloadPrioritization
        self.maximumActiveDownloads = maximumActiveDownloads
        self.imageCache = imageCache
    }
    
    // MARK: Authentication
    
    open func addAuthentication(
        user: String,
        password: String,
        persistence: URLCredential.Persistence = .forSession)
    {
        let credential = URLCredential(user: user, password: password, persistence: persistence)
        addAuthentication(usingCredential: credential)
    }
    
    open func addAuthentication(usingCredential credential: URLCredential) {
        synchronizationQueue.sync {
            self.credential = credential
        }
    }
    
    // MARK: Download
    
    @discardableResult
    open func download(
        _ urlRequest: URLRequestConvertible,
        receiptID: String = UUID().uuidString,
        filter: ImageFilter? = nil,
        progress: ProgressHandler? = nil,
        progressQueue: DispatchQueue = DispatchQueue.main,
        completion: CompletionHandler?)
        -> RequestReceipt?
    {
        var request: DataRequest!
        
        synchronizationQueue.sync {
            // 1) Append the filter and completion handler to a pre-existing request if it already exists
            let urlID = ImageDownloader.urlIdentifier(for: urlRequest)
            
            if let responseHandler = self.responseHandlers[urlID] {
                responseHandler.operations.append((receiptID: receiptID, filter: filter, completion: completion))
                request = responseHandler.request
                return
            }
            
            // 2) Attempt to load the image from the image cache if the cache policy allows it
            if let request = urlRequest.urlRequest {
                switch request.cachePolicy {
                case .useProtocolCachePolicy, .returnCacheDataElseLoad, .returnCacheDataDontLoad:
                    if let image = self.imageCache?.image(for: request, withIdentifier: filter?.identifier) {
                        DispatchQueue.main.async {
                            let response = DataResponse<Image>(
                                request: urlRequest.urlRequest,
                                response: nil,
                                data: nil,
                                result: .success(image)
                            )
                            
                            completion?(response)
                        }
                        
                        return
                    }
                default:
                    break
                }
            }
            
            // 3) Create the request and set up authentication, validation and response serialization
            request = self.sessionManager.request(urlRequest)
            
            if let credential = self.credential {
                request.authenticate(usingCredential: credential)
            }
            
            request.validate()
            
            if let progress = progress {
                request.downloadProgress(queue: progressQueue, closure: progress)
            }
            
            // Generate a unique handler id to check whether the active request has changed while downloading
            let handlerID = UUID().uuidString
            
            request.response(
                queue: self.responseQueue,
                responseSerializer: imageResponseSerializer,
                completionHandler: { [weak self] response in
                    guard let strongSelf = self, let request = response.request else { return }
                    
                    defer {
                        strongSelf.safelyDecrementActiveRequestCount()
                        strongSelf.safelyStartNextRequestIfNecessary()
                    }
                    
                    // Early out if the request has changed out from under us
                    let handler = strongSelf.safelyFetchResponseHandler(withURLIdentifier: urlID)
                    guard handler?.handlerID == handlerID else { return }
                    
                    guard let responseHandler = strongSelf.safelyRemoveResponseHandler(withURLIdentifier: urlID) else {
                        return
                    }
                    
                    switch response.result {
                    case .success(let image):
                        var filteredImages: [String: Image] = [:]
                        
                        for (_, filter, completion) in responseHandler.operations {
                            var filteredImage: Image
                            
                            if let filter = filter {
                                if let alreadyFilteredImage = filteredImages[filter.identifier] {
                                    filteredImage = alreadyFilteredImage
                                } else {
                                    filteredImage = filter.filter(image)
                                    filteredImages[filter.identifier] = filteredImage
                                }
                            } else {
                                filteredImage = image
                            }
                            
                            strongSelf.imageCache?.add(filteredImage, for: request, withIdentifier: filter?.identifier)
                            
                            DispatchQueue.main.async {
                                let response = DataResponse<Image>(
                                    request: response.request,
                                    response: response.response,
                                    data: response.data,
                                    result: .success(filteredImage),
                                    timeline: response.timeline
                                )
                                
                                completion?(response)
                            }
                        }
                    case .failure:
                        for (_, _, completion) in responseHandler.operations {
                            DispatchQueue.main.async { completion?(response) }
                        }
                    }
                }
            )
            
            // 4) Store the response handler for use when the request completes
            let responseHandler = ResponseHandler(
                request: request,
                handlerID: handlerID,
                receiptID: receiptID,
                filter: filter,
                completion: completion
            )
            
            self.responseHandlers[urlID] = responseHandler
            
            // 5) Either start the request or enqueue it depending on the current active request count
            if self.isActiveRequestCountBelowMaximumLimit() {
                self.start(request)
            } else {
                self.enqueue(request)
            }
        }
        
        if let request = request {
            return RequestReceipt(request: request, receiptID: receiptID)
        }
        
        return nil
    }
    
    @discardableResult
    open func download(
        _ urlRequests: [URLRequestConvertible],
        filter: ImageFilter? = nil,
        progress: ProgressHandler? = nil,
        progressQueue: DispatchQueue = DispatchQueue.main,
        completion: CompletionHandler? = nil)
        -> [RequestReceipt]
    {
        #if swift(>=4.1)
        return urlRequests.compactMap {
            download($0, filter: filter, progress: progress, progressQueue: progressQueue, completion: completion)
        }
        #else
        return urlRequests.flatMap {
        download($0, filter: filter, progress: progress, progressQueue: progressQueue, completion: completion)
        }
        #endif
    }
    
    open func cancelRequest(with requestReceipt: RequestReceipt) {
        synchronizationQueue.sync {
            let urlID = ImageDownloader.urlIdentifier(for: requestReceipt.request.request!)
            guard let responseHandler = self.responseHandlers[urlID] else { return }
            
            if let index = responseHandler.operations.index(where: { $0.receiptID == requestReceipt.receiptID }) {
                let operation = responseHandler.operations.remove(at: index)
                
                let response: DataResponse<Image> = {
                    let urlRequest = requestReceipt.request.request
                    let error = HGIError.requestCancelled
                    
                    return DataResponse(request: urlRequest, response: nil, data: nil, result: .failure(error))
                }()
                
                DispatchQueue.main.async { operation.completion?(response) }
            }
            
            if responseHandler.operations.isEmpty && requestReceipt.request.task?.state == .suspended {
                requestReceipt.request.cancel()
                self.responseHandlers.removeValue(forKey: urlID)
            }
        }
    }
    
    // MARK: Internal - Thread-Safe Request Methods
    
    func safelyFetchResponseHandler(withURLIdentifier urlIdentifier: String) -> ResponseHandler? {
        var responseHandler: ResponseHandler?
        
        synchronizationQueue.sync {
            responseHandler = self.responseHandlers[urlIdentifier]
        }
        
        return responseHandler
    }
    
    func safelyRemoveResponseHandler(withURLIdentifier identifier: String) -> ResponseHandler? {
        var responseHandler: ResponseHandler?
        
        synchronizationQueue.sync {
            responseHandler = self.responseHandlers.removeValue(forKey: identifier)
        }
        
        return responseHandler
    }
    
    func safelyStartNextRequestIfNecessary() {
        synchronizationQueue.sync {
            guard self.isActiveRequestCountBelowMaximumLimit() else { return }
            
            while !self.queuedRequests.isEmpty {
                if let request = self.dequeue(), request.task?.state == .suspended {
                    self.start(request)
                    break
                }
            }
        }
    }
    
    func safelyDecrementActiveRequestCount() {
        self.synchronizationQueue.sync {
            if self.activeRequestCount > 0 {
                self.activeRequestCount -= 1
            }
        }
    }
    
    // MARK: Internal - Non Thread-Safe Request Methods
    
    func start(_ request: Request) {
        request.resume()
        activeRequestCount += 1
    }
    
    func enqueue(_ request: Request) {
        switch downloadPrioritization {
        case .fifo:
            queuedRequests.append(request)
        case .lifo:
            queuedRequests.insert(request, at: 0)
        }
    }
    
    @discardableResult
    func dequeue() -> Request? {
        var request: Request?
        
        if !queuedRequests.isEmpty {
            request = queuedRequests.removeFirst()
        }
        
        return request
    }
    
    func isActiveRequestCountBelowMaximumLimit() -> Bool {
        return activeRequestCount < maximumActiveDownloads
    }
    
    static func urlIdentifier(for urlRequest: URLRequestConvertible) -> String {
        return urlRequest.urlRequest?.url?.absoluteString ?? ""
    }
}
