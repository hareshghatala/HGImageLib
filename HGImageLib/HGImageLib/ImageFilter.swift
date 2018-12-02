//
//  ImageFilter.swift
//  HGImageLib
//
//  Created by Haresh on 03/12/18.
//  Copyright © 2018 Haresh. All rights reserved.
//

import Foundation

#if os(iOS)

import UIKit

#endif

// MARK: ImageFilter

/// The `ImageFilter` protocol defines properties for filtering an image as well as identification of the filter.
public protocol ImageFilter {
    /// A closure used to create an alternative representation of the given image.
    var filter: (Image) -> Image { get }
    
    /// The string used to uniquely identify the filter operation.
    var identifier: String { get }
}

extension ImageFilter {
    /// The unique identifier for any `ImageFilter` type.
    public var identifier: String { return "\(type(of: self))" }
}

// MARK: - Sizable

/// The `Sizable` protocol defines a size property intended for use with `ImageFilter` types.
public protocol Sizable {
    /// The size of the type.
    var size: CGSize { get }
}

extension ImageFilter where Self: Sizable {
    /// The unique idenitifier for an `ImageFilter` conforming to the `Sizable` protocol.
    public var identifier: String {
        let width = Int64(size.width.rounded())
        let height = Int64(size.height.rounded())
        
        return "\(type(of: self))-size:(\(width)x\(height))"
    }
}

// MARK: - Roundable

/// The `Roundable` protocol defines a radius property intended for use with `ImageFilter` types.
public protocol Roundable {
    /// The radius of the type.
    var radius: CGFloat { get }
}

extension ImageFilter where Self: Roundable {
    /// The unique idenitifier for an `ImageFilter` conforming to the `Roundable` protocol.
    public var identifier: String {
        let radius = Int64(self.radius.rounded())
        return "\(type(of: self))-radius:(\(radius))"
    }
}

// MARK: - DynamicImageFilter

/// The `DynamicImageFilter` class simplifies custom image filter creation by using a trailing closure initializer.
public struct DynamicImageFilter: ImageFilter {
    /// The string used to uniquely identify the image filter operation.
    public let identifier: String
    
    /// A closure used to create an alternative representation of the given image.
    public let filter: (Image) -> Image
    
    public init(_ identifier: String, filter: @escaping (Image) -> Image) {
        self.identifier = identifier
        self.filter = filter
    }
}

// MARK: - CompositeImageFilter

/// The `CompositeImageFilter` protocol defines an additional `filters` property to support multiple composite filters.
public protocol CompositeImageFilter: ImageFilter {
    /// The image filters to apply to the image in sequential order.
    var filters: [ImageFilter] { get }
}

public extension CompositeImageFilter {
    /// The unique idenitifier for any `CompositeImageFilter` type.
    var identifier: String {
        return filters.map { $0.identifier }.joined(separator: "_")
    }
    
    /// The filter closure for any `CompositeImageFilter` type.
    var filter: (Image) -> Image {
        return { image in
            return self.filters.reduce(image) { $1.filter($0) }
        }
    }
}

// MARK: - DynamicCompositeImageFilter

/// The `DynamicCompositeImageFilter` class is a composite image filter based on a specified array of filters.
public struct DynamicCompositeImageFilter: CompositeImageFilter {
    /// The image filters to apply to the image in sequential order.
    public let filters: [ImageFilter]
    
    public init(_ filters: [ImageFilter]) {
        self.filters = filters
    }
    
    public init(_ filters: ImageFilter...) {
        self.init(filters)
    }
}

#if os(iOS) || os(tvOS) || os(watchOS)

// MARK: - Single Pass Image Filters (iOS, tvOS and watchOS only) -

/// Scales an image to a specified size.
public struct ScaledToSizeFilter: ImageFilter, Sizable {
    /// The size of the filter.
    public let size: CGSize
    
    public init(size: CGSize) {
        self.size = size
    }
    
    /// The filter closure used to create the modified representation of the given image.
    public var filter: (Image) -> Image {
        return { image in
            return image.hg_imageScaled(to: self.size)
        }
    }
}

// MARK: -

/// Scales an image from the center while maintaining the aspect ratio to fit within a specified size.
public struct AspectScaledToFitSizeFilter: ImageFilter, Sizable {
    /// The size of the filter.
    public let size: CGSize
    
    public init(size: CGSize) {
        self.size = size
    }
    
    /// The filter closure used to create the modified representation of the given image.
    public var filter: (Image) -> Image {
        return { image in
            return image.hg_imageAspectScaled(toFit: self.size)
        }
    }
}

// MARK: -

/// Scales an image from the center while maintaining the aspect ratio to fill a specified size. Any pixels that fall
/// outside the specified size are clipped.
public struct AspectScaledToFillSizeFilter: ImageFilter, Sizable {
    /// The size of the filter.
    public let size: CGSize
    
    public init(size: CGSize) {
        self.size = size
    }
    
    /// The filter closure used to create the modified representation of the given image.
    public var filter: (Image) -> Image {
        return { image in
            return image.hg_imageAspectScaled(toFill: self.size)
        }
    }
}

// MARK: -

/// Rounds the corners of an image to the specified radius.
public struct RoundedCornersFilter: ImageFilter, Roundable {
    /// The radius of the filter.
    public let radius: CGFloat
    
    /// Whether to divide the radius by the image scale.
    public let divideRadiusByImageScale: Bool
    
    public init(radius: CGFloat, divideRadiusByImageScale: Bool = false) {
        self.radius = radius
        self.divideRadiusByImageScale = divideRadiusByImageScale
    }
    
    /// The filter closure used to create the modified representation of the given image.
    public var filter: (Image) -> Image {
        return { image in
            return image.hg_imageRounded(
                withCornerRadius: self.radius,
                divideRadiusByImageScale: self.divideRadiusByImageScale
            )
        }
    }
    
    /// The unique idenitifier for an `ImageFilter` conforming to the `Roundable` protocol.
    public var identifier: String {
        let radius = Int64(self.radius.rounded())
        return "\(type(of: self))-radius:(\(radius))-divided:(\(divideRadiusByImageScale))"
    }
}

// MARK: -

/// Rounds the corners of an image into a circle.
public struct CircleFilter: ImageFilter {
    
    public init() {}
    
    /// The filter closure used to create the modified representation of the given image.
    public var filter: (Image) -> Image {
        return { image in
            return image.hg_imageRoundedIntoCircle()
        }
    }
}

// MARK: -

#if os(iOS) || os(tvOS)

/// The `CoreImageFilter` protocol defines `parameters`, `filterName` properties used by CoreImage.
@available(iOS 9.0, *)
public protocol CoreImageFilter: ImageFilter {
    /// The filter name of the CoreImage filter.
    var filterName: String { get }
    
    /// The image filter parameters passed to CoreImage.
    var parameters: [String: Any] { get }
}

@available(iOS 9.0, *)
public extension ImageFilter where Self: CoreImageFilter {
    /// The filter closure used to create the modified representation of the given image.
    public var filter: (Image) -> Image {
        return { image in
            return image.hg_imageFiltered(withCoreImageFilter: self.filterName, parameters: self.parameters) ?? image
        }
    }
    
    /// The unique idenitifier for an `ImageFilter` conforming to the `CoreImageFilter` protocol.
    public var identifier: String { return "\(type(of: self))-parameters:(\(self.parameters))" }
}

/// Blurs an image using a `CIGaussianBlur` filter with the specified blur radius.
@available(iOS 9.0, *)
public struct BlurFilter: ImageFilter, CoreImageFilter {
    /// The filter name.
    public let filterName = "CIGaussianBlur"
    
    /// The image filter parameters passed to CoreImage.
    public let parameters: [String: Any]
    
    public init(blurRadius: UInt = 10) {
        self.parameters = ["inputRadius": blurRadius]
    }
}

#endif

// MARK: - Composite Image Filters (iOS, tvOS and watchOS only) -

/// Scales an image to a specified size, then rounds the corners to the specified radius.
public struct ScaledToSizeWithRoundedCornersFilter: CompositeImageFilter {
    
    public init(size: CGSize, radius: CGFloat, divideRadiusByImageScale: Bool = false) {
        self.filters = [
            ScaledToSizeFilter(size: size),
            RoundedCornersFilter(radius: radius, divideRadiusByImageScale: divideRadiusByImageScale)
        ]
    }
    
    /// The image filters to apply to the image in sequential order.
    public let filters: [ImageFilter]
}

// MARK: -

/// Scales an image from the center while maintaining the aspect ratio to fit within a specified size, then rounds the
/// corners to the specified radius.
public struct AspectScaledToFillSizeWithRoundedCornersFilter: CompositeImageFilter {
    
    public init(size: CGSize, radius: CGFloat, divideRadiusByImageScale: Bool = false) {
        self.filters = [
            AspectScaledToFillSizeFilter(size: size),
            RoundedCornersFilter(radius: radius, divideRadiusByImageScale: divideRadiusByImageScale)
        ]
    }
    
    /// The image filters to apply to the image in sequential order.
    public let filters: [ImageFilter]
}

// MARK: -

/// Scales an image to a specified size, then rounds the corners into a circle.
public struct ScaledToSizeCircleFilter: CompositeImageFilter {
    
    public init(size: CGSize) {
        self.filters = [ScaledToSizeFilter(size: size), CircleFilter()]
    }
    
    /// The image filters to apply to the image in sequential order.
    public let filters: [ImageFilter]
}

// MARK: -

/// Scales an image from the center while maintaining the aspect ratio to fit within a specified size, then rounds the
/// corners into a circle.
public struct AspectScaledToFillSizeCircleFilter: CompositeImageFilter {
    
    public init(size: CGSize) {
        self.filters = [AspectScaledToFillSizeFilter(size: size), CircleFilter()]
    }
    
    /// The image filters to apply to the image in sequential order.
    public let filters: [ImageFilter]
}

#endif

