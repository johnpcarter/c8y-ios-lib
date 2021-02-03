//
//  DeviceMetricsNotifier.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 05/01/2021.
//  Copyright © 2021 John Carter. All rights reserved.
//

import Foundation
import Combine

public class C8yDeviceAlarmsNotifier {
	

	var deviceWrapper: C8yMutableDevice? = nil
	var conn: C8yCumulocityConnection? = nil
	
	private var _cancellable: [AnyCancellable] = []
	
	init() {
		
	}
	
	func reload(_ deviceWrapper: C8yMutableDevice, conn: C8yCumulocityConnection) {
		
		self.deviceWrapper = deviceWrapper
		self.conn = conn
		
		self.updateAlarmsForToday()
	}
	
	public func stopMonitoring() {
		
	}
	
	/**
	Fetches latest device alarms,  views will be updated automatically via published  attribute `alarms`
	You must ensure that your SwiftUI View references this class object either as a @ObservedObject or @StateObject
	*/
	public func updateAlarmsForToday() {
		
		if (self.deviceWrapper == nil) {
			return
		}
		
		self.fetchActiveAlarmsForToday()
			.receive(on: RunLoop.main)
			.sink(receiveCompletion: { completion in
				self.deviceWrapper!.reloadAlarms = false
				switch completion {
				case .failure(let error):
					print("failed due to \(error)")
				default:
					print("done")
				}
				
				self.deviceWrapper!.reloadAlarms = false
			}) { results in
				self.deviceWrapper!.alarms = results
		}.store(in: &self._cancellable)
	}
	
	/**
	Fetches latest device alarms from Cumulocity
	- returns: Publisher containing latest alarms
	*/
	public func fetchActiveAlarmsForToday() -> AnyPublisher<[C8yAlarm], JcConnectionRequest<C8yCumulocityConnection>.APIError> {
			
		return C8yAlarmsService(self.conn!).get(source: self.deviceWrapper!.device.c8yId!, status: .ACTIVE, pageNum: 0)
			.merge(with: C8yAlarmsService(self.conn!).get(source: self.deviceWrapper!.device.c8yId!, status: .ACKNOWLEDGED, pageNum: 0))
			.collect()
			.map({response in
				var array: [C8yAlarm] = []
		
				for p in response {
					array.append(contentsOf: p.content!.alarms)
				}
				
				return array
		}).eraseToAnyPublisher()
	}
	
	private var longPollingService: C8yAlarmsService? = nil
	
	public func listenForNewAlarms() -> AnyPublisher<C8yAlarm, Error> {
		
		self.longPollingService = C8yAlarmsService(self.conn!)
		
		return self.longPollingService!.subscribeForNewAlarms(c8yIdOfDevice: self.deviceWrapper!.device.c8yId!).map { event -> C8yAlarm in
			
			self.deviceWrapper?.alarms.insert(event, at: 0)
			
			return event
		}.eraseToAnyPublisher()
	}
}
