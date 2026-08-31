---
name: dotnet-engineering
description: Writes, reviews and structures C# and .NET code to a strict engineering standard - strong domain modeling (make invalid states unrepresentable, parse don't validate), value objects with smart constructors, discriminated-union results, typed error responses, vertical-slice structure, interface-based dependency injection, and house rules for naming, comments and tests. Bundles a full .NET reference library covering Akka.NET, .NET Aspire, EF Core and database performance, OpenTelemetry, Testcontainers, Playwright, serialization, R3, project structure, packaging and quality gates. Use for any C#, .NET, ASP.NET Core, Minimal API, Blazor or NuGet task - writing or refactoring code, designing a model or an API, reviewing a pull request, choosing an abstraction, setting up a solution, writing tests, or diagnosing performance, concurrency and configuration problems.
license: MIT
metadata:
  version: "1.0.0"
  influences: "Zoran Horvat, Milan Jovanovic, Vladimir Khorikov, Aaron Stannard"
---

# .NET Engineering Standard

The standard this codebase is written to, plus a reference library for the wider .NET ecosystem.
Apply it to every C# file you write or review. It is opinionated on purpose: the rules below were
each adopted after the alternative was tried and rejected.

## How to work

1. **Read before writing.** Read the repository's own conventions, then grep the source for an
   existing value object, result union, provider, or registration that already solves the problem.
   Reuse beats reinvention; verification beats assumption.
2. **Model first.** Decide the types before the control flow. Most of the code disappears once the
   model is right.
3. **Write the smallest change that fits the house style** and reads like the file around it.
4. **Route to a reference** when the task touches a specific technology — the map is below. Read the
   file; do not answer from memory about a library's API.
5. **Self-review** against [references/doctrine/review-checklist.md](references/doctrine/review-checklist.md)
   before reporting the work done.

Where this file and a library reference disagree, this file wins. Known conflicts and their
resolutions: [references/doctrine/precedence.md](references/doctrine/precedence.md).

## The non-negotiables

### 1. Make invalid states unrepresentable

One `sealed record` per valid state, carrying exactly what that state requires. No wide type with
nullable fields and a derived mode. What varies per state is an **abstract member on the state**,
never a central `switch` or a chain of ternaries — a new case must not be able to compile silently.

### 2. Parse, don't validate

Loose input becomes a strong type once, at the boundary, in a factory that returns the parsed model
or a typed rejection naming the failed rule. Downstream never re-checks: holding the type is the
proof. Structural validation belongs in the parser; cryptographic or remote verification stays a
separate thin component that hands back the already-parsed type.

### 3. Every id and domain concept is a value object

Private constructor plus static `TryParse`/`TryFrom` returning `null` for refused input. **No
throwing** to reject ordinary external input. The caller turns that null into a rejection at the
parse site. No implicit conversions. Raw primitives appear only in wire DTOs, at serialization.

### 4. Outcomes are discriminated unions

Never `bool IsValid` plus a nullable payload. Never `null` or a magic string for a known failure.
An `abstract record` with a private constructor and `sealed record` cases; the caller pattern-matches.
Failure cases carry a typed cause. Union names end in `Result`.

### 5. Errors are typed all the way to the wire

The failure vocabulary is a polymorphic union that owns its own wire words, so a new case cannot
compile without them. The response body is a `ProblemDetails` subclass with real properties — never
a dictionary of extensions, never a builder class. Endpoints **map** a failure they received; they
never fabricate another module's case. Full downstream detail stays in logs.

### 6. Nullable means one of exactly three things

Boundary raw input (dies at the first parse), real domain absence with a consumer that handles it,
or a bug. `?? string.Empty` on a required value is a bug. A nullable that can never be null is a lie.
Collections are never nullable — absent binds as empty.

### 7. Vertical slices

One folder per feature owning its endpoint, DTOs, settings, model and DI registration
(`Add{Feature}()`). Never `Services/`, `Models/`, `Repositories/` as top-level folders; concept
subfolders inside a slice are encouraged. Promote to `Shared/` or `Infrastructure/` only when a
second consumer appears. One type per file. Namespace matches folder.

### 8. Interfaces for everything with behavior

`services.AddSingleton<IFoo, Foo>()`, consumers depend on the interface. The implementation is named
after the interface minus the `I`; the injected variable is that name camelCased. Data and options
POCOs are exempt.

### 9. Names say what a thing is or does

`RequestAccessTokenAsync`, not `GetToken`. `ScoresUrl(...)`, not `Url`. A value-object-typed property
is named after the value object. Peer types share a role suffix. A family prefix (the folder name)
goes on every type, config section and client name in that family. No abbreviations.

### 10. Comments are plain, short and few

A `/// <summary>` on every top-level type; `//` for members. One or two lines, simple English,
saying **what**. No rationale, no document or ticket references, no dates, no links, no emoji, no
non-English text, and no concrete domain values inside an abstract type's comments.

### 11. Tests prove value, not coverage

Test what causes real damage when it breaks silently: payload shapes, claim extraction, state
derivation, merge and precedence rules, parsing rejections, wire contracts, concurrency primitives.
Do not test the framework, a mock's own configuration, or a trivial mapping. One test class per
class. Fakes are prefixed `Fake`. Never skip, comment out, or sleep-pad a test.

### 12. Method hygiene

Methods are verbs. Do not extract a one-line method used once. Define members in reading order:
public first, then privates in call order. No local functions. An early return beats a compound
ternary.

### 13. Fail fast on configuration, never on user input

Options bound, validated and `ValidateOnStart()` — missing configuration crashes at boot.
`TreatWarningsAsErrors` is on — a warning stops the build and is fixed in the code, never
suppressed; a useless analyzer rule is disabled deliberately in `.editorconfig`, not pragma'd
around. Selecting behavior at runtime from what is really deployment configuration is banned.
Ordinary bad input gets a typed rejection, not an exception.

### 14. Security defaults are not optional

Pin the token algorithm; validate issuer, audience and expiry. Pair every absolute-URI parse with a
scheme check. Never log or commit a secret. Bound the resilience budget on user-facing paths so a
dead dependency cannot hold a request open.

### 15. Delete instead of deferring

A field without a consumer, a constant nobody reads, a mock left "for now", a commented-out real
call — all are removed before the work is called done. Ask "does this have a consumer?" before
asking "required or optional?".

### 16. The toolbox is fixed

xUnit with plain `Assert`, hand-rolled fakes then Moq, Serilog behind `ILogger<T>`, Central Package
Management, EF Core for writes with Dapper for complex reads, Minimal APIs by default. Banned:
MediatR, reflection mappers, result-type libraries, guard-clause libraries, FluentValidation for
domain rules, FluentAssertions 8+. Defaults bend to an existing project's established choice — a
codebase on controllers keeps controllers — but bans hold for new additions everywhere. See
[references/doctrine/tooling.md](references/doctrine/tooling.md).

## Patterns to copy

```csharp
// Value object: private ctor + smart constructor. No throw, no implicit conversions.
public sealed record SectionId
{
    private SectionId(long value) => Value = value;

    public long Value { get; }

    public static SectionId? TryParse(string? text) =>
        long.TryParse(text, out var value) && value > 0 ? new SectionId(value) : null;
}
```

```csharp
// Result union: closed set, typed failure, matched by the caller.
public abstract record CatalogResult
{
    private CatalogResult() { }

    public sealed record Found(IReadOnlyList<CatalogItem> Items) : CatalogResult;

    public sealed record Unavailable(ErrorCause Cause) : CatalogResult;
}

var result = await catalogProvider.FindAsync(sectionId, cancellationToken);
if (result is CatalogResult.Unavailable(var cause))
    return Results.Problem(new ErrorProblem("Catalog unavailable", ErrorSource.Catalog, cause));

var items = ((CatalogResult.Found)result).Items;
```

```csharp
// States as records; behavior as an abstract member, never a central switch.
public abstract record Launch(SubjectId Subject)
{
    public abstract string Mode { get; }
}

public sealed record StudentLaunch(SubjectId Subject, GradeEndpoint GradeEndpoint) : Launch(Subject)
{
    public override string Mode => "student";
}

public sealed record PreviewLaunch(SubjectId Subject) : Launch(Subject)
{
    public override string Mode => "preview";
}
```

```csharp
// Boundary: parse once, reject at the door with the failed rule named.
var subject = SubjectId.TryParse(claims.GetString("sub"));
if (subject is null)
{
    logger.LogWarning("Launch rejected: no usable subject claim");
    return new LaunchResult.Invalid("launch without a subject");
}
```

## Reference map

Read the file that matches the task. Every path is relative to this skill.

### Doctrine — the standard itself

| Read when | File |
|---|---|
| Designing types, states, value objects, or changing a model | [references/doctrine/domain-modeling.md](references/doctrine/domain-modeling.md) |
| Returning outcomes, mapping failures, designing an error body | [references/doctrine/errors-and-results.md](references/doctrine/errors-and-results.md) |
| Any `?`, guard clause, or `!` decision | [references/doctrine/nullability.md](references/doctrine/nullability.md) |
| Naming anything; method layout and conditionals | [references/doctrine/naming.md](references/doctrine/naming.md) |
| Folders, slices, DI wiring, endpoints, solution layout | [references/doctrine/structure.md](references/doctrine/structure.md) |
| Writing comments, summaries, READMEs, log messages | [references/doctrine/comments-and-docs.md](references/doctrine/comments-and-docs.md) |
| Deciding what to test and how | [references/doctrine/testing.md](references/doctrine/testing.md) |
| Calling another service: clients, tokens, resilience, security | [references/doctrine/integration.md](references/doctrine/integration.md) |
| Choosing or adding a tool, framework, or package | [references/doctrine/tooling.md](references/doctrine/tooling.md) |
| Language level, C# 14 features, style rules, time, native unions | [references/doctrine/csharp-baseline.md](references/doctrine/csharp-baseline.md) |
| A library reference contradicts the doctrine | [references/doctrine/precedence.md](references/doctrine/precedence.md) |
| Finishing or reviewing a change | [references/doctrine/review-checklist.md](references/doctrine/review-checklist.md) |

### Library — C# language and API

| Topic | File |
|---|---|
| Records, pattern matching, async, spans, modern C# baseline | [references/library/csharp-coding-standards/README.md](references/library/csharp-coding-standards/README.md) |
| Value object and pattern-matching examples | [references/library/csharp-coding-standards/value-objects-and-patterns.md](references/library/csharp-coding-standards/value-objects-and-patterns.md) |
| Composition over inheritance, result and testing examples | [references/library/csharp-coding-standards/composition-and-error-handling.md](references/library/csharp-coding-standards/composition-and-error-handling.md) |
| Zero-allocation buffers and accept/return type choices | [references/library/csharp-coding-standards/performance-and-api-design.md](references/library/csharp-coding-standards/performance-and-api-design.md) |
| Reflection avoidance, banned mappers, `UnsafeAccessor` | [references/library/csharp-coding-standards/anti-patterns-and-reflection.md](references/library/csharp-coding-standards/anti-patterns-and-reflection.md) |
| Nullable attribute catalog and NRT migration | [references/library/csharp-nullable-reference-types/README.md](references/library/csharp-nullable-reference-types/README.md) |
| Public API compatibility, versioning, approval tests | [references/library/csharp-api-design/README.md](references/library/csharp-api-design/README.md) |
| Sealing, structs, collections, deferred enumeration | [references/library/csharp-type-design-performance/README.md](references/library/csharp-type-design-performance/README.md) |
| Choosing async, channels, locks or actors | [references/library/csharp-concurrency-patterns/README.md](references/library/csharp-concurrency-patterns/README.md) |
| Reactive streams with R3 | [references/library/r3-reactive-extensions/README.md](references/library/r3-reactive-extensions/README.md) |

### Library — application platform

| Topic | File |
|---|---|
| Solution layout, build props, SourceLink, versioning | [references/library/project-structure/README.md](references/library/project-structure/README.md) |
| Central package management and the dotnet CLI | [references/library/package-management/README.md](references/library/package-management/README.md) |
| Local tool manifests | [references/library/local-tools/README.md](references/library/local-tools/README.md) |
| Options pattern, validation, environment configuration | [references/library/microsoft-extensions-configuration/README.md](references/library/microsoft-extensions-configuration/README.md) |
| Service registration extensions, scopes, keyed services | [references/library/microsoft-extensions-dependency-injection/README.md](references/library/microsoft-extensions-dependency-injection/README.md) |
| Serialization format choice, source generators, AOT | [references/library/serialization/README.md](references/library/serialization/README.md) |
| Tracing, metrics, logs and naming conventions | [references/library/opentelemetry-instrumentation/README.md](references/library/opentelemetry-instrumentation/README.md) |
| HTTPS dev certificate trust on Linux and WSL | [references/library/dotnet-devcert-trust/README.md](references/library/dotnet-devcert-trust/README.md) |
| Decompiling an assembly to see how an API really works | [references/library/ilspy-decompile/README.md](references/library/ilspy-decompile/README.md) |

### Library — data

| Topic | File |
|---|---|
| EF Core configuration, migrations, query pitfalls | [references/library/efcore-patterns/README.md](references/library/efcore-patterns/README.md) |
| Read/write separation, N+1, tracking, row limits | [references/library/database-performance/README.md](references/library/database-performance/README.md) |

### Library — .NET Aspire and web

| Topic | File |
|---|---|
| Shared service defaults project | [references/library/aspire-service-defaults/README.md](references/library/aspire-service-defaults/README.md) |
| AppHost configuration without leaking Aspire into app code | [references/library/aspire-configuration/README.md](references/library/aspire-configuration/README.md) |
| Distributed application integration tests | [references/library/aspire-integration-testing/README.md](references/library/aspire-integration-testing/README.md) |
| Local email capture with Mailpit | [references/library/aspire-mailpit-integration/README.md](references/library/aspire-mailpit-integration/README.md) |
| Responsive email templates with MJML | [references/library/mjml-email-templates/README.md](references/library/mjml-email-templates/README.md) |

### Library — Akka.NET

| Topic | File |
|---|---|
| Supervision, event stream, work distribution, cluster abstractions | [references/library/akka-best-practices/README.md](references/library/akka-best-practices/README.md) |
| Actor tests with the hosting test kit | [references/library/akka-testing-patterns/README.md](references/library/akka-testing-patterns/README.md) |
| Entity actors, sharding, reminders, time provider | [references/library/akka-hosting-actor-patterns/README.md](references/library/akka-hosting-actor-patterns/README.md) |
| Cluster bootstrap, discovery and health checks | [references/library/akka-management/README.md](references/library/akka-management/README.md) |
| Akka.NET with Aspire orchestration | [references/library/akka-aspire-configuration/README.md](references/library/akka-aspire-configuration/README.md) |

### Library — testing and quality gates

| Topic | File |
|---|---|
| Real infrastructure in containers | [references/library/testcontainers/README.md](references/library/testcontainers/README.md) |
| Snapshot and approval testing | [references/library/snapshot-testing/README.md](references/library/snapshot-testing/README.md) |
| Email template snapshots | [references/library/verify-email-snapshots/README.md](references/library/verify-email-snapshots/README.md) |
| Blazor end-to-end tests | [references/library/playwright-blazor/README.md](references/library/playwright-blazor/README.md) |
| Caching browser binaries in CI | [references/library/playwright-ci-caching/README.md](references/library/playwright-ci-caching/README.md) |
| Detecting disabled tests, suppressions and other shortcuts | [references/library/slopwatch/README.md](references/library/slopwatch/README.md) |
| Coverage and change-risk hotspots | [references/library/crap-analysis/README.md](references/library/crap-analysis/README.md) |

### Library — maintaining this skill collection

| Topic | File |
|---|---|
| Publishing and versioning a skill marketplace | [references/library/marketplace-publishing/README.md](references/library/marketplace-publishing/README.md) |
| Router snippets for AGENTS.md and CLAUDE.md | [references/library/skills-index-snippets/README.md](references/library/skills-index-snippets/README.md) |

### Specialist playbooks

Deep diagnostic guides. Read one when the problem is squarely in its domain; in Claude Code they are
also installed as subagents.

| Specialty | File |
|---|---|
| Actor systems, clustering, persistence, streams | [references/specialists/akka-net-specialist.md](references/specialists/akka-net-specialist.md) |
| Threading, async, races, deadlocks | [references/specialists/dotnet-concurrency-specialist.md](references/specialists/dotnet-concurrency-specialist.md) |
| Profiles, benchmark interpretation, regressions | [references/specialists/dotnet-performance-analyst.md](references/specialists/dotnet-performance-analyst.md) |
| Designing benchmarks that measure the right thing | [references/specialists/dotnet-benchmark-designer.md](references/specialists/dotnet-benchmark-designer.md) |
| Roslyn incremental source generators | [references/specialists/roslyn-incremental-generator-specialist.md](references/specialists/roslyn-incremental-generator-specialist.md) |
| API documentation builds with DocFX | [references/specialists/docfx-specialist.md](references/specialists/docfx-specialist.md) |

### Companion files

Deep material that sits inside a topic. Listed here so every file is one hop away.

- **Akka.NET best practices:** [async and cancellation](references/library/akka-best-practices/async-cancellation-patterns.md) · [cluster and local abstractions](references/library/akka-best-practices/cluster-local-abstractions.md) · [work distribution](references/library/akka-best-practices/work-distribution-patterns.md)
- **Akka.NET testing:** [examples](references/library/akka-testing-patterns/examples.md) · [anti-patterns](references/library/akka-testing-patterns/anti-patterns-and-reference.md)
- **Akka.NET management:** [configuration](references/library/akka-management/configuration-reference.md) · [discovery providers](references/library/akka-management/discovery-providers.md)
- **Aspire integration testing:** [advanced patterns](references/library/aspire-integration-testing/advanced-patterns.md) · [CI and tooling](references/library/aspire-integration-testing/ci-and-tooling.md)
- **Nullable reference types:** [attribute catalog](references/library/csharp-nullable-reference-types/nullable-attributes-reference.md) · [migration playbook](references/library/csharp-nullable-reference-types/nrt-migration-playbook-reference.md)
- **Concurrency:** [advanced concurrency](references/library/csharp-concurrency-patterns/advanced-concurrency.md)
- **Configuration and DI:** [configuration advanced patterns](references/library/microsoft-extensions-configuration/advanced-patterns.md) · [DI advanced patterns](references/library/microsoft-extensions-dependency-injection/advanced-patterns.md)
- **OpenTelemetry:** [traces and propagation](references/library/opentelemetry-instrumentation/traces-and-propagation-reference.md) · [metrics and instruments](references/library/opentelemetry-instrumentation/metrics-and-instruments-reference.md) · [SDK, resources and logs](references/library/opentelemetry-instrumentation/sdk-resources-and-logs-reference.md)
- **R3:** [async and integration](references/library/r3-reactive-extensions/async-and-integration-patterns.md) · [scheduling and concurrency](references/library/r3-reactive-extensions/scheduling-and-concurrency.md) · [differences from Rx.NET](references/library/r3-reactive-extensions/rx-net-differences.md)
- **Testcontainers:** [database patterns](references/library/testcontainers/database-patterns.md) · [infrastructure patterns](references/library/testcontainers/infrastructure-patterns.md)

## Task playbooks

**New feature.** Grep for existing pieces to reuse. Create the slice folder. Model the states and
value objects first. Write the parse boundary. Write the endpoint that orchestrates inline and maps
results. Register with `Add{Feature}()`. Add configuration for every environment. Write the tests
that matter. Run the checklist.

**Refactor.** Establish the current behavior with tests before changing it. Keep the model's shape:
the value object stays, the property stays where it is, the name stays. Smallest conceptual diff.

**Code review.** Work through [references/doctrine/review-checklist.md](references/doctrine/review-checklist.md)
in order. Rank findings by severity, state the concrete failure each one causes, cite
[references/doctrine/precedence.md](references/doctrine/precedence.md) for doctrine-versus-library
disputes rather than re-arguing them.

**Performance problem.** Measure first. Read the type-design and database references, then the
performance specialist. Never optimize on an opinion.

**Configuration or startup failure.** Check options validation, environment-specific values, and
whether something is being selected at runtime that should be static deployment configuration.

## Done means done

Build clean with zero warnings (warnings are errors), tests green, no mock or `TODO` left in the
path, configuration present for every environment, documentation updated in the same pass, and an
accurate report of what was verified and what was not.

## Credits

The doctrine follows the functional-modeling school of **Zoran Horvat** (make invalid states
unrepresentable, parse don't validate), the vertical-slice and Minimal API practice of
**Milan Jovanovic**, and the testing philosophy of **Vladimir Khorikov** (test observable behavior,
value the four pillars over coverage). The library and specialist references are adapted from the
`dotnet-skills` collection by **Aaron Stannard** (MIT) — see `NOTICE.md` at the repository root.
