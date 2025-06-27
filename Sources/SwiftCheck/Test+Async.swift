//
//  Test+Async.swift
//  SwiftCheck
//
//  Created by Igor Ranieri on 25.06.2025.
//  Copyright © 2025 Igor Ranieri. All rights reserved.
//

import Dispatch
import Foundation

public typealias SendableTestable = Sendable & Testable

public typealias SendableArbitrary = Sendable & Arbitrary

public func forAll<A>(_ pf: @Sendable @escaping (A) async throws -> SendableTestable) -> Property where A: SendableArbitrary {
	return forAllShrink(A.arbitrary, shrinker: A.shrink, f: pf)
}

public func forAll<A, B>(_ pf: @Sendable @escaping (A, B) async throws -> SendableTestable) -> Property
	where A: SendableArbitrary, B: SendableArbitrary
{
	forAll { a in
		forAll { b in
			try await pf(a, b)
		}
	}
}

public func forAll<A, B, C>(_ pf: @Sendable @escaping (A, B, C) async throws -> SendableTestable) -> Property
	where A: SendableArbitrary, B: SendableArbitrary, C: SendableArbitrary
{
	forAll { a in
		forAll { b, c in
			try await pf(a, b, c)
		}
	}
}

public func forAll<A, B, C, D>(_ pf: @Sendable @escaping (A, B, C, D) async throws -> SendableTestable) -> Property
where A: SendableArbitrary, B: SendableArbitrary, C: SendableArbitrary, D: SendableArbitrary
{
	forAll { a in
		forAll { b, c, d in
			try await pf(a, b, c, d)
		}
	}
}

public func forAll<A, B, C, D, E>(_ pf: @Sendable @escaping (A, B, C, D, E) async throws -> SendableTestable) -> Property
	where A: SendableArbitrary, B: SendableArbitrary, C: SendableArbitrary, D: SendableArbitrary, E: SendableArbitrary
{
	forAll { a in
		forAll { b, c, d, e in
			try await pf(a, b, c, d, e)
		}
	}
}

public func forAll<A, B, C, D, E, F>(_ pf: @Sendable @escaping (A, B, C, D, E, F) async throws -> SendableTestable) -> Property
	where A: SendableArbitrary, B: SendableArbitrary, C: SendableArbitrary, D: SendableArbitrary, E: SendableArbitrary, F: SendableArbitrary
{
	forAll { a in
		forAll { b, c, d, e, f in
			try await pf(a, b, c, d, e, f)
		}
	}
}

public func forAll<A, B, C, D, E, F, G>(_ pf: @Sendable @escaping (A, B, C, D, E, F, G) async throws -> SendableTestable) -> Property
	where A: SendableArbitrary, B: SendableArbitrary, C: SendableArbitrary, D: SendableArbitrary, E: SendableArbitrary, F: SendableArbitrary, G: SendableArbitrary
{
	forAll { a in
		forAll { b, c, d, e, f, g in
			try await pf(a, b, c, d, e, f, g)
		}
	}
}

public func forAll<A, B, C, D, E, F, G, H>(_ pf: @Sendable @escaping (A, B, C, D, E, F, G, H) async throws -> SendableTestable) -> Property
	where A: SendableArbitrary, B: SendableArbitrary, C: SendableArbitrary, D: SendableArbitrary, E: SendableArbitrary, F: SendableArbitrary, G: SendableArbitrary, H: SendableArbitrary
{
	forAll { a in
		forAll { b, c, d, e, f, g, h in
			try await pf(a, b, c, d, e, f, g, h)
		}
	}
}

public func forAllShrink<A: Sendable>(_ gen: Gen<A>, shrinker: @escaping (A) -> [A], f: @Sendable @escaping (A) async throws -> SendableTestable) -> Property {
	Property(gen.flatMap { x in
		shrinking(shrinker, initial: x, prop: { xs in
			let result: Result<SendableTestable, Error> = runAsyncAndWait {
								do {
									return .success(try await f(xs))
								} catch let e {
									return .failure(e)
								}

			}

			switch result {
			case .success(let testResult):
				return testResult.counterexample(String(describing: xs))
			case .failure(let e):
				return TestResult.failed("Test case threw an exception: \"\(e)\"").counterexample(String(describing: xs))
			}
		}).unProperty
	}).again
}

// MARK: -

private func runAsyncAndWait<T: Sendable>(_ operation: @Sendable @escaping () async -> T) -> T {
	if Thread.isMainThread {
		// Run the blocking code *on a background queue* to avoid deadlock
		return DispatchQueue.global(qos: .userInitiated).sync {
			runAsyncAndWait(operation)
		}
	}

	let semaphore = DispatchSemaphore(value: 0)
	var result: T?

	Task.detached {
		result = await operation()
		semaphore.signal()
	}

	semaphore.wait()
	return result!
}
