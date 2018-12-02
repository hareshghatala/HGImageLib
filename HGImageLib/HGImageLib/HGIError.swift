//
//  HGIError.swift
//  HGImageLib
//
//  Created by Haresh on 02/12/18.
//  Copyright © 2018 Haresh. All rights reserved.
//

import Foundation

public enum HGIError: Error {
    case requestCancelled
    case imageSerializationFailed
}

// MARK: - Error Booleans

extension HGIError {
    
    /// Returns `true` if the `HGIError` is a request cancellation error, `false` otherwise.
    public var isRequestCancelledError: Bool {
        if case .requestCancelled = self { return true }
        return false
    }
    
    /// Returns `true` if the `HGIError` is an image serialization error, `false` otherwise.
    public var isImageSerializationFailedError: Bool {
        if case .imageSerializationFailed = self { return true }
        return false
    }
    
}

// MARK: - Error Descriptions

extension HGIError: LocalizedError {
    
    public var errorDescription: String? {
        switch self {
        case .requestCancelled:
            return "The request was explicitly cancelled."
        case .imageSerializationFailed:
            return "Response data could not be serialized into an image."
        }
    }
    
}
