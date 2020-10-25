//
//  EditableGroup.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 09/05/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation
import Combine

/**
Use this class directly from a SwiftUI Form View to allow the wrapped group to be edited.

Changes to fields are published to the attribute `onChange` and can be acted on in your View with the following code.
Duplicates are removed and changes are debounced into 1 event every 3 seconds, this means you could automatically
persist changes to Cumulocity via the method `C8yAssetCollection.saveObject(_)` without having it called
on each key press made by the user.

```
VStack {
	...
}.onReceive(self.editableGroup.onChange) { editableGroup in
	
	do {
		try self.assetCollection.saveObject(editableGroup.toGroup()) { success, error in
	
		}
	} catch {
		print("error \(error.localizedDescription)")
	}
}
```
*/
public class C8yEditableGroup: ObservableObject {
    
    public static let GROUP_ID_TYPE = "assetId"

    @Published public var c8yId: String = ""
    
	@Published public var externalId: String = "" {
		willSet(o) {
			if self.externalId != o {
				self.haveChanges = true
			}
		}
	}
    
    @Published public var name: String = "" {
		willSet(o) {
			if self.name != o {
				self.emitDidChange(o)
			}
		}
	}
	
    @Published public var category: C8yGroupCategory = .group {
		willSet(o) {
			if self.category != o {
				self.emitDidChange(o.rawValue)
			}
		}
	}
    
	@Published public var orgName: String = "" {
		willSet(o) {
			if self.orgName != o {
				self.emitDidChange(o)
			}
		}
	}
	
    @Published public var contactPerson: String = "" {
		willSet(o) {
			if self.contactPerson != o {
				self.emitDidChange(o)
			}
		}
	}
	
    @Published public var contactEmail: String = "" {
		willSet(o) {
			if self.contactEmail != o {
				self.emitDidChange(o)
			}
		}
	}
	
    @Published public var contactPhone: String = "" {
		willSet(o) {
			if self.contactPhone != o {
				self.emitDidChange(o)
			}
		}
	}
    
    @Published public var addressLine1: String = "" {
		willSet(o) {
			if self.addressLine1 != o {
				self.emitDidChange(o)
			}
		}
	}
	
    @Published public var addressLine2: String = "" {
		willSet(o) {
			if self.addressLine2 != o {
				self.emitDidChange(o)
			}
		}
	}
	
    @Published public var city: String = "" {
		willSet(o) {
			if self.city != o {
				self.emitDidChange(o)
			}
		}
	}
	
    @Published public var postCode: String = "" {
		willSet(o) {
			if self.postCode != o {
				self.emitDidChange(o)
			}
		}
	}
	
    @Published public var country: String = "" {
		willSet(o) {
			if self.country != o {
				self.emitDidChange(o)
			}
		}
	}

    @Published public var notes: String = "" {
		willSet(o) {
			if self.notes != o {
				self.emitDidChange(o)
			}
		}
	}
    
    @Published public var lat: Double = 0.0 {
		willSet(o) {
			if self.lat != o {
				self.emitDidChange("\(o)")
			}
		}
	}
	
    @Published public var lng: Double = 0.0 {
		willSet(o) {
			if self.lng != o {
				self.emitDidChange("\(o)")
			}
		}
	}
	
    @Published public var alt: Double = 0.0 {
		willSet(o) {
			if self.alt != o {
				self.emitDidChange("\(o)")
			}
		}
	}

    public var isNew: Bool {
        get {
            return c8yId.isEmpty
        }
    }
    
	/**
	true if changes have been made to any of the attributes, you will need to set it back to false explicitly once changed
	e.g. after saving changes via the `onChange` publisher
	*/
	public var haveChanges: Bool = false
	
    public var readyToDeploy: Bool {
        get {
            return !name.isEmpty && category != .unknown
        }
    }
	
	/**
	Use this publisher to listen for changes to any of device attribute, removes duplicates and debounces to minimise events to maximum 1 every 3 seconds
	*/
	public var onChange: AnyPublisher<C8yEditableGroup, Never> {
		return self.didChange
		.drop(while: { v in
			return !self.haveChanges
		 })
		.debounce(for: .milliseconds(3000), scheduler: RunLoop.main)
		.removeDuplicates()
		.map { input in
			return self
		}.eraseToAnyPublisher()
	}
	
	private let didChange = CurrentValueSubject<String, Never>("")
    private var _ignoreChanges: Bool = false
    private var cancellableSet: Set<AnyCancellable> = []

    public init() {
    
    }
    
	/**
	Constructor to allow an existing device to be edited.
	*/
    public convenience init(withGroup group: C8yGroup) {

        self.init()
        
        self._mergeWithGroup(group)
    }
    
    deinit {
        for c in self.cancellableSet {
            c.cancel()
        }
    }
    
	/**
	Clears all of the editable fields without triggering change event publishers
	*/
    public func clear() {
    
        self._ignoreChanges = true
        
        self.c8yId = ""
        self.externalId = ""
		self.orgName = ""
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
    
	/**
	Returns a `C8yGroup` instance with all of the edited fields included
	*/
	public func toGroup(_ parentGroupName: String? = nil) -> C8yGroup {
           
		var group = C8yGroup(self.c8yId, name: self.name, category: self.category, parentGroupName: parentGroupName, notes: notes.isEmpty ? nil : notes)
           
		group.info = C8yGroup.Info(orgName: self.orgName, subName: nil, address: nil, contact: nil, planning: nil)
		
        if (self.lat != 0 && self.lng != 0) {
            group.position = C8yManagedObject.Position(lat: self.lat, lng: self.lng, alt: self.alt)
        }
           
        if (!self.externalId.isEmpty) {
            group.setExternalIds([C8yExternalId(withExternalId: self.externalId, ofType: Self.GROUP_ID_TYPE)])
        }
        
		if (!self.addressLine1.isEmpty) {
			group.info.address = C8yAddress(addressLine1: self.addressLine1, city: self.city, postCode: self.postCode, country: self.country, phone: self.contactPhone)
		}
        group.info.siteOwner = C8yContactInfo(self.contactPerson, phone: self.contactPhone, email: self.contactEmail)
           
        return group
    }
	
	public func toGroup(_ originalGroup: C8yGroup) -> C8yGroup {
		   
		var group = originalGroup
			
		group.name = self.name
		group.notes = self.notes
		group.groupCategory = self.category
		//group.orgCategory = self.orgCategory
		
		group.info = C8yGroup.Info(orgName: self.orgName, subName: nil, address: nil, contact: nil, planning: nil)
		
		if (self.lat != 0 && self.lng != 0) {
			group.position = C8yManagedObject.Position(lat: self.lat, lng: self.lng, alt: self.alt)
		}
		   
		if (!self.externalId.isEmpty) {
			group.setExternalIds([C8yExternalId(withExternalId: self.externalId, ofType: Self.GROUP_ID_TYPE)])
		}
		
		if (!self.addressLine1.isEmpty) {
			group.info.address = C8yAddress(addressLine1: self.addressLine1, city: self.city, postCode: self.postCode, country: self.country, phone: self.contactPhone)
		}
		group.info.siteOwner = C8yContactInfo(self.contactPerson, phone: self.contactPhone, email: self.contactEmail)
		   
		return group
	}
    
    private func _mergeWithGroup(_ group: C8yGroup) {
    
		self._ignoreChanges = true
		
        if (group.c8yId != nil) {
            self.c8yId = group.c8yId!
        }
        
        if (group.name != group.type) {
            self.name = group.name
        }
        
        self.category = group.groupCategory
        
		if (group.info.orgName != "undefined") {
			self.orgName = group.info.orgName
		}
		
        if (group.info.address != nil) {
			
			self.addressLine1 = group.info.address!.addressLine1 ?? ""
			
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
		
		if (group.notes != nil) {
			self.notes = group.notes!
		}
		
		self.haveChanges = false
		self._ignoreChanges = false
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
	
	private func emitDidChange(_ v: String) {
		if (!self._ignoreChanges) {
			self.haveChanges = true
			self.didChange.send(v)
		}
	}
}
