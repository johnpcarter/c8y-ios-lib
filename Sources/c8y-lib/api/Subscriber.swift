//
//  Subscriber.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 29/01/2021.
//  Copyright © 2021 John Carter. All rights reserved.
//

import Foundation
import Combine

let C8Y_CLIENT_NOTIFICATION = "/cep/realtime"

public class C8ySubscriber: JcConnectionRequest<C8yCumulocityConnection> {
	
	private var _stopSubscriber: Bool = false
	private var _cancellable: [AnyCancellable] = []

	private var _clientId: ClientIdProperty = ClientIdProperty(lock: Mutex())
		
	deinit {
		for c in self._cancellable {
			c.cancel()
		}
	}
	
	/**
	
	*/
	public func connect<T:Decodable>(subscription: String) -> AnyPublisher<T, Error> {
	
		let p: PassthroughSubject = PassthroughSubject<T, Error>()

		self._clientId.getClientId(self._connection) { clientId, error in
			
			if (error != nil) {
				p.send(completion: .failure(error!))
			} else {
				self.subscribe(clientId: clientId!, publisher: p, subscription: subscription)
			}
		}
		
		return p.eraseToAnyPublisher()
	}
	
	public func stopSubscriber() {
		self._stopSubscriber = true
		
		for c in self._cancellable {
			c.cancel()
		}
	}
	
	private func subscribe<T:Decodable>(clientId: String, publisher p: PassthroughSubject<T, Error>, subscription: String) {
		
		super._execute(method: Method.POST, resourcePath: C8Y_CLIENT_NOTIFICATION, contentType: "application/json", request: self.subscribeRequest(clientId, subscription: subscription))
			.subscribe(Subscribers.Sink(receiveCompletion: { completion in
				
				// do nowt
				
				switch completion {
					case .failure(let error):
						self._clientId.clear()
						print("subscription error \(error.localizedDescription)")
					case .finished:
						print("subscription completed")
				}
				
			}, receiveValue: { response in
				
				if (response.content != nil) {
					do {
						let subscribeWrapper: [SubscribeResponse] = try JSONDecoder().decode([SubscribeResponse].self,  from: response.content!)
						if (subscribeWrapper.count > 0 && subscribeWrapper.first!.successful) {
							self.connectAndWait(clientId: clientId, publisher: p)
						} else {
							p.send(completion: .failure(InvalidSubscriberError(reason: subscribeWrapper.first!.error)))
						}
					} catch {
						p.send(completion: .failure(error))
					}
				} else {
					p.send(completion: .failure(InvalidSubscriberError()))
				}
			}))
	}
	
	private func connectAndWait<T:Decodable>(clientId: String, publisher p: PassthroughSubject<T, Error>) {
	
		// this where we do our long polling
		
		super._execute(method: Method.POST, resourcePath: C8Y_CLIENT_NOTIFICATION, contentType: "application/json", request: self.connectRequest(clientId))
			.sink(receiveCompletion: { completion in
			
				// keep listening for more
				
				if (!self._stopSubscriber) {
					self.connectAndWait(clientId: clientId, publisher: p)
				} else {
					p.send(completion: .finished)
				}
				
			}, receiveValue: { response in
				
				// will block until we get an updated operation back from c8y
				
				if (response.content != nil) {
					//p.send(response.content!)
					
					do {
						let decoder = JSONDecoder()
						decoder.dateDecodingStrategy = .formatted(C8yManagedObject.dateFormatter())
						
						print("data is \(String(data: response.content!, encoding: .utf8))")
						let opWrapper: [WaitResponse<T>] = try decoder.decode([WaitResponse<T>].self, from: response.content!)
						
						opWrapper.forEach { op in
							if (op.data != nil) {
								p.send(op.data!)
							}
						}
					} catch {
						print("error \(error)")
					// should we report errors TODO ?
					}
				} else {
					// should we report errors TODO ?
					
				}
			}).store(in: &self._cancellable)
	}
	
	
	
	public struct InvalidClientIdRequestError: Error {
		 
		 public var reason: String?
	}
	
	public struct InvalidSubscriberError: Error {
		 
		 public var reason: String?
	}

	
	private func subscribeRequest(_ clientId: String, subscription: String) -> Data {
		
		return """
		{
			\"channel\": \"/meta/subscribe\",
			\"clientId\": \"\(clientId)\",
			\"subscription\": \"\(subscription)\"
		}
		""".data(using: .utf8)!
	}

	private func connectRequest(_ clientId: String) -> Data {
		
		return """
			{
			  \"channel\": \"/meta/connect\",
			  \"clientId\": \"\(clientId)\"
			}
			""".data(using: .utf8)!
	}
	
	private class ClientIdRequestResponse: Codable {
		
		public var clientId: String?
		public var successful: Bool
		public var error: String?
	}
	
	private class SubscribeResponse: Codable {
		
		public var successful: Bool
		public var error: String?
	}
	
	private class WaitResponse<T:Decodable>: Decodable {
				
		public var data: T?
		public var realtimeAction: String?
		
		enum CodingKeys: CodingKey {
			case data
			case realtimeAction
		}
		
		public required init(from decoder: Decoder) throws {
			
			let container = try decoder.container(keyedBy: CodingKeys.self)
			
			let keys = container.allKeys
			
			for k in keys {
				print("key in response = \(k)")
			}
			

			if (container.contains(.data)) {
				let nestedContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .data)
				self.realtimeAction = try nestedContainer.decode(String.self, forKey: .realtimeAction)
				
				self.data = try nestedContainer.decode(T.self, forKey: .data)
			}
		}
	}
	
	class ClientIdProperty {
		
		private let lock: Lock

		private var clientId: String? = nil
		
		init(lock: Lock) {
			self.lock = lock
		}

		func clear() {
			self.clientId = nil
		}
		
		func getClientId(_ connection: C8yCumulocityConnection, callback: @escaping (String?, Error?) -> Void) {
			
			self.lock.lock()

			if (self.clientId != nil) {
				
				self.lock.unlock()

				callback(self.clientId, nil)
				
			} else {
				
				let rq = JcConnectionRequest<C8yCumulocityConnection>(connection)
				
				rq._execute(method: Method.POST, resourcePath: C8Y_CLIENT_NOTIFICATION, contentType: "application/json", request: self.clientIdRequest())
					.subscribe(Subscribers.Sink(receiveCompletion: { completion in
						
						switch completion {
							case .failure(let error):
								print("error \(error.localizedDescription)")
							case .finished:
								print("done")
						}
						
						self.lock.unlock()
						
					}, receiveValue: { response in
						
						if (response.content != nil) {
							do {
								let clientIdWrapper: [ClientIdRequestResponse] = try JSONDecoder().decode([ClientIdRequestResponse].self,  from: response.content!)
								
								if (clientIdWrapper.count > 0 && clientIdWrapper.first!.successful) {
									self.clientId = clientIdWrapper.first!.clientId!
									callback(self.clientId, nil)
									
								} else {
									callback(nil, InvalidClientIdRequestError(reason: clientIdWrapper.first!.error))
								}
							} catch {
								callback(nil, error)
							}
						} else {
							callback(nil, InvalidClientIdRequestError())
						}
					}))
			}
		}
		
		private func clientIdRequest() -> Data {
		
			return """
				{
					\"channel\": \"/meta/handshake\",
					\"version\": \"1.0\",
					\"mininumVersion\": \"1.0beta\",
					\"supportedConnectionTypes\": ["websocket", "long-polling"],
					\"systemOfUnits\": \"metric\"
				  }
				}
			""".data(using: .utf8)!
		}
	}
}
