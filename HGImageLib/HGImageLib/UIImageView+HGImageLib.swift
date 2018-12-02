//
//  UIImageView+HGImageLib.swift
//  HGImageLib
//
//  Created by Haresh on 02/12/18.
//  Copyright © 2018 Haresh. All rights reserved.
//

import Foundation

#if os(iOS)

import UIKit

#if swift(>=4.2)
public typealias AnimationOptions = UIView.AnimationOptions
#else
public typealias AnimationOptions = UIViewAnimationOptions
#endif

extension UIImageView {
    
    // MARK: - ImageTransition
    
    /// Used to wrap all `UIView` animation transition options alongside a duration.
    public enum ImageTransition {
        case noTransition
        case crossDissolve(TimeInterval)
        case curlDown(TimeInterval)
        case curlUp(TimeInterval)
        case flipFromBottom(TimeInterval)
        case flipFromLeft(TimeInterval)
        case flipFromRight(TimeInterval)
        case flipFromTop(TimeInterval)
        case custom(
            duration: TimeInterval,
            animationOptions: AnimationOptions,
            animations: (UIImageView, Image) -> Void,
            completion: ((Bool) -> Void)?
        )
        
        /// The duration of the image transition in seconds.
        public var duration: TimeInterval {
            switch self {
            case .noTransition:
                return 0.0
            case .crossDissolve(let duration):
                return duration
            case .curlDown(let duration):
                return duration
            case .curlUp(let duration):
                return duration
            case .flipFromBottom(let duration):
                return duration
            case .flipFromLeft(let duration):
                return duration
            case .flipFromRight(let duration):
                return duration
            case .flipFromTop(let duration):
                return duration
            case .custom(let duration, _, _, _):
                return duration
            }
        }
        
        /// The animation options of the image transition.
        public var animationOptions: AnimationOptions {
            switch self {
            case .noTransition:
                return []
            case .crossDissolve:
                return .transitionCrossDissolve
            case .curlDown:
                return .transitionCurlDown
            case .curlUp:
                return .transitionCurlUp
            case .flipFromBottom:
                return .transitionFlipFromBottom
            case .flipFromLeft:
                return .transitionFlipFromLeft
            case .flipFromRight:
                return .transitionFlipFromRight
            case .flipFromTop:
                return .transitionFlipFromTop
            case .custom(_, let animationOptions, _, _):
                return animationOptions
            }
        }
        
        /// The animation options of the image transition.
        public var animations: ((UIImageView, Image) -> Void) {
            switch self {
            case .custom(_, _, let animations, _):
                return animations
            default:
                return { $0.image = $1 }
            }
        }
        
        /// The completion closure associated with the image transition.
        public var completion: ((Bool) -> Void)? {
            switch self {
            case .custom(_, _, _, let completion):
                return completion
            default:
                return nil
            }
        }
    }
    
    // MARK: - Private - AssociatedKeys
    
    private struct AssociatedKey {
        static var imageDownloader = "hg_UIImageView.ImageDownloader"
        static var sharedImageDownloader = "hg_UIImageView.SharedImageDownloader"
        static var activeRequestReceipt = "hg_UIImageView.ActiveRequestReceipt"
    }
    
    // MARK: - Associated Properties
    
    public var hg_imageDownloader: ImageDownloader? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKey.imageDownloader) as? ImageDownloader
        }
        set(downloader) {
            objc_setAssociatedObject(self, &AssociatedKey.imageDownloader, downloader, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    public class var hg_sharedImageDownloader: ImageDownloader {
        get {
            if let downloader = objc_getAssociatedObject(self, &AssociatedKey.sharedImageDownloader) as? ImageDownloader {
                return downloader
            } else {
                return ImageDownloader.default
            }
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKey.sharedImageDownloader, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    var hg_activeRequestReceipt: RequestReceipt? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKey.activeRequestReceipt) as? RequestReceipt
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKey.activeRequestReceipt, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    // MARK: - Image Download
    
    public func hg_setImage(
        withURL url: URL,
        placeholderImage: UIImage? = nil,
        filter: ImageFilter? = nil,
        progress: ImageDownloader.ProgressHandler? = nil,
        progressQueue: DispatchQueue = DispatchQueue.main,
        imageTransition: ImageTransition = .noTransition,
        runImageTransitionIfCached: Bool = false,
        completion: ((DataResponse<UIImage>) -> Void)? = nil)
    {
        hg_setImage(
            withURLRequest: urlRequest(with: url),
            placeholderImage: placeholderImage,
            filter: filter,
            progress: progress,
            progressQueue: progressQueue,
            imageTransition: imageTransition,
            runImageTransitionIfCached: runImageTransitionIfCached,
            completion: completion
        )
    }
    
    public func hg_setImage(
        withURLRequest urlRequest: URLRequestConvertible,
        placeholderImage: UIImage? = nil,
        filter: ImageFilter? = nil,
        progress: ImageDownloader.ProgressHandler? = nil,
        progressQueue: DispatchQueue = DispatchQueue.main,
        imageTransition: ImageTransition = .noTransition,
        runImageTransitionIfCached: Bool = false,
        completion: ((DataResponse<UIImage>) -> Void)? = nil)
    {
        guard !isURLRequestURLEqualToActiveRequestURL(urlRequest) else {
            let error = HGIError.requestCancelled
            let response = DataResponse<UIImage>(request: nil, response: nil, data: nil, result: .failure(error))
            
            completion?(response)
            
            return
        }
        
        hg_cancelImageRequest()
        
        let imageDownloader = hg_imageDownloader ?? UIImageView.hg_sharedImageDownloader
        let imageCache = imageDownloader.imageCache
        
        // Use the image from the image cache if it exists
        if
            let request = urlRequest.urlRequest,
            let image = imageCache?.image(for: request, withIdentifier: filter?.identifier)
        {
            let response = DataResponse<UIImage>(request: request, response: nil, data: nil, result: .success(image))
            
            if runImageTransitionIfCached {
                let tinyDelay = DispatchTime.now() + Double(Int64(0.001 * Float(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
                
                // Need to let the runloop cycle for the placeholder image to take affect
                DispatchQueue.main.asyncAfter(deadline: tinyDelay) {
                    self.run(imageTransition, with: image)
                    completion?(response)
                }
            } else {
                self.image = image
                completion?(response)
            }
            
            return
        }
        
        // Set the placeholder since we're going to have to download
        if let placeholderImage = placeholderImage { self.image = placeholderImage }
        
        // Generate a unique download id to check whether the active request has changed while downloading
        let downloadID = UUID().uuidString
        
        // Download the image, then run the image transition or completion handler
        let requestReceipt = imageDownloader.download(
            urlRequest,
            receiptID: downloadID,
            filter: filter,
            progress: progress,
            progressQueue: progressQueue,
            completion: { [weak self] response in
                guard
                    let strongSelf = self,
                    strongSelf.isURLRequestURLEqualToActiveRequestURL(response.request) &&
                        strongSelf.hg_activeRequestReceipt?.receiptID == downloadID
                    else {
                        completion?(response)
                        return
                }
                
                if let image = response.result.value {
                    strongSelf.run(imageTransition, with: image)
                }
                
                strongSelf.hg_activeRequestReceipt = nil
                
                completion?(response)
            }
        )
        
        hg_activeRequestReceipt = requestReceipt
    }
    
    // MARK: - Image Download Cancellation
    
    /// Cancels the active download request, if one exists.
    public func hg_cancelImageRequest() {
        guard let activeRequestReceipt = hg_activeRequestReceipt else { return }
        
        let imageDownloader = hg_imageDownloader ?? UIImageView.hg_sharedImageDownloader
        imageDownloader.cancelRequest(with: activeRequestReceipt)
        
        hg_activeRequestReceipt = nil
    }
    
    // MARK: - Image Transition
    
    public func run(_ imageTransition: ImageTransition, with image: Image) {
        UIView.transition(
            with: self,
            duration: imageTransition.duration,
            options: imageTransition.animationOptions,
            animations: { imageTransition.animations(self, image) },
            completion: imageTransition.completion
        )
    }
    
    // MARK: - Private - URL Request Helper Methods
    
    private func urlRequest(with url: URL) -> URLRequest {
        var urlRequest = URLRequest(url: url)
        
        for mimeType in DataRequest.acceptableImageContentTypes {
            urlRequest.addValue(mimeType, forHTTPHeaderField: "Accept")
        }
        
        return urlRequest
    }
    
    private func isURLRequestURLEqualToActiveRequestURL(_ urlRequest: URLRequestConvertible?) -> Bool {
        if
            let currentRequestURL = hg_activeRequestReceipt?.request.task?.originalRequest?.url,
            let requestURL = urlRequest?.urlRequest?.url,
            currentRequestURL == requestURL
        {
            return true
        }
        
        return false
    }
}

#endif
