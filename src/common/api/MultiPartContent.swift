//
//  ContentPart.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 22/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

let JC_MULTIPART_BOUNDARY = "--fileBoundary"
let JC_MULTIPART_CONTENT_TYPE = "multipart/form-data; boundary=fileBoundary"

public struct JcMultiPartContent {
 
    public private(set) var parts: [ContentPart]
    
    public struct ContentPart: Encodable {
        
        public let name: String
        public let fileName: String?
        public let contentType: String?
        public let content: Data
        
        init(_ name: String, contentType: String?, content: Data) {
            self.name = name
            self.fileName = nil
            self.contentType = contentType
            self.content = content
        }
    }
    
    public init() {
        parts = []
    }
    
    public mutating func add(_ name: String, contentType: String?, content: Data) -> JcMultiPartContent {
    
        self.parts.append(ContentPart(name, contentType: contentType, content: content))
        
        return self;
    }
    
    public func build() -> Data {
        
        var out: Data = Data()
        var marker: Data = Data(JC_MULTIPART_BOUNDARY.utf8)
        let newLine = "\r\n".utf8
        marker.append(contentsOf: newLine)
        
        for (part) in self.parts {
        
            out.append(marker)
            
            if (part.fileName != nil) {
                out.append(contentsOf: String(format:"Content-Disposition: form-data; name=%@; filename=%@", part.name, part.fileName!).utf8)
            } else {
                out.append(contentsOf: String(format:"Content-Disposition: form-data; name=%@", part.name).utf8)
            }
            
            out.append(contentsOf: newLine)
            
            if (part.contentType != nil) {
                out.append(contentsOf: "Content-Type: \(part.contentType!)".utf8)
                out.append(contentsOf: newLine)
            }
            
            out.append(contentsOf: newLine)

            out.append(part.content)
        }
        
        out.append(contentsOf: "\(JC_MULTIPART_BOUNDARY)--".utf8)
        out.append(contentsOf: newLine)
        
        return out
    }
}
