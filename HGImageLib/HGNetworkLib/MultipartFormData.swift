//
//  MultipartFormData.swift
//  HGImageLib
//
//  Created by Haresh on 03/12/18.
//  Copyright © 2018 Haresh. All rights reserved.
//

import Foundation

#if os(iOS)

import MobileCoreServices

#endif

open class MultipartFormData {
    
    // MARK: - Helper Types
    
    struct EncodingCharacters {
        static let crlf = "\r\n"
    }
    
    struct BoundaryGenerator {
        enum BoundaryType {
            case initial, encapsulated, final
        }
        
        static func randomBoundary() -> String {
            return String(format: "hgnetworklib.boundary.%08x%08x", arc4random(), arc4random())
        }
        
        static func boundaryData(forBoundaryType boundaryType: BoundaryType, boundary: String) -> Data {
            let boundaryText: String
            
            switch boundaryType {
            case .initial:
                boundaryText = "--\(boundary)\(EncodingCharacters.crlf)"
            case .encapsulated:
                boundaryText = "\(EncodingCharacters.crlf)--\(boundary)\(EncodingCharacters.crlf)"
            case .final:
                boundaryText = "\(EncodingCharacters.crlf)--\(boundary)--\(EncodingCharacters.crlf)"
            }
            
            return boundaryText.data(using: String.Encoding.utf8, allowLossyConversion: false)!
        }
    }
    
    class BodyPart {
        let headers: HTTPHeaders
        let bodyStream: InputStream
        let bodyContentLength: UInt64
        var hasInitialBoundary = false
        var hasFinalBoundary = false
        
        init(headers: HTTPHeaders, bodyStream: InputStream, bodyContentLength: UInt64) {
            self.headers = headers
            self.bodyStream = bodyStream
            self.bodyContentLength = bodyContentLength
        }
    }
    
    // MARK: - Properties
    
    /// The `Content-Type` header value containing the boundary used to generate the `multipart/form-data`.
    open lazy var contentType: String = "multipart/form-data; boundary=\(self.boundary)"
    
    /// The content length of all body parts used to generate the `multipart/form-data` not including the boundaries.
    public var contentLength: UInt64 { return bodyParts.reduce(0) { $0 + $1.bodyContentLength } }
    
    /// The boundary used to separate the body parts in the encoded form data.
    public let boundary: String
    
    private var bodyParts: [BodyPart]
    private var bodyPartError: HGError?
    private let streamBufferSize: Int
    
    // MARK: - Lifecycle
    
    public init() {
        self.boundary = BoundaryGenerator.randomBoundary()
        self.bodyParts = []
        
        self.streamBufferSize = 1024
    }
    
    // MARK: - Body Parts
    
    public func append(_ data: Data, withName name: String) {
        let headers = contentHeaders(withName: name)
        let stream = InputStream(data: data)
        let length = UInt64(data.count)
        
        append(stream, withLength: length, headers: headers)
    }
    
    public func append(_ data: Data, withName name: String, mimeType: String) {
        let headers = contentHeaders(withName: name, mimeType: mimeType)
        let stream = InputStream(data: data)
        let length = UInt64(data.count)
        
        append(stream, withLength: length, headers: headers)
    }
    
    public func append(_ data: Data, withName name: String, fileName: String, mimeType: String) {
        let headers = contentHeaders(withName: name, fileName: fileName, mimeType: mimeType)
        let stream = InputStream(data: data)
        let length = UInt64(data.count)
        
        append(stream, withLength: length, headers: headers)
    }
    
    public func append(_ fileURL: URL, withName name: String) {
        let fileName = fileURL.lastPathComponent
        let pathExtension = fileURL.pathExtension
        
        if !fileName.isEmpty && !pathExtension.isEmpty {
            let mime = mimeType(forPathExtension: pathExtension)
            append(fileURL, withName: name, fileName: fileName, mimeType: mime)
        } else {
            setBodyPartError(withReason: .bodyPartFilenameInvalid(in: fileURL))
        }
    }
    
    public func append(_ fileURL: URL, withName name: String, fileName: String, mimeType: String) {
        let headers = contentHeaders(withName: name, fileName: fileName, mimeType: mimeType)
        
        //============================================================
        //                 Check 1 - is file URL?
        //============================================================
        
        guard fileURL.isFileURL else {
            setBodyPartError(withReason: .bodyPartURLInvalid(url: fileURL))
            return
        }
        
        //============================================================
        //              Check 2 - is file URL reachable?
        //============================================================
        
        do {
            let isReachable = try fileURL.checkPromisedItemIsReachable()
            guard isReachable else {
                setBodyPartError(withReason: .bodyPartFileNotReachable(at: fileURL))
                return
            }
        } catch {
            setBodyPartError(withReason: .bodyPartFileNotReachableWithError(atURL: fileURL, error: error))
            return
        }
        
        //============================================================
        //            Check 3 - is file URL a directory?
        //============================================================
        
        var isDirectory: ObjCBool = false
        let path = fileURL.path
        
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && !isDirectory.boolValue else {
            setBodyPartError(withReason: .bodyPartFileIsDirectory(at: fileURL))
            return
        }
        
        //============================================================
        //          Check 4 - can the file size be extracted?
        //============================================================
        
        let bodyContentLength: UInt64
        
        do {
            guard let fileSize = try FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber else {
                setBodyPartError(withReason: .bodyPartFileSizeNotAvailable(at: fileURL))
                return
            }
            
            bodyContentLength = fileSize.uint64Value
        }
        catch {
            setBodyPartError(withReason: .bodyPartFileSizeQueryFailedWithError(forURL: fileURL, error: error))
            return
        }
        
        //============================================================
        //       Check 5 - can a stream be created from file URL?
        //============================================================
        
        guard let stream = InputStream(url: fileURL) else {
            setBodyPartError(withReason: .bodyPartInputStreamCreationFailed(for: fileURL))
            return
        }
        
        append(stream, withLength: bodyContentLength, headers: headers)
    }
    
    public func append(
        _ stream: InputStream,
        withLength length: UInt64,
        name: String,
        fileName: String,
        mimeType: String)
    {
        let headers = contentHeaders(withName: name, fileName: fileName, mimeType: mimeType)
        append(stream, withLength: length, headers: headers)
    }
    
    public func append(_ stream: InputStream, withLength length: UInt64, headers: HTTPHeaders) {
        let bodyPart = BodyPart(headers: headers, bodyStream: stream, bodyContentLength: length)
        bodyParts.append(bodyPart)
    }
    
    // MARK: - Data Encoding
    
    public func encode() throws -> Data {
        if let bodyPartError = bodyPartError {
            throw bodyPartError
        }
        
        var encoded = Data()
        
        bodyParts.first?.hasInitialBoundary = true
        bodyParts.last?.hasFinalBoundary = true
        
        for bodyPart in bodyParts {
            let encodedData = try encode(bodyPart)
            encoded.append(encodedData)
        }
        
        return encoded
    }
    
    public func writeEncodedData(to fileURL: URL) throws {
        if let bodyPartError = bodyPartError {
            throw bodyPartError
        }
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            throw HGError.multipartEncodingFailed(reason: .outputStreamFileAlreadyExists(at: fileURL))
        } else if !fileURL.isFileURL {
            throw HGError.multipartEncodingFailed(reason: .outputStreamURLInvalid(url: fileURL))
        }
        
        guard let outputStream = OutputStream(url: fileURL, append: false) else {
            throw HGError.multipartEncodingFailed(reason: .outputStreamCreationFailed(for: fileURL))
        }
        
        outputStream.open()
        defer { outputStream.close() }
        
        self.bodyParts.first?.hasInitialBoundary = true
        self.bodyParts.last?.hasFinalBoundary = true
        
        for bodyPart in self.bodyParts {
            try write(bodyPart, to: outputStream)
        }
    }
    
    // MARK: - Private - Body Part Encoding
    
    private func encode(_ bodyPart: BodyPart) throws -> Data {
        var encoded = Data()
        
        let initialData = bodyPart.hasInitialBoundary ? initialBoundaryData() : encapsulatedBoundaryData()
        encoded.append(initialData)
        
        let headerData = encodeHeaders(for: bodyPart)
        encoded.append(headerData)
        
        let bodyStreamData = try encodeBodyStream(for: bodyPart)
        encoded.append(bodyStreamData)
        
        if bodyPart.hasFinalBoundary {
            encoded.append(finalBoundaryData())
        }
        
        return encoded
    }
    
    private func encodeHeaders(for bodyPart: BodyPart) -> Data {
        var headerText = ""
        
        for (key, value) in bodyPart.headers {
            headerText += "\(key): \(value)\(EncodingCharacters.crlf)"
        }
        headerText += EncodingCharacters.crlf
        
        return headerText.data(using: String.Encoding.utf8, allowLossyConversion: false)!
    }
    
    private func encodeBodyStream(for bodyPart: BodyPart) throws -> Data {
        let inputStream = bodyPart.bodyStream
        inputStream.open()
        defer { inputStream.close() }
        
        var encoded = Data()
        
        while inputStream.hasBytesAvailable {
            var buffer = [UInt8](repeating: 0, count: streamBufferSize)
            let bytesRead = inputStream.read(&buffer, maxLength: streamBufferSize)
            
            if let error = inputStream.streamError {
                throw HGError.multipartEncodingFailed(reason: .inputStreamReadFailed(error: error))
            }
            
            if bytesRead > 0 {
                encoded.append(buffer, count: bytesRead)
            } else {
                break
            }
        }
        
        return encoded
    }
    
    // MARK: - Private - Writing Body Part to Output Stream
    
    private func write(_ bodyPart: BodyPart, to outputStream: OutputStream) throws {
        try writeInitialBoundaryData(for: bodyPart, to: outputStream)
        try writeHeaderData(for: bodyPart, to: outputStream)
        try writeBodyStream(for: bodyPart, to: outputStream)
        try writeFinalBoundaryData(for: bodyPart, to: outputStream)
    }
    
    private func writeInitialBoundaryData(for bodyPart: BodyPart, to outputStream: OutputStream) throws {
        let initialData = bodyPart.hasInitialBoundary ? initialBoundaryData() : encapsulatedBoundaryData()
        return try write(initialData, to: outputStream)
    }
    
    private func writeHeaderData(for bodyPart: BodyPart, to outputStream: OutputStream) throws {
        let headerData = encodeHeaders(for: bodyPart)
        return try write(headerData, to: outputStream)
    }
    
    private func writeBodyStream(for bodyPart: BodyPart, to outputStream: OutputStream) throws {
        let inputStream = bodyPart.bodyStream
        
        inputStream.open()
        defer { inputStream.close() }
        
        while inputStream.hasBytesAvailable {
            var buffer = [UInt8](repeating: 0, count: streamBufferSize)
            let bytesRead = inputStream.read(&buffer, maxLength: streamBufferSize)
            
            if let streamError = inputStream.streamError {
                throw HGError.multipartEncodingFailed(reason: .inputStreamReadFailed(error: streamError))
            }
            
            if bytesRead > 0 {
                if buffer.count != bytesRead {
                    buffer = Array(buffer[0..<bytesRead])
                }
                
                try write(&buffer, to: outputStream)
            } else {
                break
            }
        }
    }
    
    private func writeFinalBoundaryData(for bodyPart: BodyPart, to outputStream: OutputStream) throws {
        if bodyPart.hasFinalBoundary {
            return try write(finalBoundaryData(), to: outputStream)
        }
    }
    
    // MARK: - Private - Writing Buffered Data to Output Stream
    
    private func write(_ data: Data, to outputStream: OutputStream) throws {
        var buffer = [UInt8](repeating: 0, count: data.count)
        data.copyBytes(to: &buffer, count: data.count)
        
        return try write(&buffer, to: outputStream)
    }
    
    private func write(_ buffer: inout [UInt8], to outputStream: OutputStream) throws {
        var bytesToWrite = buffer.count
        
        while bytesToWrite > 0, outputStream.hasSpaceAvailable {
            let bytesWritten = outputStream.write(buffer, maxLength: bytesToWrite)
            
            if let error = outputStream.streamError {
                throw HGError.multipartEncodingFailed(reason: .outputStreamWriteFailed(error: error))
            }
            
            bytesToWrite -= bytesWritten
            
            if bytesToWrite > 0 {
                buffer = Array(buffer[bytesWritten..<buffer.count])
            }
        }
    }
    
    // MARK: - Private - Mime Type
    
    private func mimeType(forPathExtension pathExtension: String) -> String {
        if
            let id = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension as CFString, nil)?.takeRetainedValue(),
            let contentType = UTTypeCopyPreferredTagWithClass(id, kUTTagClassMIMEType)?.takeRetainedValue()
        {
            return contentType as String
        }
        
        return "application/octet-stream"
    }
    
    // MARK: - Private - Content Headers
    
    private func contentHeaders(withName name: String, fileName: String? = nil, mimeType: String? = nil) -> [String: String] {
        var disposition = "form-data; name=\"\(name)\""
        if let fileName = fileName { disposition += "; filename=\"\(fileName)\"" }
        
        var headers = ["Content-Disposition": disposition]
        if let mimeType = mimeType { headers["Content-Type"] = mimeType }
        
        return headers
    }
    
    // MARK: - Private - Boundary Encoding
    
    private func initialBoundaryData() -> Data {
        return BoundaryGenerator.boundaryData(forBoundaryType: .initial, boundary: boundary)
    }
    
    private func encapsulatedBoundaryData() -> Data {
        return BoundaryGenerator.boundaryData(forBoundaryType: .encapsulated, boundary: boundary)
    }
    
    private func finalBoundaryData() -> Data {
        return BoundaryGenerator.boundaryData(forBoundaryType: .final, boundary: boundary)
    }
    
    // MARK: - Private - Errors
    
    private func setBodyPartError(withReason reason: HGError.MultipartEncodingFailureReason) {
        guard bodyPartError == nil else { return }
        bodyPartError = HGError.multipartEncodingFailed(reason: reason)
    }
}

