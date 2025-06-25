//
//  Test+Async.swift
//  SwiftCheck
//
//  Created by Igor Ranieri on 25.06.2025.
//  Copyright © 2025 Igor Ranieri. All rights reserved.
//

import Foundation

public func forAll<A>(_ pf: @escaping (A) async throws -> Testable) -> Property where A: Arbitrary {
	return forAllShrink(A.arbitrary, shrinker: A.shrink, f: pf)
}

public func forAll<A, B>(_ pf: @escaping (A, B) async throws -> Testable) -> Property
	where A: Arbitrary, B: Arbitrary
{
	forAll { a in
		forAll { b in
			try await pf(a, b)
		}
	}
}

public func forAll<A, B, C>(_ pf: @escaping (A, B, C) async throws -> Testable) -> Property
	where A: Arbitrary, B: Arbitrary, C: Arbitrary
{
	forAll { a in
		forAll { b, c in
			try await pf(a, b, c)
		}
	}
}

public func forAll<A, B, C, D>(_ pf: @escaping (A, B, C, D) async throws -> Testable) -> Property
where A: Arbitrary, B: Arbitrary, C: Arbitrary, D: Arbitrary
{
	forAll { a in
		forAll { b, c, d in
			try await pf(a, b, c, d)
		}
	}
}

public func forAll<A, B, C, D, E>(_ pf: @escaping (A, B, C, D, E) async throws -> Testable) -> Property
	where A: Arbitrary, B: Arbitrary, C: Arbitrary, D: Arbitrary, E: Arbitrary
{
	forAll { a in
		forAll { b, c, d, e in
			try await pf(a, b, c, d, e)
		}
	}
}

public func forAll<A, B, C, D, E, F>(_ pf: @escaping (A, B, C, D, E, F) async throws -> Testable) -> Property
	where A: Arbitrary, B: Arbitrary, C: Arbitrary, D: Arbitrary, E: Arbitrary, F: Arbitrary
{
	forAll { a in
		forAll { b, c, d, e, f in
			try await pf(a, b, c, d, e, f)
		}
	}
}

public func forAll<A, B, C, D, E, F, G>(_ pf: @escaping (A, B, C, D, E, F, G) async throws -> Testable) -> Property
	where A: Arbitrary, B: Arbitrary, C: Arbitrary, D: Arbitrary, E: Arbitrary, F: Arbitrary, G: Arbitrary
{
	forAll { a in
		forAll { b, c, d, e, f, g in
			try await pf(a, b, c, d, e, f, g)
		}
	}
}

public func forAll<A, B, C, D, E, F, G, H>(_ pf: @escaping (A, B, C, D, E, F, G, H) async throws -> Testable) -> Property
	where A: Arbitrary, B: Arbitrary, C: Arbitrary, D: Arbitrary, E: Arbitrary, F: Arbitrary, G: Arbitrary, H: Arbitrary
{
	forAll { a in
		forAll { b, c, d, e, f, g, h in
			try await pf(a, b, c, d, e, f, g, h)
		}
	}
}

public func forAllShrink<A>(_ gen: Gen<A>, shrinker: @escaping (A) -> [A], f: @escaping (A) async throws -> Testable) -> Property {
	Property(gen.flatMap { x in
		shrinking(shrinker, initial: x, prop: { xs in
			runAsyncAndWait {
				do {
					return (try await f(xs)).counterexample(String(describing: xs))
				} catch let e {
					return TestResult.failed("Test case threw an exception: \"\(e)\"").counterexample(String(describing: xs))
				}
			}
		}).unProperty
	}).again
}

private func runAsyncAndWait<T>(_ operation: @Sendable @escaping () async -> T) -> T {
	let semaphore = DispatchSemaphore(value: 0)
	let queue = DispatchQueue(label: "syncResultQueue")
	var result: T!

	Task.detached {
		let value = await operation()
		queue.sync {
			result = value
		}
		semaphore.signal()
	}

	semaphore.wait()

	return queue.sync {
		result
	}
}
