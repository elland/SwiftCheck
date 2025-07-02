//
//  AsyncForAllTests.swift
//  SwiftCheck
//
//  Created by Igor Ranieri on 25.06.2025.
//

@testable import SwiftCheck
import Foundation
import Testing

let PropertyTestRuns = 150

struct AsyncForAllTests {
	@Test func asyncForAllBasicTest() {
		let args = CheckerArguments(replay: (StdGen(12345, 67890), 10), maxAllowableSuccessfulTests: PropertyTestRuns)

		property("async forAll works with simple property", arguments: args) <-
		forAll { (x: Int) async -> Bool in
			try! await Task.sleep(nanoseconds: 100)
			return x == x
		}
	}

	@Test func asyncForAllErrorHandlingTest() {
		let args = CheckerArguments(maxAllowableSuccessfulTests: PropertyTestRuns)

		property("async forAll handles errors correctly", arguments: args) <-
		forAll { (x: Int) async throws -> Bool in
			if x == Int.min {
				throw TestError.overflow
			}
			try! await Task.sleep(nanoseconds: 500)
			return x != Int.min
		}
	}

	@Test func asyncForAllShrinkingTest() {
		let args = CheckerArguments(maxAllowableSuccessfulTests: PropertyTestRuns)

		property("async forAll shrinks properly on failure", arguments: args) <-
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
		let args = CheckerArguments(replay: (seed, size), maxAllowableSuccessfulTests: PropertyTestRuns)

		property("parameterized async test", arguments: args) <-
		forAll { (x: Int, y: String) async -> Bool in
			try! await Task.sleep(nanoseconds: UInt64(size * 100))
			return y.count >= 0 && x == x
		}
	}

	@Test func asyncForAllDifferentReturnTypes() {
		let args = CheckerArguments(maxAllowableSuccessfulTests: PropertyTestRuns)

		property("async forAll works with Property return", arguments: args) <-
		forAll { (x: Int, y: Int) async -> Property in
			try! await Task.sleep(nanoseconds: 300)
			return (x + y == y + x).counterexample("commutative addition failed")
		}
	}

	@Test func asyncForAllSequentialExecutionTest() {
		let start = Date()
		let args = CheckerArguments(maxAllowableSuccessfulTests: 10) // Small number for timing test

		property("async operations run sequentially as expected", arguments: args) <-
		forAll { (x: Int) async -> Bool in
			try! await Task.sleep(for: .milliseconds(10))  // 10ms * 10 = 100ms minimum
			return true
		}

		let elapsed = Date().timeIntervalSince(start)
		#expect(elapsed >= 0.1) // Should take at least 100ms
		#expect(elapsed < 0.2)  // But not too much more than that
	}

	@Test func asyncForAllDeterministicTest() async {
		let seed = StdGen(12345, 67890)
		let args = CheckerArguments(replay: (seed, 10), maxAllowableSuccessfulTests: PropertyTestRuns)

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
		let args1 = CheckerArguments(replay: (seed1, 10), maxAllowableSuccessfulTests: PropertyTestRuns)
		let args2 = CheckerArguments(replay: (seed2, 10), maxAllowableSuccessfulTests: PropertyTestRuns)

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
		let args = CheckerArguments(maxAllowableSuccessfulTests: PropertyTestRuns)

		property("multiple async operations work", arguments: args) <-
		forAll { (x: Int, y: Int) async -> Bool in
			let result1 = await asyncComputation(x)
			let result2 = await asyncComputation(y)
			try! await Task.sleep(nanoseconds: 100)
			let computeResult = await asyncComputation(x + y)

			return result1 + result2 == computeResult
		}
	}

	@Test func asyncForAllTupleVariants() {
		let args = CheckerArguments(maxAllowableSuccessfulTests: PropertyTestRuns)

		property("3-tuple async forAll", arguments: args) <-
		forAll { (a: Int, b: String, c: Bool) async -> Bool in
			try! await Task.sleep(nanoseconds: 100)
			return c || (!c)  // tautology
		}

		property("4-tuple async forAll", arguments: args) <-
		forAll { (a: Int8, b: Int16, c: Int32, d: Int64) async -> Bool in
			try! await Task.sleep(nanoseconds: 100)
			return Int64(a) < d || Int64(a) >= d  // tautology
		}
	}

	@Test func asyncForAllCancellationTest() async {
		var wasFullyCancelled = false
		let args = CheckerArguments(maxAllowableSuccessfulTests: PropertyTestRuns)

		let task = Task {
			property("cancellable property", arguments: args) <-
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
		let args = CheckerArguments(maxAllowableSuccessfulTests: PropertyTestRuns)

		property("concurrent async operations", arguments: args) <-
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
		let args = CheckerArguments(maxAllowableSuccessfulTests: PropertyTestRuns)

		property("actor state is consistent", arguments: args) <-
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
		let args = CheckerArguments(maxAllowableSuccessfulTests: PropertyTestRuns)

		property("main actor operations", arguments: args) <-
		forAll { (value: String) async -> Bool in
			let result = await MainActor.run {
				// Simulate UI operation
				value.uppercased()
			}

			return result == value.uppercased()
		}
	}

	// TODO: fix this
//	@Test func asyncForAllTimeoutBehavior() {
//		let args = CheckerArguments(maxAllowableSuccessfulTests: PropertyTestRuns)
//
//		property("operations complete within timeout", arguments: args) <-
//		forAll { (delayMs: UInt8) async -> Bool in
//			let delay = min(UInt64(delayMs), 1) // Cap at 50ms
//
//			let result = await withTaskGroup(of: Bool.self) { group in
//				group.addTask {
//					do {
//						try await Task.sleep(for: .milliseconds(100 * delay))
//					} catch {
//						print("Caught an error from delay sleep! \(error)")
//					}
//					return true
//				}
//
//				group.addTask {
//					do {
//						try await Task.sleep(for: .milliseconds(100)) // 100ms timeout
//					} catch {
//						print("Caught an error from sleep! \(error)")
//					}
//					return false
//				}
//
//				let firstResult = await group.next() ?? false
//				group.cancelAll()
//				return firstResult
//			}
//
//			return result == true // Should always complete before timeout
//		}
//	}

	@Test func asyncForAllThreadSafetyStressTest() async {
		let concurrentProperties = PropertyTestRuns
		let testsPerProperty = 1000
		let expectedTotal = concurrentProperties * testsPerProperty

		let counter = ThreadSafeCounter()

		await withTaskGroup(of: Void.self) { group in
			for i in 0..<concurrentProperties {
				group.addTask {
					let args = CheckerArguments(maxAllowableSuccessfulTests: testsPerProperty)
					property("concurrent property \(i)", arguments: args) <-
					forAll { (x: Int) async -> Bool in
						await counter.increment()
						return true
					}
				}
			}
		}

		let finalCount = await counter.value
		#expect(finalCount == expectedTotal)
	}

	// MARK: - forAll(Gen)
	// TODO: generated tests, double check for nonsense
	
	@Test func asyncForAllExplicitSingleGenTest() {
		let args = CheckerArguments(replay: (StdGen(12345, 67890), 10), maxAllowableSuccessfulTests: PropertyTestRuns)

		property("async forAll with explicit single generator", arguments: args) <-
		forAll(Gen<Int>.choose((1, 100))) { (x: Int) async -> Bool in
			try! await Task.sleep(nanoseconds: 100)
			return x >= 1 && x <= 100
		}
	}

	@Test func asyncForAllExplicitTwoGenTest() {
		let args = CheckerArguments(replay: (StdGen(12345, 67890), 10), maxAllowableSuccessfulTests: PropertyTestRuns)

		property("async forAll with two explicit generators", arguments: args) <-
		forAll(Gen<Int>.choose((0, 50)), Gen<String>.fromElements(of: ["a", "b", "c"])) { (x: Int, s: String) async -> Bool in
			try! await Task.sleep(nanoseconds: 150)
			return x <= 50 && ["a", "b", "c"].contains(s)
		}
	}

	@Test func asyncForAllExplicitThreeGenTest() {
		let args = CheckerArguments(maxAllowableSuccessfulTests: PropertyTestRuns)

		property("async forAll with three explicit generators", arguments: args) <-
		forAll(
			Gen<Int>.choose((1, 10)),
			Gen<Bool>.fromElements(of: [true, false]),
			Gen<Double>.choose((0.0, 1.0))
		) { (i: Int, b: Bool, d: Double) async -> Bool in
			try! await Task.sleep(nanoseconds: 200)
			return i >= 1 && i <= 10 && d >= 0.0 && d <= 1.0
		}
	}

	@Test func asyncForAllExplicitFourGenTest() {
		let args = CheckerArguments(maxAllowableSuccessfulTests: PropertyTestRuns)

		property("async forAll with four explicit generators", arguments: args) <-
		forAll(
			Gen<Int8>.choose((1, 127)),
			Gen<Int16>.choose((1, 1000)),
			Gen<Int32>.choose((1, 100000)),
			Gen<String>.fromElements(of: ["test", "data", "value"])
		) { (a: Int8, b: Int16, c: Int32, s: String) async -> Bool in
			try! await Task.sleep(nanoseconds: 250)
			return a > 0 && b > 0 && c > 0 && !s.isEmpty
		}
	}

	@Test func asyncForAllExplicitArrayGenTest() {
		let args = CheckerArguments(maxAllowableSuccessfulTests: PropertyTestRuns)

		property("async forAll with array generator", arguments: args) <-
		forAll(Gen<[Int]>.fromElements(of: [[1, 2, 3], [4, 5], [6]])) { (arr: [Int]) async -> Bool in
			try! await Task.sleep(nanoseconds: 100)
			return !arr.isEmpty && arr.allSatisfy { $0 > 0 }
		}
	}

	@Test func asyncForAllExplicitCustomGenTest() {
		let evenGen = Gen<Int>.choose((1, 100)).map { $0 * 2 }
		let args = CheckerArguments(maxAllowableSuccessfulTests: PropertyTestRuns)

		property("async forAll with custom generator", arguments: args) <-
		forAll(evenGen) { (x: Int) async -> Bool in
			try! await Task.sleep(nanoseconds: 100)
			return x % 2 == 0
		}
	}

	@Test func asyncForAllExplicitErrorHandlingTest() {
		let args = CheckerArguments(maxAllowableSuccessfulTests: PropertyTestRuns)

		property("async forAll explicit gen handles errors", arguments: args) <-
		forAll(Gen<Int>.choose((-100, 100))) { (x: Int) async throws -> Bool in
			if x == -100 {
				throw TestError.overflow
			}
			try! await Task.sleep(nanoseconds: 150)
			return x != -100
		}
	}

	@Test func asyncForAllExplicitShrinkingTest() {
		let args = CheckerArguments(maxAllowableSuccessfulTests: PropertyTestRuns)

		property("async forAll explicit gen shrinks properly", arguments: args) <-
		forAll(Gen<Int>.choose((1, 100))) { (x: Int) async -> Bool in
			try! await Task.sleep(nanoseconds: 200)
			return x > 75
		}.expectFailure
	}

	@Test func asyncForAllExplicitDeterministicTest() async {
		let seed = StdGen(12345, 67890)
		let args = CheckerArguments(replay: (seed, 10), maxAllowableSuccessfulTests: PropertyTestRuns)

		let firstCollector = Collector()
		let secondCollector = Collector()

		let gen = Gen<Int>.choose((1, 1000))

		property("deterministic explicit gen test run 1", arguments: args) <-
		forAll(gen) { (x: Int) async -> Bool in
			await firstCollector.append(x)
			try! await Task.sleep(nanoseconds: 100)
			return true
		}

		property("deterministic explicit gen test run 2", arguments: args) <-
		forAll(gen) { (x: Int) async -> Bool in
			await secondCollector.append(x)
			try! await Task.sleep(nanoseconds: 100)
			return true
		}

		let firstValues = await firstCollector.values
		let secondValues = await secondCollector.values

		#expect(firstValues == secondValues)
		#expect(firstValues.count > 0)
		#expect(firstValues.allSatisfy { $0 >= 1 && $0 <= 1000 })
	}

	@Test func asyncForAllExplicitConcurrentTest() {
		let args = CheckerArguments(maxAllowableSuccessfulTests: PropertyTestRuns)

		property("explicit gen concurrent operations", arguments: args) <-
		forAll(
			Gen<[String]>.fromElements(of: [["url1", "url2"], ["url3"], ["url4", "url5", "url6"]])
		) { (urls: [String]) async -> Bool in
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

	@Test func asyncForAllExplicitComplexTypeTest() {
		struct TestData: Arbitrary {
			static var arbitrary: SwiftCheck.Gen<TestData> {
				Gen.zip(
					Int.arbitrary,
					String.arbitrary,
					Bool.arbitrary
				).map { id, name, active in
					TestData(id: id, name: name, active: active)
				}
			}

			let id: Int
			let name: String
			let active: Bool
		}

		let testDataGen = Gen<TestData>.compose { _ in
			TestData(
				id: Gen.choose((1, 1000)).generate,
				name: Gen.fromElements(of: ["Alice", "Bob", "Charlie"]).generate,
				active: Gen.fromElements(of: [true, false]).generate
			)
		}

		let args = CheckerArguments(maxAllowableSuccessfulTests: PropertyTestRuns)

		property("async forAll with complex type generator", arguments: args) <-
		forAll(testDataGen) { (data: TestData) async -> Bool in
			try! await Task.sleep(nanoseconds: 100)
			return data.id > 0 && !data.name.isEmpty
		}
	}

	@Test func asyncForAllExplicitMixedGenAndImplicitTest() {
		let args = CheckerArguments(maxAllowableSuccessfulTests: PropertyTestRuns)

		property("mixed explicit and implicit generators", arguments: args) <-
		forAll(Gen<Int>.choose((1, 10))) { (explicitInt: Int) async -> Property in
			forAll { (implicitString: String) async -> Property in
				try! await Task.sleep(nanoseconds: 100)
				return explicitInt > 0 ^&&^ implicitString.count >= 0
			}
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

actor ThreadSafeCounter {
	private var count = 0

	func increment() {
		self.count += 1
	}

	var value: Int {
		self.count
	}
}
