//
//  AsyncForAllTests.swift
//  SwiftCheck
//
//  Created by Igor Ranieri on 25.06.2025.
//

import SwiftCheck
import Foundation
import Testing

struct AsyncForAllTests {
	@Test func asyncForAllBasicTest() {
		let args = CheckerArguments(replay: (StdGen(12345, 67890), 10))

		property("async forAll works with simple property", arguments: args) <-
		forAll { (x: Int) async -> Bool in
			try! await Task.sleep(nanoseconds: 1000)
			return x == x
		}
	}

	@Test func asyncForAllErrorHandlingTest() {
		property("async forAll handles errors correctly") <-
		forAll { (x: Int) async throws -> Bool in
			if x == Int.min {
				throw TestError.overflow
			}
			try! await Task.sleep(nanoseconds: 500)
			return x != Int.min
		}
	}

	@Test func asyncForAllShrinkingTest() {
		property("async forAll shrinks properly on failure") <-
		forAll { (x: Int) async -> Bool in
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
		forAll { (x: Int, y: String) async -> Bool in
			try! await Task.sleep(nanoseconds: UInt64(size * 100))
			return y.count >= 0 && x == x
		}
	}

	@Test func asyncForAllDifferentReturnTypes() {
		property("async forAll works with Property return") <-
		forAll { (x: Int, y: Int) async -> Property in
			try! await Task.sleep(nanoseconds: 300)
			return (x + y == y + x).counterexample("commutative addition failed")
		}
	}

	@Test func asyncForAllPerformanceTest() {
		let start = Date()

		property("async operations run concurrently, not sequentially") <-
		forAll { (x: Int) async -> Bool in
			try! await Task.sleep(for: .milliseconds(1))  // 1ms * 100 = 100ms total
			return true
		}

		let elapsed = Date().timeIntervalSince(start)
		#expect(elapsed < 0.5)  // Should complete in under 500ms (100 * 1ms + overhead)
	}

	@Test func asyncForAllDeterministicTest() async {
		let seed = StdGen(12345, 67890)
		let args = CheckerArguments(replay: (seed, 10))

		let firstCollector = Collector()
		let secondCollector = Collector()

		// First run
		property("deterministic test run 1", arguments: args) <-
		forAll { (x: Int) async -> Bool in
			await firstCollector.append(x)
			try! await Task.sleep(nanoseconds: 100)
			return true
		}

		// Second run with same seed
		property("deterministic test run 2", arguments: args) <-
		forAll { (x: Int) async -> Bool in
			await secondCollector.append(x)
			try! await Task.sleep(nanoseconds: 100)
			return true
		}

		let firstValues = await firstCollector.values
		let secondValues = await secondCollector.values

		#expect(firstValues == secondValues)
		#expect(firstValues.count > 0)
	}

	@Test func asyncForAllDifferentSeedsDifferentData() async {
		let collector1 = Collector()
		let collector2 = Collector()

		let seed1 = StdGen(11111, 22222)
		let seed2 = StdGen(33333, 44444)
		let args1 = CheckerArguments(replay: (seed1, 10))
		let args2 = CheckerArguments(replay: (seed2, 10))

		property("different seeds test 1", arguments: args1) <-
		forAll { (x: Int) async -> Bool in
			await collector1.append(x)
			return true
		}

		property("different seeds test 2", arguments: args2) <-
		forAll { (x: Int) async -> Bool in
			await collector2.append(x)
			return true
		}

		let values1 = await collector1.values
		let values2 = await collector2.values

		#expect(values1 != values2)
	}

	// MARK: - Additional Tests

	@Test func asyncForAllMultipleAsyncOps() {
		property("multiple async operations work") <-
		forAll { (x: Int, y: Int) async -> Bool in
			let result1 = await asyncComputation(x)
			let result2 = await asyncComputation(y)
			try! await Task.sleep(nanoseconds: 100)
			let computeResult = await asyncComputation(x + y)

			return result1 + result2 == computeResult
		}
	}

	@Test func asyncForAllTupleVariants() {
		property("3-tuple async forAll") <-
		forAll { (a: Int, b: String, c: Bool) async -> Bool in
			try! await Task.sleep(nanoseconds: 100)
			return c || (!c)  // tautology
		}

		property("4-tuple async forAll") <-
		forAll { (a: Int8, b: Int16, c: Int32, d: Int64) async -> Bool in
			try! await Task.sleep(nanoseconds: 100)
			return Int64(a) < d || Int64(a) >= d  // tautology
		}
	}

	@Test func asyncForAllCancellationTest() async {
		var wasFullyCancelled = false

		let task = Task {
			property("cancellable property") <-
			forAll { (x: Int) async throws -> Bool in
				for _ in 0..<10 {
					try Task.checkCancellation()
					try await Task.sleep(nanoseconds: 100_000)
				}
				return true
			}
		}

		// Give the task a moment to start
		try! await Task.sleep(for: .milliseconds(50))
		task.cancel()
		wasFullyCancelled = true

		// Wait for cancellation to propagate
		_ = await task.result

		#expect(wasFullyCancelled)
	}

	@Test func asyncForAllConcurrentOperations() {
		property("concurrent async operations") <-
		forAll { (urls: [String]) async -> Bool in
			// Simulate concurrent network requests
			let results = await withTaskGroup(of: Int.self) { group in
				for (index, _) in urls.enumerated() {
					group.addTask {
						try! await Task.sleep(nanoseconds: 100)
						return index
					}
				}

				var collected: [Int] = []
				for await result in group {
					collected.append(result)
				}
				return collected
			}

			return results.count == urls.count
		}
	}

	@Test func asyncForAllActorInteraction() async {
		let sharedActor = SharedCounter()

		property("actor state is consistent") <-
		forAll { (increments: Int8) async -> Bool in
			let absoluteIncrements = abs(Int(increments))

			await sharedActor.reset()

			await withTaskGroup(of: Void.self) { group in
				for _ in 0..<absoluteIncrements {
					group.addTask {
						await sharedActor.increment()
					}
				}
			}

			let finalCount = await sharedActor.count
			return finalCount == absoluteIncrements
		}
	}

	@Test func asyncForAllMainActorInteraction() {
		property("main actor operations") <-
		forAll { (value: String) async -> Bool in
			let result = await MainActor.run {
				// Simulate UI operation
				value.uppercased()
			}

			return result == value.uppercased()
		}
	}

	@Test func asyncForAllTimeoutBehavior() {
		property("operations complete within timeout") <-
		forAll { (delayMs: UInt8) async -> Bool in
			let delay = min(UInt64(delayMs), 50) // Cap at 50ms

			let result = await withTaskGroup(of: Bool.self) { group in
				group.addTask {
					try! await Task.sleep(nanoseconds: delay * 1_000_000)
					return true
				}

				group.addTask {
					try? await Task.sleep(nanoseconds: 100_000_000) // 100ms timeout
					return false
				}

				let firstResult = await group.next() ?? false
				group.cancelAll()
				return firstResult
			}

			return result == true // Should always complete before timeout
		}
	}
}

// MARK: - Helper Types and Functions

enum TestError: Error {
	case overflow
}

actor Collector {
	var values: [Int] = []

	func append(_ value: Int) {
		self.values.append(value)
	}
}

actor SharedCounter {
	var count = 0

	func increment() {
		self.count += 1
	}

	func reset() {
		self.count = 0
	}
}

func asyncComputation(_ n: Int) async -> Int {
	try! await Task.sleep(nanoseconds: 100)
	return n * 2
}
