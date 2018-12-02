//
//  ImageCache.swift
//  HGImageLib
//
//  Created by Haresh on 03/12/18.
//  Copyright © 2018 Haresh. All rights reserved.
//

import Foundation

#if os(iOS)

import UIKit

#endif

// MARK: ImageCache

/// The `ImageCache` protocol defines a set of APIs for adding, removing and fetching images from a cache.
public protocol ImageCache {
    /// Adds the image to the cache with the given identifier.
    func add(_ image: Image, withIdentifier identifier: String)
    
    /// Removes the image from the cache matching the given identifier.
    func removeImage(withIdentifier identifier: String) -> Bool
    
    /// Removes all images stored in the cache.
    @discardableResult
    func removeAllImages() -> Bool
    
    /// Returns the image in the cache associated with the given identifier.
    func image(withIdentifier identifier: String) -> Image?
}

/// The `ImageRequestCache` protocol extends the `ImageCache` protocol by adding methods for adding, removing and
/// fetching images from a cache given an `URLRequest` and additional identifier.
public protocol ImageRequestCache: ImageCache {
    /// Adds the image to the cache using an identifier created from the request and identifier.
    func add(_ image: Image, for request: URLRequest, withIdentifier identifier: String?)
    
    /// Removes the image from the cache using an identifier created from the request and identifier.
    func removeImage(for request: URLRequest, withIdentifier identifier: String?) -> Bool
    
    /// Returns the image from the cache associated with an identifier created from the request and identifier.
    func image(for request: URLRequest, withIdentifier identifier: String?) -> Image?
}

// MARK: -

open class AutoPurgingImageCache: ImageRequestCache {
    class CachedImage {
        let image: Image
        let identifier: String
        let totalBytes: UInt64
        var lastAccessDate: Date
        
        init(_ image: Image, identifier: String) {
            self.image = image
            self.identifier = identifier
            self.lastAccessDate = Date()
            
            self.totalBytes = {
                #if os(iOS) || os(tvOS) || os(watchOS)
                let size = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
                #elseif os(macOS)
                let size = CGSize(width: image.size.width, height: image.size.height)
                #endif
                
                let bytesPerPixel: CGFloat = 4.0
                let bytesPerRow = size.width * bytesPerPixel
                let totalBytes = UInt64(bytesPerRow) * UInt64(size.height)
                
                return totalBytes
            }()
        }
        
        func accessImage() -> Image {
            lastAccessDate = Date()
            return image
        }
    }
    
    // MARK: Properties
    
    /// The current total memory usage in bytes of all images stored within the cache.
    open var memoryUsage: UInt64 {
        var memoryUsage: UInt64 = 0
        synchronizationQueue.sync { memoryUsage = self.currentMemoryUsage }
        
        return memoryUsage
    }
    
    /// The total memory capacity of the cache in bytes.
    public let memoryCapacity: UInt64
    
    /// The preferred memory usage after purge in bytes. During a purge, images will be purged until the memory
    /// capacity drops below this limit.
    public let preferredMemoryUsageAfterPurge: UInt64
    
    private let synchronizationQueue: DispatchQueue
    private var cachedImages: [String: CachedImage]
    private var currentMemoryUsage: UInt64
    
    // MARK: Initialization
    
    public init(memoryCapacity: UInt64 = 100_000_000, preferredMemoryUsageAfterPurge: UInt64 = 60_000_000) {
        self.memoryCapacity = memoryCapacity
        self.preferredMemoryUsageAfterPurge = preferredMemoryUsageAfterPurge
        
        precondition(
            memoryCapacity >= preferredMemoryUsageAfterPurge,
            "The `memoryCapacity` must be greater than or equal to `preferredMemoryUsageAfterPurge`"
        )
        
        self.cachedImages = [:]
        self.currentMemoryUsage = 0
        
        self.synchronizationQueue = {
            let name = String(format: "org.hgnetworklib.autopurgingimagecache-%08x%08x", arc4random(), arc4random())
            return DispatchQueue(label: name, attributes: .concurrent)
        }()
        
        #if os(iOS) || os(tvOS)
        #if swift(>=4.2)
        let notification = UIApplication.didReceiveMemoryWarningNotification
        #else
        let notification = Notification.Name.UIApplicationDidReceiveMemoryWarning
        #endif
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(AutoPurgingImageCache.removeAllImages),
            name: notification,
            object: nil
        )
        #endif
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: Add Image to Cache
    
    open func add(_ image: Image, for request: URLRequest, withIdentifier identifier: String? = nil) {
        let requestIdentifier = imageCacheKey(for: request, withIdentifier: identifier)
        add(image, withIdentifier: requestIdentifier)
    }
    
    open func add(_ image: Image, withIdentifier identifier: String) {
        synchronizationQueue.async(flags: [.barrier]) {
            let cachedImage = CachedImage(image, identifier: identifier)
            
            if let previousCachedImage = self.cachedImages[identifier] {
                self.currentMemoryUsage -= previousCachedImage.totalBytes
            }
            
            self.cachedImages[identifier] = cachedImage
            self.currentMemoryUsage += cachedImage.totalBytes
        }
        
        synchronizationQueue.async(flags: [.barrier]) {
            if self.currentMemoryUsage > self.memoryCapacity {
                let bytesToPurge = self.currentMemoryUsage - self.preferredMemoryUsageAfterPurge
                
                var sortedImages = self.cachedImages.map { $1 }
                
                sortedImages.sort {
                    let date1 = $0.lastAccessDate
                    let date2 = $1.lastAccessDate
                    
                    return date1.timeIntervalSince(date2) < 0.0
                }
                
                var bytesPurged = UInt64(0)
                
                for cachedImage in sortedImages {
                    self.cachedImages.removeValue(forKey: cachedImage.identifier)
                    bytesPurged += cachedImage.totalBytes
                    
                    if bytesPurged >= bytesToPurge {
                        break
                    }
                }
                
                self.currentMemoryUsage -= bytesPurged
            }
        }
    }
    
    // MARK: Remove Image from Cache
    
    @discardableResult
    open func removeImage(for request: URLRequest, withIdentifier identifier: String?) -> Bool {
        let requestIdentifier = imageCacheKey(for: request, withIdentifier: identifier)
        return removeImage(withIdentifier: requestIdentifier)
    }
    
    @discardableResult
    open func removeImages(matching request: URLRequest) -> Bool {
        let requestIdentifier = imageCacheKey(for: request, withIdentifier: nil)
        var removed = false
        
        synchronizationQueue.sync {
            for key in self.cachedImages.keys where key.hasPrefix(requestIdentifier) {
                if let cachedImage = self.cachedImages.removeValue(forKey: key) {
                    self.currentMemoryUsage -= cachedImage.totalBytes
                    removed = true
                }
            }
        }
        
        return removed
    }
    
    @discardableResult
    open func removeImage(withIdentifier identifier: String) -> Bool {
        var removed = false
        
        synchronizationQueue.sync {
            if let cachedImage = self.cachedImages.removeValue(forKey: identifier) {
                self.currentMemoryUsage -= cachedImage.totalBytes
                removed = true
            }
        }
        
        return removed
    }
    
    @discardableResult @objc
    open func removeAllImages() -> Bool {
        var removed = false
        
        synchronizationQueue.sync {
            if !self.cachedImages.isEmpty {
                self.cachedImages.removeAll()
                self.currentMemoryUsage = 0
                
                removed = true
            }
        }
        
        return removed
    }
    
    // MARK: Fetch Image from Cache
    
    open func image(for request: URLRequest, withIdentifier identifier: String? = nil) -> Image? {
        let requestIdentifier = imageCacheKey(for: request, withIdentifier: identifier)
        return image(withIdentifier: requestIdentifier)
    }
    
    open func image(withIdentifier identifier: String) -> Image? {
        var image: Image?
        
        synchronizationQueue.sync {
            if let cachedImage = self.cachedImages[identifier] {
                image = cachedImage.accessImage()
            }
        }
        
        return image
    }
    
    // MARK: Image Cache Keys
    
    open func imageCacheKey(for request: URLRequest, withIdentifier identifier: String?) -> String {
        var key = request.url?.absoluteString ?? ""
        
        if let identifier = identifier {
            key += "-\(identifier)"
        }
        
        return key
    }
}

