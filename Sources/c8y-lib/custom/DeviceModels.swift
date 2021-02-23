//
//  DeviceModels.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 02/05/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation
import Combine
import UIKit

public let C8Y_SUPPLIERS = "device_Supplier"

public protocol C8yOperationTemplateDelegate {
	func template(for operationType: String) -> C8yOperation.OperationTemplate
}
	
public class C8yDeviceModels: ObservableObject {

	public var operationTemplateDelegate: C8yOperationTemplateDelegate? = nil
	
    private var _conn: C8yCumulocityConnection?
    
    @Published public var suppliers: [C8ySupplier] = []
	@Published public var models: [String:[String:C8yModel]] = [:]
        
    private var cancellableSet: Set<AnyCancellable> = []

    private var _didLoad: Bool = false
    	
	public init(_ templates: C8yOperationTemplateDelegate? = nil) {
		self._conn = nil
		self.operationTemplateDelegate = templates
		self.suppliers.append(C8ySupplier(name: "generic", description: "", site: nil))
    }

	public func load(_ conn: C8yCumulocityConnection) {
        
		self._conn = conn
		
        if (!_didLoad) {
            self.fetchSuppliers()
        }
    }

	public func supplierForId(id: String = "generic") -> C8ySupplier? {

		var found: C8ySupplier? = nil

		for s in suppliers {

			if (s.name.lowercased() == id) {
				found = s
				break
			}
		}

		return found
	}

    public func supplierForModel(id: String) -> C8ySupplier? {

        var found: C8ySupplier? = nil
        var keys = self.models.keys.makeIterator()

        var key: String? = keys.next()
        
        while (key != nil && found == nil) {
            
            let smodels = models[key!]

            if (smodels != nil) {
                for m in smodels! {
					if (id.lowercased().contains(m.key.lowercased())) {
                        found = supplierForId(id: key!)
                        break
                    }
                }
            }
            
            key = keys.next()
        }

        return found
    }

	public func modelFor(device: C8yDevice) -> AnyPublisher<C8yModel, Never> {

		var id = device.revision ?? device.model
		let s = device.supplier.isEmpty || device.supplier == "generic" ? self.supplierForModel(id: id)?.name ?? "generic" : device.supplier
		
		if (id.isNumber && !device.model.isEmpty) {
			id = device.model
		}
		
		return modelFor(id: id, andSupplier: s)
	}
	
	public func modelFor(id: String, andSupplier s: String) -> AnyPublisher<C8yModel, Never> {
		
		if (self.models[s] == nil || self.models[s]![id.lowercased()] == nil) {
			
			if (self._conn != nil) {
				return self.fetchModel(id: id, forSupplier: s).map( { response -> C8yModel in
					
					var r = response ?? C8yModel()
					
					if (self.models[s] == nil) {
						self.models[s] = [id.lowercased():r]
					} else {
						self.models[s]![id.lowercased()] = r
					}
					
					r._operationTemplateDelegate = self.operationTemplateDelegate
					
					return r
				}).eraseToAnyPublisher()
			} else {
				return Just(C8yModel(self.operationTemplateDelegate)).eraseToAnyPublisher()
			}
		} else {
			return Just(self.models[s]![id.lowercased()]!).eraseToAnyPublisher()
		}
    }

	private func fetchSuppliers() {
        
        C8yManagedObjectsService(self._conn!).get(forType: C8Y_SUPPLIERS, pageNum: 0).sink(receiveCompletion: { (completion) in
            switch completion {
            case .failure:
                //TODO: report
				break
            case .finished:
                break
            }
        }, receiveValue: { (response) in
            self._didLoad = true

            DispatchQueue.main.sync {
                for object in response.content!.objects {
					self.suppliers.append(C8ySupplier(object))
                }
            }
		}).store(in: &cancellableSet)
    }

	private func fetchModel(id: String, forSupplier supplier: String?) -> AnyPublisher<C8yModel?, Never> {

        var query = C8yManagedObjectQuery()
		
		if (supplier != nil) {
			query.add(key: "supplier", op: C8yManagedObjectQuery.Operator.eq, value: supplier!)
		}
		
		query.add(key: "model.id", op: C8yManagedObjectQuery.Operator.eq, value: id)

		return C8yManagedObjectsService(self._conn!).get(forQuery: query, pageNum: 0).map{response -> C8yModel in
			
			if (response.content?.objects.count ?? 0 > 0) {
				return C8yModel(response.content!.objects[0])
			} else {
				return C8yModel()
			}
		}.catch { error -> AnyPublisher<C8yModel?, Never> in
			// do nothing
			return Just(nil).eraseToAnyPublisher()
		}.eraseToAnyPublisher()
    }
}
