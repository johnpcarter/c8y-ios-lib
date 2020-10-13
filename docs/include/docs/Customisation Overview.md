# Customisation Overview #

Cumulocity is highly customisable and virtually all data models can be enriched with either simple or complex types.
This obviously creates a problem for a strongly typed language such as Swift, because all attributes have to be 
predefined. 

This is solved by ensuring that any unrecognised attributes found in an instance of `C8yManagedObject`, `C8yAlarm` 
or `C8yEvent` are included in a properties Dictionary attribute. Simple values are keyed by the same name they would 
have in Cumulocity. Complex fragments by default are flattened into strings with the complete path of the attribute included
in the key with each part separated by the dot '.' separator e.g.

```
"ManagedObject": {
	"id": "1019593",
    "c8y_Notes": "",
    "c8y_Availability": {
		"lastMessage": "2020-10-05T17:59:06.248Z",
		"status": "MAINTENANCE"
  	},
  	"c8y_RequiredAvailability": {
	  "responseInterval": -1
  	},
  	"c8y_Connection": {
	  "status": "MAINTENANCE"
  	},
  	"customAttribute1": "test",
	"customAttributeComplex": {
		"name": "fish"
	}
}

...

let c1 = managedObject.properties["customAttribute1"]
print("custom atribute is \(c1)")
==> custom attribute is test

let c2 = managedObject.properties["customAttributeComplex.name"]
print("custom atribute is \(c2)")
==> custom attribute is fish
``` 

# Providing Custom attribute classes #

Alternatively you can register your own custom model classes to reference complete structures via the properties attribute.
To override the default behaviour you will need to provide a class that implements the protocol `C8yCustomAsset`.

```
public struct CustomAttributeComplex: C8yCustomAsset {
	
	public var name: String = "dummy"
	
	mutating func decode(_ container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws -> Void /*{
		self.name = try container.decode(String.self, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: "name")
	}

	func encode(_ container: KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws -> 	KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey> {
	
		var updatedContainer = container
		try updatedContainer.encode(self.isDeployed, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: "name")!)
		
		return updatedContainer
	}
}
```

Then implement the protocol `C8yCustomAssetFactory` to allow instances of your custom class to be created as needed

```
class CustomAttributeComplexFactory: C8yCustomAssetFactory {
	
	override func make() -> C8yCustomAsset {
		return CustomAttributeComplex()
	}
	
	override func make(key: C8yCustomAssetProcessor.AssetObjectKey, container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>) throws -> C8yCustomAsset {
				
		return try container.decode(CustomAttributeComplex.self, forKey: key)
	}
}
```

Finally register your factory class so that it will be included when encoding and decoding `C8yManagedObject` objects.

```
C8yCustomAssetProcessor.registerCustomPropertyClass("customAttributeComplex", CustomAttributeComplexFactory())

```

The resulting object will be accessible as an item in the `C8yManagedObject` properties Dictionary e.g.

```
let customAtrib: CustomAttributeComplex = manageObject.properties["customAttributeComplex"] as! CustomAttributeComplex
print("Custom atribute is \(customAtrib.name)")
===> custom attribute is fish
```

