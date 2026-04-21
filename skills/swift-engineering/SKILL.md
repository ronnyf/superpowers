---
name: swift-engineering
description: Use when writing, reviewing, planning, or architecting Swift code for Apple platforms — invoke during plan writing for Swift features, concurrency design, and API surface decisions
---

# Swift Engineering

Swift 6 best practices for Apple platform development. Follow these when writing code; verify these when reviewing code.

## Swift 6 Strict Concurrency

Every decision must account for data isolation. This is non-negotiable:

- **Actors** for shared mutable state. Prefer over classes with locks or queues.
- **Structured concurrency**: `TaskGroup`, `async let`. Avoid unstructured `Task {}` unless escaping a synchronous context.
- **@TaskLocal** for dependency injection into task hierarchies.
  - Propagation rules: structured child tasks (`async let`, `TaskGroup`) inherit via **parent link** (live read). Unstructured `Task {}` inherits via **deep copy** (snapshot at creation). `Task.detached` inherits **nothing**.
  - **Ordering matters:** when using `withValue` to inject state for a framework API, the API call must happen **inside** `withValue`. Frameworks may create internal tasks at call time that inherit the `@TaskLocal` from the calling context — setting `withValue` only around iteration is insufficient.
  - Never assert `@TaskLocal` propagation from reasoning alone — write a test.
- **Sendable**: All types crossing isolation boundaries must conform. Prefer value types (structs, enums).
  - `some AsyncSequence` is not `Sendable`. To iterate one inside a `Task`, use `withTaskCancellationHandler` — its `operation` closure is not `@Sendable`, providing a legal capture scope for non-Sendable types.
  - `sending` parameters transfer exclusive ownership across isolation boundaries. Prefer over `@unchecked Sendable`.
- **NEVER use `nonisolated(unsafe)`** — find alternative designs (actors, protocols with Sendable constraints, restructure ownership).
- **@MainActor**: Only for UI-bound code. Not a convenience escape hatch.
- **@concurrent nonisolated**: For methods that can safely run on any executor without isolation.
- **Typed throws** (`throws(MyError)`): Use for precise, exhaustive error handling at API boundaries.
- **consuming / borrowing**: Apply parameter ownership modifiers on performance-critical paths.
- **~Copyable**: Use non-copyable types when ownership semantics enforce correctness.
- **Mutex / OSAllocatedUnfairLock**: For synchronous critical sections when actors are too heavyweight.
- **AsyncSequence / AsyncStream**: For streaming data. Prefer over callback/delegate patterns.
- **Continuations**: Bridge callback-based APIs to async/await. Always resume exactly once.

## Type System — Leverage Fully

Use the type system to catch errors at compile time, not runtime:

- **Parameter packs** (`each T`) for variadic generic APIs — prefer over overload sets.
- **Opaque types** (`some Protocol`) when the concrete return type is fixed at the call site.
- **Existentials** (`any Protocol`) only when runtime polymorphism is truly needed. Minimize existential overhead.
- **Conditional conformance** for specialized behavior without type erasure.
- **@resultBuilder** for declarative DSLs and configuration APIs.
- **Attached macros** for eliminating repetitive boilerplate.
- **Phantom types** for compile-time state machines and type-level invariants.
- **Key paths** for functional composition and generic property access.

## SwiftUI

- Appropriate state ownership: `@State` for view-local, `@Binding` for parent-owned, `@Observable`/`@Environment` for shared.
- View body is simple — complex logic extracted to methods or computed properties.
- No unnecessary recomputation (stable identifiers, proper use of `Equatable`).
- Task modifiers (`.task`, `.task(id:)`) for async work tied to view lifecycle.
- No blocking work on MainActor in view code.

## Protocol-Oriented Design

- Composition over inheritance. Protocols over base classes.
- Protocol extensions provide sensible defaults without surprising behavior.
- Associated types and conditional conformance used over type erasure.
- Protocols are minimal — don't bundle unrelated requirements.

## Architecture

- `package` access for framework-internal APIs. `public` only for the true external surface.
- Closure-based configuration (static let closures) over subclassing or delegation.
- Single source of truth for state. Derive everything else.

## Code Quality

- **os.log**: Structured logging with subsystem and category.
- **Error handling**: Throw on invariant violations. Never silently return empty results for errors.

## Testing

- **Swift Testing** framework (`@Test`, `#expect`, `#require`) — NOT XCTest (except performance tests).
- Async tests use proper patterns (no `XCTestExpectation` workarounds).
- Tests verify behavior, not implementation details.
- Edge cases and error paths covered.
