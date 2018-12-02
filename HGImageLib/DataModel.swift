//
//  DataModel.swift
//  HGImageLib
//
//  Created by Haresh on 03/12/18.
//  Copyright © 2018 Haresh. All rights reserved.
//

import Foundation

public struct DataModel {
    
    public let imageURLString: String
    
    public init(imageURLString: String) {
        self.imageURLString = imageURLString
    }
    
    public func getURL() -> URL {
        return URL(string: self.imageURLString)!
    }
    
}
