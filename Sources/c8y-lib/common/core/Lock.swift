//
//  Lock.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 05/02/2021.
//  Copyright © 2021 John Carter. All rights reserved.
//

import Foundation

protocol Lock {
	func lock()
	func unlock()
}

extension NSLock: Lock {}

final class SpinLock: Lock {
	private var unfairLock = os_unfair_lock_s()

	func lock() {
		os_unfair_lock_lock(&unfairLock)
	}

	func unlock() {
		os_unfair_lock_unlock(&unfairLock)
	}
}

final class Mutex: Lock {
	private var mutex: pthread_mutex_t = {
		var mutex = pthread_mutex_t()
		pthread_mutex_init(&mutex, nil)
		return mutex
	}()

	func lock() {
		pthread_mutex_lock(&mutex)
	}

	func unlock() {
		pthread_mutex_unlock(&mutex)
	}
}
