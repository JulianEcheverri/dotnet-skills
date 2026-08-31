# Precedence: Doctrine over Library

`SKILL.md` and `references/doctrine/` are the standard. `references/library/` and
`references/specialists/` are an excellent, broad .NET reference adapted from an upstream
collection, and they are kept whole — including the places where they disagree with the doctrine.

**When they disagree, the doctrine wins.** This file lists every known disagreement, the reason,
and what to write instead. If you find a new one, resolve it the same way and add it here.

## Contents

- [Value objects reject, they do not throw](#value-objects-reject-they-do-not-throw)
- [Result types are unions, not flags](#result-types-are-unions-not-flags)
- [Error responses are typed objects](#error-responses-are-typed-objects)
- [Not-found is a result, not an exception](#not-found-is-a-result-not-an-exception)
- [Local functions](#local-functions)
- [Abstract base classes](#abstract-base-classes)
- [Struct or class for a value object](#struct-or-class-for-a-value-object)
- [Extend-only design applies to published libraries](#extend-only-design-applies-to-published-libraries)
- [Comment density](#comment-density)
- [Assertion libraries](#assertion-libraries)
- [Where the library is authoritative](#where-the-library-is-authoritative)

## Value objects reject, they do not throw

The library shows value objects whose constructor throws `ArgumentException` on invalid input.

**Doctrine:** a value object has a private constructor and a static `TryParse`/`TryFrom` that
returns `null` for input it refuses. The caller converts that null into a typed rejection at the
parse site.

**Why:** input that arrives every day from outside the process is not exceptional. Throwing turns a
routine rejection into a stack unwind, hides the failure from the type system, and pushes callers
into `try/catch` around construction. Returning the option makes the rejection a value the caller
must handle, which is the entire point of parse-don't-validate.

**Exception:** a value constructed only from data the process itself produced, where an invalid
value is a programming bug, may throw — that is a genuine invariant violation.

## Result types are unions, not flags

The library models an operation result as a record with `IsSuccess`, a nullable payload, a nullable
error code, and a nullable message.

**Doctrine:** a discriminated union of records. `bool` + nullable payload is explicitly banned.

**Why:** the flag shape makes the invalid state representable (`IsSuccess = true` with a null
payload, or a failure with no code), forces `!` at every use, and cannot be exhaustively matched.
The union removes all three problems.

```csharp
// Library shape — do not write this.
public sealed record CreateOrderResult
{
    public bool IsSuccess { get; init; }
    public Order? Order { get; init; }
    public OrderErrorCode? ErrorCode { get; init; }
}

// Doctrine shape.
public abstract record CreateOrderResult
{
    private CreateOrderResult() { }
    public sealed record Created(Order Order) : CreateOrderResult;
    public sealed record Rejected(ErrorCause Cause) : CreateOrderResult;
}
```

The library is right that a **domain-specific** result beats a generic `Result<T, TError>`; the
doctrine keeps that and fixes the shape.

## Error responses are typed objects

The library maps a result to an action result by switching on an enum error code inside the service.

**Doctrine:** mapping to HTTP happens in the endpoint, the body is a `ProblemDetails` subclass with
strong properties, and the failure vocabulary is a polymorphic union that owns its own wire words.
No extensions dictionary, no `_ => throw` arm. See [errors-and-results.md](errors-and-results.md).

## Not-found is a result, not an exception

Several library data-access examples throw for an absent row (`?? throw new NotFoundException(...)`
after a lookup) or define write stores that "return void or throw".

**Doctrine:** an absent entity is an expected outcome, so it comes back as a value the caller must
handle — a `NotFound` case on the operation's result union, or `null` from a `TryGet`-shaped
lookup that the caller converts immediately. Exceptions stay reserved for programming bugs and
infrastructure faults. The library's query mechanics (projection, tracking, batching, limits)
are unaffected — only the reporting shape changes.

## Local functions

The library recommends async **local functions** over `Task.Run(async () => ...)` lambdas and
`ContinueWith` chains, and several actor examples define them inside message handlers.

**Doctrine:** the underlying advice stands — never an anonymous async lambda fired into the void,
never `ContinueWith` for sequencing — but the extraction target is a **private method**, not a
local function. Local functions are banned: they bury a named unit of work inside another method's
body where it cannot be seen in the type's outline or ordered by the reading-order rule. Every
benefit the library lists (readable stack traces, clean exception handling, testability) is kept
or improved by a private method; captured state becomes explicit parameters.

```csharp
// Library shape — do not write this.
private void HandleSync(StartSync command)
{
    async Task<SyncResult> PerformSyncAsync() { ... }
    PerformSyncAsync().PipeTo(Self);
}

// Doctrine shape.
private void HandleSync(StartSync command) =>
    PerformSyncAsync(command.EntityId).PipeTo(Self);

private async Task<SyncResult> PerformSyncAsync(EntityId entityId) { ... }
```

## Abstract base classes

The library says to avoid abstract base classes and use composition.

**Doctrine:** agrees as the default — with two deliberate exceptions:

1. **A closed hierarchy that models states** (the whole point of
   [domain-modeling.md](domain-modeling.md)) is an abstract record with sealed cases. That is
   modeling, not inheritance for reuse.
2. **One shared algorithm implemented once** (the token cache) may be an abstract base class,
   provided it is always registered and consumed **behind an interface** so it stays substitutable.

Inheritance for code reuse across unrelated services remains banned.

## Struct or class for a value object

The library says value objects are *always* `readonly record struct`.

**Doctrine:** both are legal; choose deliberately. `readonly record struct` for small values in hot
paths; `sealed record` class when the type participates in the model as a possibly-absent reference,
holds more than a couple of fields, or when `default(T)` bypassing the smart constructor would be a
trap. The smart-constructor rule is identical either way.

## Extend-only design applies to published libraries

The library's API-design guidance (never change a signature, add overloads, deprecate for years) is
correct for a package with external consumers.

**Doctrine:** for an internal service that owns both sides of its contract, a change is a
**replacement**, made in the smallest conceptual diff — one name for one concept, no parallel
"v2" field kept alongside the old one out of habit. Apply extend-only when there is a real external
consumer with its own release schedule; apply replacement when there is not.

## Comment density

Several library examples carry multi-line explanatory comments and rationale inside code blocks.

**Doctrine:** one or two lines, what not why, no links, no dated notes, no ticket ids, no emoji. See
[comments-and-docs.md](comments-and-docs.md). Read the library's comments as teaching material for
the reader of the reference file — not as a model for production source.

## Assertion libraries

Library test examples use FluentAssertions' `.Should()` syntax.

**Doctrine:** the standard is xUnit's built-in `Assert` (see [tooling.md](tooling.md)).
FluentAssertions moved to a paid license for commercial use starting with version 8 and is never
added to a commercial project; version 7 and its API-compatible open forks remain acceptable where
a fluent style is already established, and an existing project's assertion library wins over the
default. Read the library's `.Should()` examples as behavior documentation, not as a tooling
instruction.

## Where the library is authoritative

On everything the doctrine does not speak to, the library is the reference and should be followed:
actor systems, Aspire orchestration, OpenTelemetry instrumentation, EF Core and database
performance, serialization formats, reactive extensions, Playwright, containers for integration
tests, packaging, decompilation, certificate trust, and the specialist playbooks. Read those files
directly; they are detailed and specific.
