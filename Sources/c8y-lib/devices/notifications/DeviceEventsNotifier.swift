//
//  DeviceMetricsNotifier.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 05/01/2021.
//  Copyright © 2021 John Carter. All rights reserved.
//

import Foundation
import Combine
import CoreLocation

public class C8yDeviceEventsNotifier {
	
	var deviceWrapper: C8yMutableDevice? = nil
	var conn: C8yCumulocityConnection? = nil
	
	private var _cancellable: [AnyCancellable] = []

	init() {
		
	}
	
	func reload(_ deviceWrapper: C8yMutableDevice, conn: C8yCumulocityConnection) {
		
		self.deviceWrapper = deviceWrapper
		self.conn = conn
		
		self.updateEventLogsForToday()
	}
	
	/**
	Fetches latest device event logs, views will be updated automatically via published  attribute `events`
	You must ensure that your SwiftUI View references this class object either as a @ObservedObject or @StateObject
	*/
	public func updateEventLogsForToday() {
		
		if (self.deviceWrapper == nil) {
			return
		}
		
		self.fetchEventLogsForToday()
			.receive(on: RunLoop.main)
			.sink(receiveCompletion: { completion in
				self.deviceWrapper!.reloadLogs = false
				switch completion {
				case .failure(let error):
					print("failed due to \(error)")
				default:
					print("done")
				}
				
				self.deviceWrapper!.reloadLogs = false
			}) { results in
				self.deviceWrapper!.events = results
				
				results.forEach { o in
					if (o.type == C8yLocationUpdate_EVENT && o.position != nil) {
						self.deviceWrapper!.tracking.insert(CLLocationCoordinate2D(latitude: o.position!.lat, longitude: o.position!.lng), at: 0)
					}
				}
		}.store(in: &self._cancellable)
	}
	
	private var longPollingService: C8yEventsService? = nil
	
	public func listenForNewEvents() -> AnyPublisher<C8yEvent, Error> {
		
		self.longPollingService = C8yEventsService(self.conn!)
		
		return self.longPollingService!.subscribeForNewEvents(c8yIdOfDevice: self.deviceWrapper!.device.c8yId!).map { event -> C8yEvent in
			
			DispatchQueue.main.async {
				self.deviceWrapper?.events.insert(event, at: 0)
			}
			
			return event
		}.eraseToAnyPublisher()
	}
	
	public func stopMonitoring() {
		
		if (self.longPollingService != nil) {
			self.longPollingService!.stopSubscriber()
			self.longPollingService = nil
		}
	}
	
	/**
	Fetches latest device events from Cumulocity
	- returns: Publisher containing latest device events
	*/
	public func fetchEventLogsForToday() -> AnyPublisher<[C8yEvent], JcConnectionRequest<C8yCumulocityConnection>.APIError> {
					
		return C8yEventsService(self.conn!).get(source: self.deviceWrapper!.device.c8yId!, pageNum: 0).map({response in
			
			return response.content!.events
			
		}).eraseToAnyPublisher()
	}
}
