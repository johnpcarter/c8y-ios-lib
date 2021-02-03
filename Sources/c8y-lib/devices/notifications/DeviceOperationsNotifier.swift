//
//  DeviceMetricsNotifier.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 05/01/2021.
//  Copyright © 2021 John Carter. All rights reserved.
//

import Foundation
import Combine

public class  C8yDeviceOperationsNotifier: ObservableObject {
	
	var deviceWrapper: C8yMutableDevice? = nil
	
	public var conn: C8yCumulocityConnection? = nil
	
	private var _deviceOperationHistoryTimer: JcRepeatingTimer? = nil
	private var _cancellable: [AnyCancellable] = []

	init() {
		
	}
	
	func reload(_ deviceWrapper: C8yMutableDevice, conn: C8yCumulocityConnection) {
		
		self.deviceWrapper = deviceWrapper
		self.conn = conn
		
		self.updateOperationHistory()
	}
	
	/**
	Stops the background thread for the preferred metric refresh and operation history. The thread must have been started by either `startMonitorForPrimaryMetric(_:refreshInterval)` or
	`primaryMetricPublisher(preferredMetric:refreshInterval:)`
	*/
	public func stopMonitoring() {
		
		for c in self._cancellable {
			c.cancel()
		}
	}
	
	func run(_ operation: C8yOperation, deviceWrapper: C8yMutableDevice? = nil, conn: C8yCumulocityConnection? = nil) throws -> AnyPublisher<C8yOperation, Error> {
		
		if (deviceWrapper != nil) {
			self.deviceWrapper = deviceWrapper
		}
		
		if (conn != nil) {
			self.conn = conn
		}
		
		let p = PassthroughSubject<C8yOperation, Error>()

		try C8yOperationService(self.conn!).post(operation: operation)
			.mapError( { error -> Error in
				return error
			})
			.receive(on: RunLoop.main)
			.subscribe(Subscribers.Sink(receiveCompletion: { completion in
				
				switch completion {
					case .failure(let error):
						p.send(completion: .failure(error))
					case .finished:
						print("done")
				}
			}, receiveValue: { response in
				
				// TODO: long poll operations to get next update

				if (response.content != nil) {
					self.deviceWrapper!.operationHistory.insert(response.content!, at: 0)
					self.waitForOperationResult(response.content!, publisher: p)
				} else {
					p.send(completion: .finished)
				}
			}))
		
		return p.eraseToAnyPublisher()
	}
	
	private var longPollingService: C8yOperationService? = nil
	
	func waitForOperationResult(_ op: C8yOperation, publisher p: PassthroughSubject<C8yOperation, Error>) {
		
		self.longPollingService = C8yOperationService(self.conn!)
		
		self.longPollingService!.subscribeForNewOperations(c8yIdOfDevice: op.deviceId)
			.receive(on: RunLoop.main)
			.subscribe(Subscribers.Sink(receiveCompletion: { completion in
			
				p.send(completion: completion)
			}, receiveValue: { operation in
				
				if (operation.id == op.id) {
					
					// got it, notify
					
					print("================= got operation update back")
					
					p.send(operation)
					p.send(completion: .finished)
					
					self.longPollingService!.stopSubscriber()
				} else {
					self.deviceWrapper?.operationHistory.insert(operation, at: 0)
				}
			}))
	}
	
	/**
	Fetches latest device operation history, views will be updated automatically via published  attribute `operationHistory`
	You must ensure that your SwiftUI View references this class object either as a @ObservedObject or @StateObject
	*/
	public func updateOperationHistory() {
		
		if (self.deviceWrapper == nil) {
			return
		}
		
		self.fetchOperationHistory()
			.receive(on: RunLoop.main)
			.sink(receiveCompletion: { completion in
				
				self.deviceWrapper!.reloadOperations = false
				
				switch completion {
				case .failure(let error):
					print("failed due to \(error)")
				default:
					print("done")
				}
			}) { results in
				
				self.deviceWrapper!.operationHistory = results.reversed()
				
		}.store(in: &self._cancellable)
	}
	
	/**
	Fetches latest device operation history from Cumulocity
	- returns: Publisher containing latest operation history
	*/
	public func fetchOperationHistory() -> AnyPublisher<[C8yOperation], JcConnectionRequest<C8yCumulocityConnection>.APIError> {
					  
		return C8yOperationService(self.conn!).get(self.deviceWrapper!.device.c8yId!).map({response in
			return response.content!.operations
		}).eraseToAnyPublisher()
	}
}
