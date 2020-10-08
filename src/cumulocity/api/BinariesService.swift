//
//  BinariesService.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 22/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation
import Combine

let C8Y_BINARIES_API = "inventory/binaries"

/**
 Allows binary attachments to be uploaded/downloaded to c8y for `C8yManagedObject`
 
Refer to the [c8y API documentation](https://cumulocity.com/guides/reference/binaries/) for more information
 */
public class C8yBinariesService: JcConnectionRequest<C8yCumulocityConnection> {
    
    /**
     Fetch file contents using Cumulocity internal id of the file
     
     - parameter id internal id of the stored file
	 - returns Publisher that will return response containing binary response
     */
    public func get(_ id: String) -> AnyPublisher<JcMultiPartRequestResponse, APIError> {

        return super._getMultipart(resourcePath: args(id)).map({ response in
            
            let disposition: String = response.httpHeaders![JC_HEADER_CONTENT_DISPOSITION] as! String

            let name = String(disposition[disposition.index(disposition.firstIndex(of: "\"")!, offsetBy: 1)..<disposition.index(disposition.endIndex, offsetBy: -2)])

            var content = JcMultiPartContent()
            content.add(name, contentType: response.content?.parts[0].contentType, content: (response.content?.parts[0].content)!)
            
            return JcMultiPartRequestResponse(response, updatedContent: content)
        }).eraseToAnyPublisher()
    }
    
    /**
     Sends the file to Cumulocity to be stored
     
     - parameter name label of the file to be shown in Cumulocity -> Administration --> Management -> File Repository
     - parameter contentType content type representing the type of data to be stored
     - parameter content ByteArray representing rawe data to be stored
	 - response Publisher to issue succes/failure of upload
     */
    func post(name: String, contentType: String, content: Data) -> AnyPublisher<JcMultiPartRequestResponse, APIError> {
        
        return super._execute(method: JcConnectionRequest.Method.POST, resourcePath: C8Y_BINARIES_API, request: makeRequest(name, contentType: contentType, data: content)).map( {response in
            
            var wrappedContent = JcMultiPartContent()

            let location: String = response.httpHeaders![JC_HEADER_LOCATION] as! String
            let id = String(location[location.index(location.lastIndex(of: "/")!, offsetBy: 1)...])

            wrappedContent.add(withId: id, name: name, contentType: contentType, content: content)
                
            return JcMultiPartRequestResponse(response, updatedContent: wrappedContent)
        }).eraseToAnyPublisher()
    }
    
    private func makeRequest(_ name: String, contentType: String, data: Data) -> JcMultiPartContent {
                
        var mp = JcMultiPartContent()
        mp.add("object", contentType: nil, content: Data("{\"name\": \"\(name)\", \"type\":\"\(contentType)\"}".utf8))
        mp.add("filesize", contentType: nil, content: Data("\(data.count)".utf8))
        mp.add("file", contentType: contentType, content: data)
        
        return mp
    }
    
    private func args(_ id: String) -> String {
        
        return String(format: "%@/%@", C8Y_BINARIES_API, id)
    }
}
