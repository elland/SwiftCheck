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

// MARK: - forAll { }

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
			let capturedF = f
			let capturedXs = xs

			let result: Result<SendableTestable, Error> = runAsyncAndWait {
				do {
					return .success(try await capturedF(capturedXs))
				} catch let e {
					return .failure(e)
				}
				
			}

			switch result {
			case .success(let testResult):
				return testResult.counterexample(String(describing: capturedXs))
			case .failure(let e):
				return TestResult.failed("Test case threw an exception: \"\(e)\"").counterexample(String(describing: xs))
			}
		}).unProperty
	}).again
}

// MARK: - forAll(Gen) { }

public func forAll<A>(_ gen: Gen<A>, pf: @Sendable @escaping (A) async throws -> SendableTestable) -> Property
where A : SendableArbitrary
{
	return forAllShrink(gen, shrinker: A.shrink, f: pf)
}

public func forAll<A, B>(_ genA: Gen<A>, _ genB: Gen<B>, pf:  @Sendable @escaping (A, B) async throws -> SendableTestable) -> Property
where A : SendableArbitrary, B : SendableArbitrary
{
	forAll(genA, pf: { t in
		forAll(genB, pf: { b in
			try await pf(t, b)
		})
	})
}

public func forAll<A, B, C>(_ genA: Gen<A>, _ genB: Gen<B>, _ genC: Gen<C>, pf: @Sendable @escaping (A, B, C) async throws -> SendableTestable) -> Property
where A : SendableArbitrary, B : SendableArbitrary, C : SendableArbitrary
{
	forAll(genA, pf: { t in
		forAll(genB, genC, pf: { b, c in
			try await pf(t, b, c)
		})
	})
}

public func forAll<A, B, C, D>(_ genA: Gen<A>, _ genB: Gen<B>, _ genC: Gen<C>, _ genD: Gen<D>, pf: @Sendable @escaping (A, B, C, D) async throws -> SendableTestable) -> Property
where A : SendableArbitrary, B : SendableArbitrary, C : SendableArbitrary, D : SendableArbitrary
{
	forAll(genA, pf: { t in
		forAll(genB, genC, genD, pf: { b, c, d in
			try await pf(t, b, c, d)
		})
	})
}

public func forAll<A, B, C, D, E>(_ genA: Gen<A>, _ genB: Gen<B>, _ genC: Gen<C>, _ genD: Gen<D>, _ genE: Gen<E>, pf: @Sendable @escaping (A, B, C, D, E) async throws -> SendableTestable) -> Property
where A : SendableArbitrary, B : SendableArbitrary, C : SendableArbitrary, D : SendableArbitrary, E : SendableArbitrary
{
	forAll(genA, pf: { t in
		forAll(genB, genC, genD, genE, pf: { b, c, d, e in
			try await pf(t, b, c, d, e)
		})
	})
}

public func forAll<A, B, C, D, E, F>(_ genA: Gen<A>, _ genB: Gen<B>, _ genC: Gen<C>, _ genD: Gen<D>, _ genE: Gen<E>, _ genF: Gen<F>, pf: @Sendable @escaping (A, B, C, D, E, F) async throws -> SendableTestable) -> Property
where A : SendableArbitrary, B : SendableArbitrary, C : SendableArbitrary, D : SendableArbitrary, E : SendableArbitrary, F : SendableArbitrary
{
	forAll(genA, pf: { t in
		forAll(genB, genC, genD, genE, genF, pf: { b, c, d, e, f in
			try await pf(t, b, c, d, e, f)
		})
	})
}

public func forAll<A, B, C, D, E, F, G>(_ genA: Gen<A>, _ genB: Gen<B>, _ genC: Gen<C>, _ genD: Gen<D>, _ genE: Gen<E>, _ genF: Gen<F>, _ genG: Gen<G>, pf: @Sendable @escaping (A, B, C, D, E, F, G) async throws -> SendableTestable) -> Property
where A : SendableArbitrary, B : SendableArbitrary, C : SendableArbitrary, D : SendableArbitrary, E : SendableArbitrary, F : SendableArbitrary, G : SendableArbitrary
{
	forAll(genA, pf: { t in
		forAll(genB, genC, genD, genE, genF, genG, pf: { b, c, d, e, f, g in
			try await pf(t, b, c, d, e, f, g)
		})
	})
}

public func forAll<A, B, C, D, E, F, G, H>(_ genA: Gen<A>, _ genB: Gen<B>, _ genC: Gen<C>, _ genD: Gen<D>, _ genE: Gen<E>, _ genF: Gen<F>, _ genG: Gen<G>, _ genH: Gen<H>, pf: @Sendable @escaping (A, B, C, D, E, F, G, H) async throws -> SendableTestable) -> Property
where A : SendableArbitrary, B : SendableArbitrary, C : SendableArbitrary, D : SendableArbitrary, E : SendableArbitrary, F : SendableArbitrary, G : SendableArbitrary, H : SendableArbitrary
{
	forAll(genA, pf: { t in
		forAll(genB, genC, genD, genE, genF, genG, genH, pf: { b, c, d, e, f, g, h in
			try await pf(t, b, c, d, e, f, g, h)
		})
	})
}

// MARK: - Helper

final class SyncBox<T: Sendable>: @unchecked Sendable {
	private var value: T
	private let queue = DispatchQueue(label: "SyncBox", attributes: .concurrent)

	init(_ value: T) {
		self.value = value
	}

	func get() -> T {
		self.queue.sync {
			self.value
		}
	}

	func set(_ newValue: T) {
		self.queue.async(flags: .barrier) {
			self.value = newValue
		}
	}

	func setSync(_ newValue: T) {
		self.queue.sync(flags: .barrier) { self.value = newValue }
	}

	func modify(_ transform: @Sendable @escaping (inout T) -> Void) {
		self.queue.async(flags: .barrier) {
			transform(&self.value)
		}
	}
}

// TODO: This can somehow still crash sometimes. Swift Concurrency feels broken here.
private func runAsyncAndWait<T: Sendable>(_ operation: @Sendable @escaping () async -> T) -> T {
	if Thread.isMainThread {
		return DispatchQueue.global(qos: .userInitiated).sync {
			runAsyncAndWait(operation)
		}
	}

	let semaphore = DispatchSemaphore(value: 0)
	let resultBox = SyncBox<T?>(nil)

	Task.detached {
		let opResult = await operation()
		resultBox.setSync(opResult)
		semaphore.signal()
	}

	semaphore.wait()

	guard let result = resultBox.get() else {
		fatalError("Operation failed, deallocated too soon?")
	}

	return result
}
