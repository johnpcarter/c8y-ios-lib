//
//  EditableGroup.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 09/05/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation
import Combine

public class C8yEditableGroup: ObservableObject {
    
    public static let GROUP_ID_TYPE = "assetId"

    @Published public var c8yId: String = ""
    
    @Published public var externalId: String = ""
    
    @Published public var name: String = ""
    @Published public var category: C8yGroupCategory = .group
    
    @Published public var contactPerson: String = ""
    @Published public var contactEmail: String = ""
    @Published public var contactPhone: String = ""
    
    @Published public var addressLine1: String = ""
    @Published public var addressLine2: String = ""
    @Published public var city: String = ""
    @Published public var postCode: String = ""
    @Published public var country: String = ""

    @Published public var notes: String = ""
    
    @Published public var lat: Double = 0.0
    @Published public var lng: Double = 0.0
    @Published public var alt: Double = 0.0

    public var isNew: Bool {
        get {
            return c8yId.isEmpty
        }
    }
    
    public var readyToDeploy: Bool {
        get {
            return !name.isEmpty && category != .unknown
        }
    }
        
    private var haveUnsavedChanged: Bool = false
    private var _ignoreChanges: Bool = false
    
    private var cancellableSet: Set<AnyCancellable> = []

    public init() {
    
    }
    
    public convenience init(withGroup group: C8yGroup) {

        self.init()
        
        self._mergeWithGroup(group)
    }
    
    deinit {
        for c in self.cancellableSet {
            c.cancel()
        }
    }
    
    public func clear() {
    
        self._ignoreChanges = true
        
        self.c8yId = ""
        self.externalId = ""
        self.contactEmail = ""
        self.contactPhone = ""
        self.addressLine1 = ""
        self.addressLine2 = ""
        self.city = ""
        self.country = ""
        self.lat = 0.0
        self.lng = 0.0
        self.alt = 0.01234567
        
        self._ignoreChanges = false
    }
    
    public func toGroup(_ location: String?) -> C8yGroup {
           
        var group = C8yGroup(self.c8yId, name: self.name, category: self.category, location: location, notes: notes.isEmpty ? nil : notes)
           
        if (self.lat != 0 && self.lng != 0) {
            group.position = C8yManagedObject.Position(lat: self.lat, lng: self.lng, alt: self.alt)
        }
           
        if (!self.externalId.isEmpty) {
            group.setExternalIds([C8yExternalId(withExternalId: self.externalId, ofType: Self.GROUP_ID_TYPE)])
        }
        
        group.info.address = C8yAddress(addressLine1: self.addressLine1, city: self.city, postCode: self.postCode, country: self.country, phone: self.contactPhone)
        group.info.siteOwner = C8yContactInfo(self.contactPerson, phone: self.contactPhone, email: self.contactEmail)
           
        return group
    }
    
    private func _mergeWithGroup(_ group: C8yGroup) {
    
        if (group.c8yId != "_new_") {
            self.c8yId = group.c8yId
        }
        
        if (group.name != group.type) {
            self.name = group.name
        }
        
        self.category = group.groupCategory
        
        if (group.info.address != nil) {
            self.addressLine1 = group.info.address!.addressLine1!
            //self.addressLine2 = group.info.address!.addressLine1
            self.city = group.info.address!.city ?? ""
            self.postCode = group.info.address!.postCode ?? ""
            self.country = group.info.address!.country ?? ""

        }
        
        if (group.info.siteOwner != nil) {
            self.contactPerson = group.info.siteOwner!.contact ?? ""
            self.contactEmail = group.info.siteOwner!.contactEmail ?? ""
            self.contactPhone = group.info.siteOwner!.contactPhone ?? ""
        }
    }
    
    func makeError<T>(_ response: JcRequestResponse<T>) -> Error? {

        if (response.status != .SUCCESS) {
            if (response.httpMessage != nil) {
                return DeviceUpdateError.reason(response.httpMessage)
            } else if (response.error != nil){
                return DeviceUpdateError.reason(response.error?.localizedDescription)
            } else {
                return DeviceUpdateError.reason("undocumented")
            }
        } else {
            return nil
        }
    }

    enum DeviceUpdateError: Error {
        case reason (String?)
    }
}
