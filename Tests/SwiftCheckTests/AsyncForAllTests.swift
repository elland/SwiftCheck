//
//  AsyncForAllTests.swift
//  SwiftCheck
//
//  Created by Igor Ranieri on 25.06.2025.
//  Copyright © 2025 Typelift. All rights reserved.
//

import SwiftCheck
import Foundation
import Testing

struct AsyncForAllTests {
	@Test func asyncForAllBasicTest() {
		let args = CheckerArguments(replay: (StdGen(12345, 67890), 10))

		property("async forAll works with simple property", arguments: args) <-
		forAll { (x: Int) -> Bool in
			try! await Task.sleep(nanoseconds: 1000)
			return x == x
		}
	}

	@Test func asyncForAllErrorHandlingTest() {
		property("async forAll handles errors correctly") <-
		forAll { (x: Int) -> Bool in
			if x == Int.min {
				throw TestError.overflow
			}
			try! await Task.sleep(nanoseconds: 500)
			return x != Int.min
		}
	}

	@Test func asyncForAllShrinkingTest() {
		property("async forAll shrinks properly on failure") <-
		forAll { (x: Int) -> Bool in
			try! await Task.sleep(nanoseconds: 200)
			return x < 50  // This will fail and shrink
		}.expectFailure
	}

	@Test(arguments: [
		(StdGen(12345, 67890), 5),
		(StdGen(98765, 43210), 10),
		(StdGen(11111, 22222), 20)
	])
	func asyncForAllParameterizedTest(seed: StdGen, size: Int) {
		let args = CheckerArguments(replay: (seed, size))

		property("parameterized async test", arguments: args) <-
		forAll { (x: Int, y: String) -> Bool in
			try! await Task.sleep(nanoseconds: UInt64(size * 100))
			return y.count >= 0 && x == x
		}
	}

	@Test func asyncForAllDifferentReturnTypes() {
		property("async forAll works with Property return") <-
		forAll { (x: Int, y: Int) -> Property in
			try! await Task.sleep(nanoseconds: 300)
			return (x + y == y + x).counterexample("commutative addition failed")
		}
	}

	@Test func asyncForAllPerformanceTest() {
		let start = Date()

		property("async forAll doesn't block threads") <-
		forAll { (x: Int) -> Bool in
			try! await Task.sleep(for: .milliseconds(0.5))
			return true
		}

		let elapsed = Date().timeIntervalSince(start)
		#expect(
			// Should complete reasonably fast despite sleeps
			Duration.seconds(elapsed) < Duration.seconds(0.2)
		)
	}

	@Test func asyncForAllDeterministicTest() async {
		let seed = StdGen(12345, 67890)
		let args = CheckerArguments(replay: (seed, 10))

		let firstCollector = Collector()
		let secondCollector = Collector()

		// First run
		property("deterministic test run 1", arguments: args) <-
		forAll { (x: Int) -> Bool in
			await firstCollector.append(x)
			try! await Task.sleep(nanoseconds: 100)
			return true
		}

		// Second run with same seed
		property("deterministic test run 2", arguments: args) <-
		forAll { (x: Int) -> Bool in
			await secondCollector.append(x)
			try! await Task.sleep(nanoseconds: 100)
			return true
		}

		let firstCount = await firstCollector.values
		let secondCount = await secondCollector.values

		#expect(firstCount == secondCount)
		#expect(firstCount.count > 0)
	}

	@Test func asyncForAllDifferentSeedsDifferentData() {
		let seed1 = StdGen(11111, 22222)
		let seed2 = StdGen(33333, 44444)
		let args1 = CheckerArguments(replay: (seed1, 10))
		let args2 = CheckerArguments(replay: (seed2, 10))

		var values1: [Int] = []
		var values2: [Int] = []

		property("different seeds test 1", arguments: args1) <-
		forAll { (x: Int) -> Bool in
			values1.append(x)
			return true
		}

		property("different seeds test 2", arguments: args2) <-
		forAll { (x: Int) -> Bool in
			values2.append(x)
			return true
		}

		#expect(values1 != values2)
	}
}

enum TestError: Error {
	case overflow
}

actor Collector {
	var values: [Int] = []

	func append(_ value: Int) {
		values.append(value)
	}

	func getValues() -> [Int] {
		values
	}
}
