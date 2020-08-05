//
//  DeviceModels.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 02/05/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation
import Combine

public class C8yDeviceModelsReference: ObservableObject {

    private var _conn: C8yCumulocityConnection?
    
    @Published public private(set) var suppliers: [C8ySupplier] = []
    @Published public private(set) var models: [String:[C8yModel]] = [:]
    
    private var _model: SupplierModelsSummary? = nil
    
    private var cancellableSet: Set<AnyCancellable> = []

    private var _didLoad: Bool = false
    
    public init() {
        _conn = nil
        self.suppliers.append(C8ySupplier("generic", name: "Generic", networkType: nil, site: nil))
        self.setupBuiltInModelReferences()
    }
    
    public convenience init(_ conn: C8yCumulocityConnection) {
        
        self.init()
        
        self.load(conn)
    }

    public func load(_ conn: C8yCumulocityConnection) {
        _conn = conn
        
        if (!_didLoad) {
            self.fetchSuppliers()
        }
    }
    
    public func fetchModelsForSupplier(supplierId: String, modelId: String) -> C8yModel? {

        let smodels = models[supplierId]
        var model: C8yModel? = nil

        if (smodels != nil) {
            for m in smodels! {

                if (m.id == modelId) {
                    model = m
                    break
                }
            }
        }

        return model
    }

    public func supplierForModel(id: String) -> C8ySupplier? {

        var found: C8ySupplier? = nil
        var keys = self.models.keys.makeIterator()

        var key: String? = keys.next()
        
        while (key != nil && found == nil) {
            
            let smodels = models[key!]

            if (smodels != nil) {
                for m in smodels! {
                    if (id.lowercased().contains(m.id.lowercased())) {
                        found = supplierForId(id: key!)
                        break
                    }
                }
            }
            
            key = keys.next()
        }

        return found
    }

    public func modelForId(id: String) -> C8yModel? {

        var found: C8yModel? = nil
        var keys = self.models.keys.makeIterator()

        var key: String? = keys.next()
        while (key != nil && found == nil) {
        
            let smodels = self.models[key!]

            if (smodels != nil) {
            
                for m in smodels! {
                
                    if (id.lowercased().contains(m.id.lowercased())) {
                        found = m
                        break
                    }
                }
            }
            
            key = keys.next()
        }

        return found
    }

    public func supplierForId(id: String) -> C8ySupplier? {

        var found: C8ySupplier? = nil

        for s in suppliers {

            if (s.id == id) {
                found = s
                break
            }
        }

        return found
    }

    public func fetchSuppliers() {
        
        C8yManagedObjectsService(self._conn!).get(forType: "suppliers", pageNum: 0).sink(receiveCompletion: { (completion) in
            switch completion {
            case .failure(let error):
                print(error)
            case .finished:
                print("done")
            }
        }, receiveValue: { (response) in
            self._didLoad = true

            DispatchQueue.main.sync {
                for object in response.content!.objects {
                    self.suppliers.append(contentsOf: (object.properties[JC_MANAGED_OBJECT_SUPPLIER] as! C8ySuppliers).suppliers)
                }
            }
            
            for s in self.suppliers {
                self.fetchModelsForSupplier(id: s.id)
            }
            }).store(in: &cancellableSet)
    }

    public func fetchModelsForSupplier(id: String) {

        var query = C8yManagedObjectQuery()
        _ = query.add(key: "type", op: C8yManagedObjectQuery.Operator.eq, value: "models")
        _ = query.add(key: "xSupplier", op: C8yManagedObjectQuery.Operator.eq, value: id)

        _ = C8yManagedObjectsService(self._conn!).get(forQuery: query, pageNum: 0).sink(receiveCompletion: { (completion) in
            print("done")
        }, receiveValue: { (response) in
            if (response.content != nil && response.content!.objects.count > 0) {
                
                DispatchQueue.main.sync {
                    
                    self.models[id] = (response.content!.objects[0].properties[JC_MANAGED_OBJECT_MODEL] as! C8yModels).models
                }
            }
        }).store(in: &cancellableSet)
    }
    
    func setupBuiltInModelReferences() {

        let apple = C8ySupplier("apple", name: "Apple", networkType: "", site: "https://www.apple.com")
        let rasp = C8ySupplier("rasp-foundation", name: "Raspberry Pi Foundation", networkType: "credentials", site: "https://www.raspberrypi.org")
        let tado = C8ySupplier("tado", name: "Tado", networkType: "oauth", site: "https://www.tado.com")
        let philips = C8ySupplier("philips-hue", name: "Philips Hue", networkType: "oauth", site: "https://www2.meethue.com/")

        suppliers.append(apple)
        suppliers.append(rasp)
        suppliers.append(tado)
        suppliers.append(philips)

        models["apple"] = [C8yModel("iPhone", name: "iPhone", category: .Phone, link: "https://www.apple.fr/iphone")]
        
        models["rasp-foundation"] = [C8yModel("Rasp Pi BCM2035", name: "Rasp Pi Desktop Computer", category: .Computer, link: "https://projects.raspberrypi.org/en/projects/raspberry-pi-setting-up"),
                                      C8yModel("Rasp Pi BCM2012", name: "Compute Module 3+", category: .Computer, link: "https://www.raspberrypi.org/documentation/hardware/computemodule/datasheets/rpi_DATA_CM3plus_1p0.pd")]
       
        models["tado"] = [C8yModel("Smart Thermostat", name: "Smart Thermostat", category: .Thermostat, link: "https://www.tado.com/fr/produits/thermostat-intelligent-kit-demarrage"),
                           C8yModel("Extension Kit", name: "Extension Kit", category: .Router, link: "https://www.tado.com/fr/produits/kit-extension"),
                           C8yModel("Smart Radiator Thermostat", name: "Smart Radiator Thermostat", category: .Thermostat, link: "https://www.tado.com/fr/produits/valve-thermostatique-intelligente")]
        
        models["philips-hue"] = [C8yModel("E261", name: "Color Starter kit E26", category: .Light, link: "https://www2.meethue.com/en-us/p/hue-white-and-color-ambiance-starter-kit-e26/046677548544"),
                                 C8yModel("E262", name: "White Starter Kit", category: .Light, link: "https://www2.meethue.com/en-us/p/hue-white-starter-kit-e26/046677530334"),
                                  C8yModel("PH002", name: "Hue Hub Bridge", category: .Router, link: "https://www2.meethue.com/en-us/p/hue-bridge/046677458478"),
                                  C8yModel("PH003", name: "Hue Smart Button", category: .Light, link: "https://www2.meethue.com/en-us/p/hue-smart-button/046677553715")]
    }
    
    public class SupplierModelsSummary: ObservableObject {
           
        private var _wrappedDevice: C8yEditableDevice
        private var _ref: C8yDeviceModelsReference?
        
        private var _ignore: Bool = false
        
        @Published public var selectedSupplier: String = "" {
            didSet {
                
                if (_ignore) {
                    return
                }
                
                if (oldValue != selectedSupplier) {
                    selectedModel = ""
                    _wrappedDevice.category = .Unknown
                }
                
                _wrappedDevice.supplier = selectedSupplier
                _wrappedDevice.model = selectedModel
            }
        }
        
        @Published public var selectedModel: String = "" {
            didSet {
                
                if (_ignore) {
                    return
                }
                
                if (!selectedModel.isEmpty) {
                    let model: C8yModel? = _lookupModel(forId: selectedModel, andSupplierId: selectedSupplier)
                    
                    if (model != nil && model!.category != .Unknown) {
                        _wrappedDevice.category = model!.category
                    }
                    
                    if (model != nil && model!.link != nil) {
                        _wrappedDevice.webLink = model!.link!
                    }
                }
                
                _ignore = true
                _wrappedDevice.model = selectedModel
                _ignore = false
            }
        }
        
        public func models(_ model: C8yDeviceModelsReference) -> [C8yModel] {
           
            _ref = model // keep copy for reference below
            
            if (!self.selectedSupplier.isEmpty) {

                let modelsForSupplier = model.models[self.selectedSupplier]
                
                if (modelsForSupplier != nil) {
                    return modelsForSupplier!
                } else if self.selectedModel.count > 0 {
                    return [C8yModel(self.selectedModel, name: self.selectedModel, category: .Unknown, link: nil)]
                } else {
                    return []
                }
            } else {
                return []
            }
        }
        
        public init(updatableDevice: C8yEditableDevice) {
            
            self._wrappedDevice = updatableDevice
            self.refresh()
        }
        
        public func refresh() {
            
            let m = self._wrappedDevice.model
            let c = self._wrappedDevice.category
           
            self.selectedSupplier = self._wrappedDevice.supplier
            self.selectedModel = m
            self._wrappedDevice.category = c
        }
        
        private func _lookupModel(forId id: String, andSupplierId supplierId: String) -> C8yModel? {
            
            if (_ref == nil) {
                return nil
            }
            
            let smodels: [C8yModel]? = _ref!.models[supplierId]
            
            if (smodels != nil) {
                
                var found: C8yModel? = nil
                
                for m in smodels! {
                    if (m.id == id) {
                        found = m
                        break
                    }
                }
                
                return found
            } else {
                return nil
            }
        }
    }
}
