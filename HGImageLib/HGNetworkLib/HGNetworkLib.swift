//
//  HGNetworkLib.swift
//  HGImageLib
//
//  Created by Haresh on 02/12/18.
//  Copyright © 2018 Haresh. All rights reserved.
//

import Foundation

class HGNetworkLib {
    
   class func performGet(with urlString: String, completion: @escaping (Any?, Error?) -> Void) {
        guard let getURL = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: getURL, completionHandler: { responseData, _, error in
            if error != nil {
                completion(nil, error)
                return
            }
            
            guard let data = responseData else { return }
            do {
                let response = try JSONSerialization.jsonObject(with: data, options: [])
                completion(response, nil)
            } catch let jsonError {
                completion(nil, jsonError)
            }
        }).resume()
    }
    
}

/// URL requests.
public protocol URLConvertible {
    /**
     Returns a URL that conforms to RFC 2396 or throws an `Error`.
     
     - throws: An `Error` if the type cannot be converted to a `URL`.
     - returns: A URL or throws an `Error`.
     */
    func asURL() throws -> URL
}

extension String: URLConvertible {
    /**
     Returns a URL if `self` represents a valid URL string that conforms to RFC 2396 or throws an `HGError`.
    
     - throws: An `HGError.invalidURL` if `self` is not a valid URL string.
     - returns: A URL or throws an `HGError`.
     */
    public func asURL() throws -> URL {
        guard let url = URL(string: self) else { throw HGError.invalidURL(url: self) }
        return url
    }
}

extension URL: URLConvertible {
    /// Returns self.
    public func asURL() throws -> URL { return self }
}

extension URLComponents: URLConvertible {
    /**
     Returns a URL if `url` is not nil, otherwise throws an `Error`.
    
     - throws: An `HGError.invalidURL` if `url` is `nil`.
     - returns: A URL or throws an `HGError`.
     */
    public func asURL() throws -> URL {
        guard let url = url else { throw HGError.invalidURL(url: self) }
        return url
    }
}

// MARK: -

/// Types adopting the `URLRequestConvertible` protocol can be used to construct URL requests.
public protocol URLRequestConvertible {
    /**
     Returns a URL request or throws if an `Error` was encountered.
     
     - throws: An `Error` if the underlying `URLRequest` is `nil`.
     - returns: A URL request.
     */
    func asURLRequest() throws -> URLRequest
}

extension URLRequestConvertible {
    /// The URL request.
    public var urlRequest: URLRequest? { return try? asURLRequest() }
}

extension URLRequest: URLRequestConvertible {
    /// Returns a URL request or throws if an `Error` was encountered.
    public func asURLRequest() throws -> URLRequest { return self }
}

// MARK: -

extension URLRequest {
    /**
     Creates an instance with the specified `method`, `urlString` and `headers`.
    
     - parameters:
        - url: The URL.
        - method: The HTTP method.
        - headers: The HTTP headers. `nil` by default.
     - returns: The new `URLRequest` instance.
     */
    public init(url: URLConvertible, method: HTTPMethod, headers: HTTPHeaders? = nil) throws {
        let url = try url.asURL()
        
        self.init(url: url)
        
        httpMethod = method.rawValue
        
        if let headers = headers {
            for (headerField, headerValue) in headers {
                setValue(headerValue, forHTTPHeaderField: headerField)
            }
        }
    }
    
    func adapt(using adapter: RequestAdapter?) throws -> URLRequest {
        guard let adapter = adapter else { return self }
        return try adapter.adapt(self)
    }
}

// MARK: - Data Request

/**
 Creates a `DataRequest` using the default `SessionManager` to retrieve the contents of the specified `url`, `method`, `parameters`, `encoding` and `headers`.

 - parameters:
    - url: The URL.
    - method: The HTTP method. `.get` by default.
    - parameters: The parameters. `nil` by default.
    - encoding: The parameter encoding. `URLEncoding.default` by default.
    - headers: The HTTP headers. `nil` by default.
 - returns: The created `DataRequest`.
 */
@discardableResult
public func request(_ url: URLConvertible,
                    method: HTTPMethod = .get,
                    parameters: Parameters? = nil,
                    encoding: ParameterEncoding = URLEncoding.default,
                    headers: HTTPHeaders? = nil) -> DataRequest {
    return SessionManager.default.request(
        url,
        method: method,
        parameters: parameters,
        encoding: encoding,
        headers: headers
    )
}

@discardableResult
public func request(_ urlRequest: URLRequestConvertible) -> DataRequest {
    return SessionManager.default.request(urlRequest)
}

// MARK: - Download Request

// MARK: URL Request

@discardableResult
public func download(_ url: URLConvertible,
                     method: HTTPMethod = .get,
                     parameters: Parameters? = nil,
                     encoding: ParameterEncoding = URLEncoding.default,
                     headers: HTTPHeaders? = nil,
                     to destination: DownloadRequest.DownloadFileDestination? = nil) -> DownloadRequest {
    return SessionManager.default.download(
        url,
        method: method,
        parameters: parameters,
        encoding: encoding,
        headers: headers,
        to: destination
    )
}

@discardableResult
public func download(_ urlRequest: URLRequestConvertible,
    to destination: DownloadRequest.DownloadFileDestination? = nil) -> DownloadRequest {
    return SessionManager.default.download(urlRequest, to: destination)
}

// MARK: Resume Data

@discardableResult
public func download(
    resumingWith resumeData: Data,
    to destination: DownloadRequest.DownloadFileDestination? = nil)
    -> DownloadRequest
{
    return SessionManager.default.download(resumingWith: resumeData, to: destination)
}

// MARK: - Upload Request

// MARK: File

@discardableResult
public func upload(
    _ fileURL: URL,
    to url: URLConvertible,
    method: HTTPMethod = .post,
    headers: HTTPHeaders? = nil)
    -> UploadRequest
{
    return SessionManager.default.upload(fileURL, to: url, method: method, headers: headers)
}

@discardableResult
public func upload(_ fileURL: URL, with urlRequest: URLRequestConvertible) -> UploadRequest {
    return SessionManager.default.upload(fileURL, with: urlRequest)
}

// MARK: Data

@discardableResult
public func upload(
    _ data: Data,
    to url: URLConvertible,
    method: HTTPMethod = .post,
    headers: HTTPHeaders? = nil)
    -> UploadRequest
{
    return SessionManager.default.upload(data, to: url, method: method, headers: headers)
}

@discardableResult
public func upload(_ data: Data, with urlRequest: URLRequestConvertible) -> UploadRequest {
    return SessionManager.default.upload(data, with: urlRequest)
}

// MARK: InputStream

@discardableResult
public func upload(
    _ stream: InputStream,
    to url: URLConvertible,
    method: HTTPMethod = .post,
    headers: HTTPHeaders? = nil)
    -> UploadRequest
{
    return SessionManager.default.upload(stream, to: url, method: method, headers: headers)
}

@discardableResult
public func upload(_ stream: InputStream, with urlRequest: URLRequestConvertible) -> UploadRequest {
    return SessionManager.default.upload(stream, with: urlRequest)
}

// MARK: MultipartFormData

public func upload(
    multipartFormData: @escaping (MultipartFormData) -> Void,
    usingThreshold encodingMemoryThreshold: UInt64 = SessionManager.multipartFormDataEncodingMemoryThreshold,
    to url: URLConvertible,
    method: HTTPMethod = .post,
    headers: HTTPHeaders? = nil,
    encodingCompletion: ((SessionManager.MultipartFormDataEncodingResult) -> Void)?)
{
    return SessionManager.default.upload(
        multipartFormData: multipartFormData,
        usingThreshold: encodingMemoryThreshold,
        to: url,
        method: method,
        headers: headers,
        encodingCompletion: encodingCompletion
    )
}

public func upload(
    multipartFormData: @escaping (MultipartFormData) -> Void,
    usingThreshold encodingMemoryThreshold: UInt64 = SessionManager.multipartFormDataEncodingMemoryThreshold,
    with urlRequest: URLRequestConvertible,
    encodingCompletion: ((SessionManager.MultipartFormDataEncodingResult) -> Void)?)
{
    return SessionManager.default.upload(
        multipartFormData: multipartFormData,
        usingThreshold: encodingMemoryThreshold,
        with: urlRequest,
        encodingCompletion: encodingCompletion
    )
}

#if !os(watchOS)

// MARK: - Stream Request

// MARK: Hostname and Port

@discardableResult
@available(iOS 9.0, macOS 10.11, tvOS 9.0, *)
public func stream(withHostName hostName: String, port: Int) -> StreamRequest {
    return SessionManager.default.stream(withHostName: hostName, port: port)
}

// MARK: NetService

@discardableResult
@available(iOS 9.0, macOS 10.11, tvOS 9.0, *)
public func stream(with netService: NetService) -> StreamRequest {
    return SessionManager.default.stream(with: netService)
}

#endif
