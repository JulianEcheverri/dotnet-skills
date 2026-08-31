# C# and .NET Baseline

The language level this doctrine assumes, the features that carry it, and what changes when the
next version lands. Verify the current SDK with `dotnet --list-sdks` and the project's
`global.json` before assuming a language version.

## Contents

- [Baseline](#baseline)
- [Features this doctrine depends on](#features-this-doctrine-depends-on)
- [C# 14 additions worth using](#c-14-additions-worth-using)
- [Style rules](#style-rules)
- [Native unions are coming](#native-unions-are-coming)
- [Async rules](#async-rules)
- [Time](#time)
- [Performance defaults](#performance-defaults)
- [Old patterns](#old-patterns)

## Baseline

| Item | Position |
|---|---|
| Target framework | The current long-term-support release; .NET 10 (LTS, November 2025) at the time of writing |
| Language version | `latest`; C# 14 ships with .NET 10 |
| Nullable | `enable`, everywhere, no exceptions |
| Warnings | `TreatWarningsAsErrors` on — a warning stops the build and is fixed in the code, never suppressed |
| Analyzers | `AnalysisLevel` at `latest-recommended`; CA1852 as error — see [tooling.md](tooling.md) |
| Implicit usings | `enable` |
| Namespaces | File-scoped |
| SDK | Pinned in `global.json` with `rollForward: latestFeature` |
| Solution file | `.slnx` |

`.NET 11` (short-term support, C# 15) reaches general availability in November 2026. Adopt it for
applications when it ships and the dependency set has caught up; libraries with a broad audience
stay on the long-term-support target.

## Features this doctrine depends on

**Records** for every immutable model: domain states, wire DTOs, result unions, value objects.
`with` expressions replace copy constructors and hand-written builders.

**Pattern matching** as the way to consume a union — positional patterns, property patterns,
relational and logical patterns, list patterns:

```csharp
if (result is TokenResult.Unavailable(var cause))
    return Problem(cause);

var band = temperature switch
{
    < 0 => Band.Freezing,
    >= 0 and < 20 => Band.Cold,
    _ => Band.Warm
};
```

**`required` members** for a model that must be fully initialized by an object initializer:

```csharp
public sealed class PaymentsApiSettings
{
    public required string BaseUrl { get; init; }
    public required string ClientId { get; init; }
}
```

**Primary constructors** for services with injected dependencies. Add a private field only when a
value is reused; otherwise use the parameter directly.

```csharp
public sealed class CatalogService(ICatalogProvider catalogProvider, ILogger<CatalogService> logger)
```

**Collection expressions** for every collection literal: `[]`, `[a, b, c]`, and spreads
`[.. first, .. second]`. They replace `Array.Empty<T>()`, `new List<T> { … }`, and `Enumerable.Concat`
chains in most code.

**`sealed` by default** on classes and records that are not designed for inheritance.

## C# 14 additions worth using

- **`field` keyword** — a property accessor can use its compiler-provided backing field without
  declaring one. The compiler applies null-resilience analysis, so a lazily initialized property no
  longer triggers a spurious uninitialized-member warning.

  ```csharp
  public string DisplayName => field ??= BuildDisplayName();
  ```

- **Extension members** — the extension block form declares extension properties and static members,
  not just methods. Use it to extend a type you do not own; do not use it to hide a dependency.

- **Null-conditional assignment** — `customer?.Order = BuildOrder();` evaluates the right-hand side
  only when the receiver is non-null.

- **Implicit `Span<T>` conversions**, `nameof` over unbound generics, and lambda parameter modifiers
  (`ref`, `in`, `out`) without explicit types.

## Style rules

- **`var`**: prefer it when the type is apparent from the right-hand side (a `new` expression, a
  cast, a factory named after the type, a literal). Spell the type when the right side does not
  reveal it. Never let `var` hide a type the reader would have to hunt for.
- **Expression-bodied members**: use them for members that are genuinely one expression — computed
  properties, one-line delegating methods and constructors. The moment a member needs branching or
  a second statement, it gets a block body; squeezing logic into an expression to keep the arrow
  violates the readable-conditionals rule.
- **Primary constructors are mandatory** for services with injected dependencies, not merely
  preferred. A field is declared only when the value is reused (`_settings = options.Value`);
  otherwise the parameter is used directly.
- **Global usings**: `ImplicitUsings` plus, at most, one deliberate `GlobalUsings.cs` per project
  for namespaces used in effectively every file. Never use a global using to hide a dependency a
  reader would want to see at the top of the file.
- **Sealing is enforced by the build**: CA1852 runs as an error, so internal types that can be
  sealed must be. Public types stay sealed by the doctrine and the review checklist.

## Native unions are coming

C# 15 introduces real discriminated unions: a closed set of case types with exhaustive pattern
matching checked by the compiler, composing types you already have rather than declaring new inline
shapes. They shipped first in a .NET 11 preview behind `<LangVersion>preview</LangVersion>`.

This does not change the modeling in this doctrine — it is the same design with less ceremony:

- Today: `abstract record` with a private constructor and `sealed record` cases.
- Then: the same case records declared as a union, with exhaustiveness enforced by the compiler
  instead of by the private-constructor trick and code review.

Write hierarchies now the way [domain-modeling.md](domain-modeling.md) describes and the migration
is mechanical. Do not adopt a third-party union library in the meantime: it adds a dependency to
express something the language is about to provide, and its ergonomics will not match the final
syntax.

## Async rules

- Every method that does I/O is `async`, ends in `Async`, and takes a `CancellationToken`.
- Pass the token to **every** call that accepts one, including the ones in `finally`-adjacent
  cleanup paths that support it.
- Never block on async: no `.Result`, no `.Wait()`, no `.GetAwaiter().GetResult()`.
- `ConfigureAwait(false)` in library code; unnecessary in application code on modern ASP.NET Core.
- `ValueTask` only for a hot path that usually completes synchronously; await it once, never twice.
- Streaming results use `IAsyncEnumerable<T>` with `[EnumeratorCancellation]`.

## Time

- **`DateTimeOffset`, in UTC, for everything stored or transmitted.** `DateTime` appears only at
  the presentation edge, converting for display. Machine-readable formatting always uses the
  invariant culture and a round-trip format.
- **`TimeProvider` is injected wherever code reads the clock or waits.** A bare `DateTime.UtcNow`,
  `DateTimeOffset.UtcNow`, `Task.Delay`, or `new Timer` in logic is a review finding: it makes the
  behavior untestable without real waiting. Tests drive time with a fake provider.
- A type that stamps times takes `TimeProvider` in its constructor; a static pure function that
  needs "now" takes it as a parameter.

## Performance defaults

Apply these when they cost nothing; reach for the deeper ones only with a measurement:

- `sealed` classes let the runtime devirtualize calls.
- `readonly record struct` for small value types avoids allocation and defensive copies.
- Accept the least specific type you need (`IEnumerable<T>` to iterate, `IReadOnlyList<T>` to index)
  and return an immutable view (`IReadOnlyList<T>`) from public APIs.
- Materialize once: one `ToList()` at the end of a query chain, not between every operator.
- `FrozenDictionary`/`FrozenSet` for lookup tables built once at startup.
- `Span<T>`/`ReadOnlySpan<T>` for synchronous buffer work, `Memory<T>` across `await`, `ArrayPool<T>`
  for large temporary buffers.
- Measure before optimizing: a benchmark, not an opinion. See
  [../library/csharp-type-design-performance/README.md](../library/csharp-type-design-performance/README.md)
  and [../specialists/dotnet-benchmark-designer.md](../specialists/dotnet-benchmark-designer.md).

## Old patterns

<details>
<summary>Patterns replaced by the baseline above</summary>

- `class` with settable properties for a DTO → `record`.
- `Array.Empty<T>()` / `new List<T>()` initializers → collection expressions.
- Explicit backing fields for lazily initialized properties → the `field` keyword.
- Hand-rolled `Result<T, TError>` generic libraries → a domain-specific result union per operation.
- Reflection-based object mappers → explicit mapping extension methods.
- `BinaryFormatter`, and reflection-driven polymorphic JSON with type names in the payload →
  schema-based serialization with explicit discriminators.
- Blocking wrappers around async methods → async all the way.

</details>
