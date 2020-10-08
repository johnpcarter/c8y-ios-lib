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

/**
 Convenience class to allow multi-part formatted data to be sent/received via http/s
 
 # Example: (get)#
 ```
 return super._getMultipart(resourcePath: args(id)) { (response) in
     
    if (response.status == .SUCCESS) {
        
        for part in response.content!.parts {
            var name = part.name
            var filename = part.fileName
            var contentType = part.contentType
 
            var data = part.content
        }
    }
 }
 ```
 
 # Example: (post)#
 ```
 var mp = JcMultiPartContent()
 mp.add("object", contentType: nil, content: Data("{\"name\": \"\(name)\", \"type\":\"\(contentType)\"}".utf8))
 mp.add("filesize", contentType: nil, content: Data("\(data.count)".utf8))
 mp.add("file", contentType: contentType, content: data)
 
 return super._execute(method: JcConnectionRequest.Method.POST, resourcePath: C8Y_BINARIES_API, request: mp) { (response) in

    if (response.status == .SUCCESS) {
        ...
    }
 }
 ```
 */
public struct JcMultiPartContent {
 
    /**
     The content parts to be sent or have been received
     */
    public private(set) var parts: [ContentPart]
    
    /**
     Defines the content part
     */
    public struct ContentPart: Encodable {
        
        public let id: String?
        public let name: String
        public let fileName: String?
        public let contentType: String?
        public let content: Data
        
        init(withId: String, name: String, contentType: String?, content: Data) {

            self.id = withId
            self.name = name
            self.fileName = nil
            self.contentType = contentType
            self.content = content
        }
        
        init(_ name: String, contentType: String?, content: Data) {
            self.id = nil
            self.name = name
            self.fileName = nil
            self.contentType = contentType
            self.content = content
        }
    }
    
    /**
     Create a new multipart instance, use one of the `add()` functions to add content parts
     */
    public init() {
        
        self.parts = []
    }
    
    init (_ headers: [AnyHashable : Any], data: Data) {

    // get

        let disposition: String = headers[JC_HEADER_CONTENT_DISPOSITION] as! String
        let contentType: String = headers["Content-Type"] as! String
        
        self.parts = []
        parts.append(ContentPart(disposition, contentType: contentType, content: data))
    }
    
    /**
     Adds a content part for the givent data
     
     - parameter name: name of the content part
     - parameter contentType: Defines the type of data e.g. 'applicaton/jpeg' etc.
     - parameter content: data to be included
     */
    public mutating func add(_ name: String, contentType: String?, content: Data) {
    
        self.parts.append(ContentPart(name, contentType: contentType, content: content))
    }
    
    /**
    Adds a content part for the givent data including a unique id
     
    - parameter id: Unique id to be included
    - parameter name: name of the content part
    - parameter contentType: Defines the type of data e.g. 'applicaton/jpeg' etc.
    - parameter content: data to be included
    */

    public mutating func add(withId: String, name: String, contentType: String?, content: Data) {
       
        self.parts.append(ContentPart(withId: withId, name: name, contentType: contentType, content: content))
    }
    
    /**
     Generates raw multipart output that can then be used as a request to a `URLSession` call
     # Attention: #
     You will need to set the content type to include the multipart  boundary type If not using the `ConnectionRequest` class.
     Namely #multipart/form-data; boundary=fileBoundary#
     */
    public func build() -> Data {
        
        var out: Data = Data()
        var marker: Data = Data(JC_MULTIPART_BOUNDARY.utf8)
        let newLine = "\r\n".utf8
        marker.append(contentsOf: newLine)
        
        for (part) in self.parts {
        
            out.append(marker)
            
            if (part.fileName != nil) {
                out.append(contentsOf: String(format:"Content-Disposition: form-data; name=%@; filename=\"%@\"", part.name, part.fileName!).utf8)
            } else {
                out.append(contentsOf: String(format:"Content-Disposition: form-data; name=\"%@\"", part.name).utf8)
            }
            
            out.append(contentsOf: newLine)
            
            if (part.contentType != nil) {
                out.append(contentsOf: "Content-Type: \(part.contentType!)".utf8)
                out.append(contentsOf: newLine)
            }
            
            out.append(contentsOf: newLine)

            out.append(part.content)
            out.append(contentsOf: newLine)
        }
        
        out.append(contentsOf: "\(JC_MULTIPART_BOUNDARY)--".utf8)
        out.append(contentsOf: newLine)
        
        return out
    }
}

/**
  Wrapper for a request to fetch multipart data
 */
public struct JcMultiPartRequestResponse {

    /**
     http response status, content will only be valid if code is
     200...201
     */
	public let httpStatus: Int
    
    /**
     Optional http headers that are to be sent or were received
     */
	public let httpHeaders: [AnyHashable: Any]?
    
    /**
     Optional http response message returned from server, generally only provided in case of error
     */
	public let httpMessage: String?
    
    /**
     Multipart content, might be nil if this is a response and the `httpStatus` is not 200...201
     */
    public let content: JcMultiPartContent?
    
    /**
    Flags .SUCCESS or failure of request.
    
    Two types of failure are possible;
    
    # SERVER_SIDE_FAILURE #
    Error was server side, refer to `httpStatus` & `httpMessage`.
    
    # CLIENT_SIDE_FAILURE #
    The failure was triggered on our side when trying to translate the response into something useful, refer instead to `error`
    
    # Notes: #
    Connection failures will not be reported here, as they are triggered immediately when making calls
    */
	public var status: JCResponseStatus {
        get {
            if (httpStatus >= 200 && httpStatus <= 300) {
                if (content != nil) {
                    return JCResponseStatus.SUCCESS
                } else {
                    return JCResponseStatus.CLIENT_SIDE_FAILURE
                }
            } else {
                return JCResponseStatus.SERVER_SIDE_FAILURE
            }
        }
    }
    
    init(_ original: JcRequestResponse<Data>, updatedContent: JcMultiPartContent) {
        
        self.httpStatus = original.httpStatus
        self.httpHeaders = original.httpHeaders
        self.httpMessage = original.httpMessage
        self.content = updatedContent
    }
    
    init(_ original: JcMultiPartRequestResponse, updatedContent: JcMultiPartContent) {
        
        self.httpStatus = original.httpStatus
        self.httpHeaders = original.httpHeaders
        self.httpMessage = original.httpMessage
        self.content = updatedContent
    }
    
    init(_ original: JcRequestResponse<Data>) {
        
        self.httpStatus = original.httpStatus
        self.httpHeaders = original.httpHeaders
        self.httpMessage = original.httpMessage
        
        if (original.httpStatus >= 200 && original.httpStatus <= 201 && original.content != nil) {
            self.content = JcMultiPartContent(self.httpHeaders!, data: original.content!)
        } else {
            self.content = nil
        }
    }
}
