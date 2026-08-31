# Testing

Tests exist to catch a silent bug that would cause real damage. Coverage is not a goal, and a test
that only restates the implementation is worse than no test: it must be maintained forever and
proves nothing.

## Contents

- [What a test is for](#what-a-test-is-for)
- [Do not test](#do-not-test)
- [Do test](#do-test)
- [Test tooling](#test-tooling)
- [When tests are written](#when-tests-are-written)
- [One test class per class](#one-test-class-per-class)
- [Naming and structure](#naming-and-structure)
- [Fakes and mocks](#fakes-and-mocks)
- [Integration tests](#integration-tests)
- [Architecture tests](#architecture-tests)
- [Coverage is not a gate](#coverage-is-not-a-gate)
- [Never disable a test](#never-disable-a-test)
- [Cross-platform behavior](#cross-platform-behavior)

## What a test is for

Two questions decide whether a test is worth writing:

1. **If this breaks silently, what does it cost?** A wrong score payload, a mis-signed token, a
   dropped record — write the test. A misspelled log message — do not.
2. **Am I testing observable behavior or an implementation detail?** Test the behavior a caller
   depends on. A test bound to private structure breaks on every refactor and protects nothing.

A good test is valuable on four axes at once: it catches real regressions, it survives refactoring
that does not change behavior, it fails fast, and it is easy to read. A test that scores zero on
"resistance to refactoring" is a liability regardless of what it covers.

## Do not test

- That the cache stores what you told it to store.
- That an HTTP client mock returns the response the mock was given.
- That token validation succeeds with a key you generated in the test.
- A trivial mapping, a `ToString()`, an auto-property.
- That a health endpoint returns 200.
- Private methods. If a private method needs a test, it wants to be a public pure function on its
  own type.

## Do test

Data transformations where a silent bug causes real damage:

- Payload construction sent to an external system — casing, number vs string, id format.
- Signed message claims: exact claim names, nested shapes, values echoed verbatim.
- Mode or state derivation from input data (the rule that decides which record you build).
- Extraction of values from tokens, headers, and claims — a path typo is invisible until production.
- URL construction: parameter presence, order, and encoding.
- Merge and precedence rules (deduplication, which source wins a collision).
- Value-object parsing: what is accepted and, above all, what is rejected.
- Serialization contracts a client depends on — pin the wire shape, including casing.
- Concurrency primitives: one fetch under concurrent callers, fallback while a value is still valid.

## Test tooling

Fixed choices, from [tooling.md](tooling.md):

- **Framework: xUnit** — v3 for new projects.
- **Assertions: xUnit's built-in `Assert`.** It needs no dependency and no justification. An
  existing project's assertion library wins over the default; never add FluentAssertions 8 or
  later to a commercial project — its license changed. Where a fluent style is already
  established, version 7 or its open forks are the acceptable forms.
- **Doubles: hand-rolled `Fake*` first, Moq when a configured mock reads clearer** than a fake.
  One mocking library per codebase, never two.

## When tests are written

Unit tests are written **at the end**, once the endpoints and the model are settled — not
feature-by-feature while the shape is still moving. Writing them early against a shape that
changes twice produces tests that were rewritten twice and proved nothing.

This is a house preference about **timing**, not about value: the test suite that ships is
thorough. When the design is already fixed (a bug fix, a well-understood algorithm), writing the
test first is fine.

## One test class per class

Each test class maps 1:1 to the class it tests: `{Class}Tests`, in a folder mirroring the source
tree. The summary's first words name the class under test:

```csharp
/// <summary>
/// Tests GradeSender — the score payload: a wrong shape is silently accepted by the
/// platform and the grade never lands.
/// </summary>
public class GradeSenderTests
```

A test file named after a source **file** rather than a class is wrong: split it, one class per
subject.

## Naming and structure

- `Method_Scenario_ExpectedOutcome`, or a plain sentence that reads as the guarantee:
  `BuildCatalog_KeepsTheSectionMedia_WhenBothOriginsHaveTheSameId`.
- Arrange / act / assert, in that order, without ceremony comments when the shape is obvious.
- One behavior per test. A test asserting five unrelated things fails without telling you which
  guarantee broke.
- Use `record` builders and `with` expressions for variations instead of many constructors.
- Prefer real value objects and real domain types in tests; do not weaken the model for testability.

## Fakes and mocks

- Mocking libraries are allowed; **Moq is the standard one** when a mock is the clearer tool. The
  rule is "no real network or real infrastructure in a unit test", never "no mocking library".
- Hand-rolled fakes are preferred where they read better than configured mocks — an HTTP message
  handler is the classic case.
- Test helper names must be self-evident and use the `Fake` prefix: `FakeHttpMessageHandler`,
  `FakeHttpClientFactory`, `FakeClock`. A name like `RecordingHttpMessageHandler` is rejected — the
  reader should not have to guess.
- A fake HTTP handler answers each request with the next queued response and **keeps every request
  it was given**, so tests assert the exact URL, headers, and body that went out.
- Assert on what the outside world receives, not on how many times an internal method ran.

## Integration tests

Use real infrastructure in containers rather than mocks when the thing under test **is** the
integration: the database query, the migration, the queue round-trip. Keep them in a separate
project so the unit suite stays fast. Patterns:
[../library/testcontainers/README.md](../library/testcontainers/README.md),
[../library/aspire-integration-testing/README.md](../library/aspire-integration-testing/README.md).

Snapshot testing is the right tool for rendered output and public API surfaces — it makes an
unintended change a reviewable diff:
[../library/snapshot-testing/README.md](../library/snapshot-testing/README.md).

## Architecture tests

Structural rules that only live in a document get broken politely and repeatedly. Enforce them in
the test suite with NetArchTest.Rules or ArchUnitNET, so a violation is a red build instead of a
review comment:

- Namespaces match folders and slices do not reach into each other's internals.
- Types with behavior are consumed through interfaces.
- Banned libraries (see [tooling.md](tooling.md)) are referenced nowhere.
- Wire DTO namespaces do not leak into the domain model.

A handful of these tests is enough; they run in milliseconds and never flake.

## Coverage is not a gate

**No coverage-percentage threshold in the build.** A percentage gate is a target, and targets get
gamed with tests that assert nothing. The doctrine already says what must be tested — the
transformations whose silent failure causes damage — and that judgment does not reduce to a
number.

Coverage data is still useful as a **map**: change-risk analysis (complexity × uncovered paths)
points at the code most dangerous to touch, which is where the next test belongs. Use
[../library/crap-analysis/README.md](../library/crap-analysis/README.md) to prioritize, never to
pass or fail a build.

## Never disable a test

A failing or flaky test is a signal. Never:

- add `Skip = "flaky"`,
- comment a test out,
- add a sleep until it passes,
- suppress the warning it exposes,
- swallow the exception in an empty `catch`.

Fix the race, the ordering, or the design. If a test must be temporarily disabled for a deliberate,
time-boxed reason, the skip reason names the switch that will re-enable it and the change is
reverted in the same follow-up. Automated detection of these shortcuts:
[../library/slopwatch/README.md](../library/slopwatch/README.md).

## Cross-platform behavior

The build and the runtime are often not the developer's machine. Behavior that differs by platform
must be pinned by a test.

The canonical example, worth internalizing: `Uri.TryCreate("/some/path", UriKind.Absolute, out _)`
**fails on Windows and succeeds on Linux** as a `file:///` URI. Code that accepted a bare path
silently kept working locally and only failed later, at request time, in production.

Rule: every `Uri.TryCreate(..., UriKind.Absolute, ...)` is paired with an explicit scheme check.

```csharp
if (!Uri.TryCreate(value, UriKind.Absolute, out var uri) || uri.Scheme != Uri.UriSchemeHttps)
    return null;
```

The same discipline applies to path separators, case-sensitive file systems, culture-sensitive
formatting (always `InvariantCulture` for machine-readable output), and time zones (`DateTimeOffset`
and UTC for anything stored or transmitted).
