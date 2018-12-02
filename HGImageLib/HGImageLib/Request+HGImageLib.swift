//
//  Request+HGImageLib.swift
//  HGImageLib
//
//  Created by Haresh on 03/12/18.
//  Copyright © 2018 Haresh. All rights reserved.
//

import Foundation

#if os(iOS)

import UIKit

#endif

extension DataRequest {
    static var acceptableImageContentTypes: Set<String> = [
        "image/tiff",
        "image/jpeg",
        "image/gif",
        "image/png",
        "image/ico",
        "image/x-icon",
        "image/bmp",
        "image/x-bmp",
        "image/x-xbitmap",
        "image/x-ms-bmp",
        "image/x-win-bitmap"
    ]
    
    static let streamImageInitialBytePattern = Data(bytes: [255, 216])
    
    public class func addAcceptableImageContentTypes(_ contentTypes: Set<String>) {
        DataRequest.acceptableImageContentTypes.formUnion(contentTypes)
    }
    
    // MARK: - iOS
    
    #if os(iOS)
    
    public class func imageResponseSerializer(
        imageScale: CGFloat = DataRequest.imageScale,
        inflateResponseImage: Bool = true)
        -> DataResponseSerializer<Image>
    {
        return DataResponseSerializer { request, response, data, error in
            let result = serializeResponseData(response: response, data: data, error: error)
            
            guard case let .success(data) = result else { return .failure(result.error!) }
            
            do {
                try DataRequest.validateContentType(for: request, response: response)
                
                let image = try DataRequest.image(from: data, withImageScale: imageScale)
                if inflateResponseImage { image.hg_inflate() }
                
                return .success(image)
            } catch {
                return .failure(error)
            }
        }
    }
    
    @discardableResult
    public func responseImage(
        imageScale: CGFloat = DataRequest.imageScale,
        inflateResponseImage: Bool = true,
        queue: DispatchQueue? = nil,
        completionHandler: @escaping (DataResponse<Image>) -> Void)
        -> Self
    {
        return response(
            queue: queue,
            responseSerializer: DataRequest.imageResponseSerializer(
                imageScale: imageScale,
                inflateResponseImage: inflateResponseImage
            ),
            completionHandler: completionHandler
        )
    }
    
    @discardableResult
    public func streamImage(
        imageScale: CGFloat = DataRequest.imageScale,
        inflateResponseImage: Bool = true,
        completionHandler: @escaping (Image) -> Void)
        -> Self
    {
        var imageData = Data()
        
        return stream { chunkData in
            if chunkData.starts(with: DataRequest.streamImageInitialBytePattern) {
                imageData = Data()
            }
            
            imageData.append(chunkData)
            
            if let image = DataRequest.serializeImage(from: imageData) {
                completionHandler(image)
            }
        }
    }
    
    private class func serializeImage(
        from data: Data,
        imageScale: CGFloat = DataRequest.imageScale,
        inflateResponseImage: Bool = true)
        -> UIImage?
    {
        guard data.count > 0 else { return nil }
        
        do {
            let image = try DataRequest.image(from: data, withImageScale: imageScale)
            if inflateResponseImage { image.hg_inflate() }
            
            return image
        } catch {
            return nil
        }
    }
    
    private class func image(from data: Data, withImageScale imageScale: CGFloat) throws -> UIImage {
        if let image = UIImage.hg_threadSafeImage(with: data, scale: imageScale) {
            return image
        }
        
        throw HGIError.imageSerializationFailed
    }
    
    public class var imageScale: CGFloat {
        #if os(iOS)
        return UIScreen.main.scale
        #endif
    }
    
    #elseif os(macOS)
    
    // MARK: - macOS
    public class func imageResponseSerializer() -> DataResponseSerializer<Image> {
        return DataResponseSerializer { request, response, data, error in
            let result = serializeResponseData(response: response, data: data, error: error)
            
            guard case let .success(data) = result else { return .failure(result.error!) }
            
            do {
                try DataRequest.validateContentType(for: request, response: response)
            } catch {
                return .failure(error)
            }
            
            guard let bitmapImage = NSBitmapImageRep(data: data) else {
                return .failure(HGIError.imageSerializationFailed)
            }
            
            let image = NSImage(size: NSSize(width: bitmapImage.pixelsWide, height: bitmapImage.pixelsHigh))
            image.addRepresentation(bitmapImage)
            
            return .success(image)
        }
    }
    
    @discardableResult
    public func responseImage(
        queue: DispatchQueue? = nil,
        completionHandler: @escaping (DataResponse<Image>) -> Void)
        -> Self {
            return response(
                queue: queue,
                responseSerializer: DataRequest.imageResponseSerializer(),
                completionHandler: completionHandler
            )
    }
    
    @discardableResult
    public func streamImage(completionHandler: @escaping (Image) -> Void) -> Self {
        var imageData = Data()
        
        return stream { chunkData in
            if chunkData.starts(with: DataRequest.streamImageInitialBytePattern) {
                imageData = Data()
            }
            
            imageData.append(chunkData)
            
            if let image = DataRequest.serializeImage(from: imageData) {
                completionHandler(image)
            }
        }
    }
    
    private class func serializeImage(from data: Data) -> NSImage? {
        guard data.count > 0 else { return nil }
        guard let bitmapImage = NSBitmapImageRep(data: data) else { return nil }
        
        let image = NSImage(size: NSSize(width: bitmapImage.pixelsWide, height: bitmapImage.pixelsHigh))
        image.addRepresentation(bitmapImage)
        
        return image
    }
    
    #endif
    
    public class func validateContentType(for request: URLRequest?, response: HTTPURLResponse?) throws {
        if let url = request?.url, url.isFileURL { return }
        
        guard let mimeType = response?.mimeType else {
            let contentTypes = Array(DataRequest.acceptableImageContentTypes)
            throw HGError.responseValidationFailed(reason: .missingContentType(acceptableContentTypes: contentTypes))
        }
        
        guard DataRequest.acceptableImageContentTypes.contains(mimeType) else {
            let contentTypes = Array(DataRequest.acceptableImageContentTypes)
            
            throw HGError.responseValidationFailed(
                reason: .unacceptableContentType(acceptableContentTypes: contentTypes, responseContentType: mimeType)
            )
        }
    }
}
