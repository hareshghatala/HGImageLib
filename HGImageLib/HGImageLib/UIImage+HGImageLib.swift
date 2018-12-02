//
//  UIImage+HGImageLib.swift
//  HGImageLib
//
//  Created by Haresh on 03/12/18.
//  Copyright © 2018 Haresh. All rights reserved.
//

#if os(iOS)

import CoreGraphics
import Foundation
import UIKit

// MARK: Initialization

private let lock = NSLock()

extension UIImage {
    
    public static func hg_threadSafeImage(with data: Data) -> UIImage? {
        lock.lock()
        let image = UIImage(data: data)
        lock.unlock()
        
        return image
    }
    
    public static func hg_threadSafeImage(with data: Data, scale: CGFloat) -> UIImage? {
        lock.lock()
        let image = UIImage(data: data, scale: scale)
        lock.unlock()
        
        return image
    }
}

// MARK: - Inflation

extension UIImage {
    private struct AssociatedKey {
        static var inflated = "hg_UIImage.Inflated"
    }
    
    /// Returns whether the image is inflated.
    public var hg_inflated: Bool {
        get {
            if let inflated = objc_getAssociatedObject(self, &AssociatedKey.inflated) as? Bool {
                return inflated
            } else {
                return false
            }
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKey.inflated, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    public func hg_inflate() {
        guard !hg_inflated else { return }
        
        hg_inflated = true
        _ = cgImage?.dataProvider?.data
    }
}

// MARK: - Alpha

extension UIImage {
    /// Returns whether the image contains an alpha component.
    public var hg_containsAlphaComponent: Bool {
        let alphaInfo = cgImage?.alphaInfo
        
        return (
            alphaInfo == .first ||
                alphaInfo == .last ||
                alphaInfo == .premultipliedFirst ||
                alphaInfo == .premultipliedLast
        )
    }
    
    /// Returns whether the image is opaque.
    public var hg_isOpaque: Bool { return !hg_containsAlphaComponent }
}

// MARK: - Scaling

extension UIImage {
    
    public func hg_imageScaled(to size: CGSize) -> UIImage {
        assert(size.width > 0 && size.height > 0, "You cannot safely scale an image to a zero width or height")
        
        UIGraphicsBeginImageContextWithOptions(size, hg_isOpaque, 0.0)
        draw(in: CGRect(origin: .zero, size: size))
        
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()
        
        return scaledImage
    }
    
    public func hg_imageAspectScaled(toFit size: CGSize) -> UIImage {
        assert(size.width > 0 && size.height > 0, "You cannot safely scale an image to a zero width or height")
        
        let imageAspectRatio = self.size.width / self.size.height
        let canvasAspectRatio = size.width / size.height
        
        var resizeFactor: CGFloat
        
        if imageAspectRatio > canvasAspectRatio {
            resizeFactor = size.width / self.size.width
        } else {
            resizeFactor = size.height / self.size.height
        }
        
        let scaledSize = CGSize(width: self.size.width * resizeFactor, height: self.size.height * resizeFactor)
        let origin = CGPoint(x: (size.width - scaledSize.width) / 2.0, y: (size.height - scaledSize.height) / 2.0)
        
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        draw(in: CGRect(origin: origin, size: scaledSize))
        
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()
        
        return scaledImage
    }
    
    public func hg_imageAspectScaled(toFill size: CGSize) -> UIImage {
        assert(size.width > 0 && size.height > 0, "You cannot safely scale an image to a zero width or height")
        
        let imageAspectRatio = self.size.width / self.size.height
        let canvasAspectRatio = size.width / size.height
        
        var resizeFactor: CGFloat
        
        if imageAspectRatio > canvasAspectRatio {
            resizeFactor = size.height / self.size.height
        } else {
            resizeFactor = size.width / self.size.width
        }
        
        let scaledSize = CGSize(width: self.size.width * resizeFactor, height: self.size.height * resizeFactor)
        let origin = CGPoint(x: (size.width - scaledSize.width) / 2.0, y: (size.height - scaledSize.height) / 2.0)
        
        UIGraphicsBeginImageContextWithOptions(size, hg_isOpaque, 0.0)
        draw(in: CGRect(origin: origin, size: scaledSize))
        
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()
        
        return scaledImage
    }
}

// MARK: - Rounded Corners

extension UIImage {
    
    public func hg_imageRounded(withCornerRadius radius: CGFloat, divideRadiusByImageScale: Bool = false) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        
        let scaledRadius = divideRadiusByImageScale ? radius / scale : radius
        
        let clippingPath = UIBezierPath(roundedRect: CGRect(origin: CGPoint.zero, size: size), cornerRadius: scaledRadius)
        clippingPath.addClip()
        
        draw(in: CGRect(origin: CGPoint.zero, size: size))
        
        let roundedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return roundedImage
    }
    
    public func hg_imageRoundedIntoCircle() -> UIImage {
        let radius = min(size.width, size.height) / 2.0
        var squareImage = self
        
        if size.width != size.height {
            let squareDimension = min(size.width, size.height)
            let squareSize = CGSize(width: squareDimension, height: squareDimension)
            squareImage = hg_imageAspectScaled(toFill: squareSize)
        }
        
        UIGraphicsBeginImageContextWithOptions(squareImage.size, false, 0.0)
        
        let clippingPath = UIBezierPath(
            roundedRect: CGRect(origin: CGPoint.zero, size: squareImage.size),
            cornerRadius: radius
        )
        
        clippingPath.addClip()
        
        squareImage.draw(in: CGRect(origin: CGPoint.zero, size: squareImage.size))
        
        let roundedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return roundedImage
    }
}

#endif

#if os(iOS) || os(tvOS)

import CoreImage

// MARK: - Core Image Filters

@available(iOS 9.0, *)
extension UIImage {
    
    public func hg_imageFiltered(withCoreImageFilter name: String, parameters: [String: Any]? = nil) -> UIImage? {
        var image: CoreImage.CIImage? = ciImage
        
        if image == nil, let CGImage = self.cgImage {
            image = CoreImage.CIImage(cgImage: CGImage)
        }
        
        guard let coreImage = image else { return nil }
        
        #if swift(>=4.2)
        let context = CIContext(options: [.priorityRequestLow: true])
        #else
        let context = CIContext(options: [kCIContextPriorityRequestLow: true])
        #endif
        
        var parameters: [String: Any] = parameters ?? [:]
        parameters[kCIInputImageKey] = coreImage
        #if swift(>=4.2)
        guard let filter = CIFilter(name: name, parameters: parameters) else { return nil }
        #else
        guard let filter = CIFilter(name: name, withInputParameters: parameters) else { return nil }
        #endif
        guard let outputImage = filter.outputImage else { return nil }
        
        let cgImageRef = context.createCGImage(outputImage, from: outputImage.extent)
        
        return UIImage(cgImage: cgImageRef!, scale: scale, orientation: imageOrientation)
    }
}

#endif
