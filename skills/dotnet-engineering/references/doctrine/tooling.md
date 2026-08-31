# Tooling and Library Policy

Fixed choices, so no project re-litigates them. Two principles frame everything below:

1. **Defaults bend to the project.** These are the choices for new code and new projects. An
   existing codebase's established, working choice wins — read the project before adding a tool,
   and never introduce a second tool for a job one already covers.
2. **Bans do not bend.** A banned library is not added anywhere, including legacy code. If a
   legacy project already uses one, do not extend its usage — and do not rip it out as a side
   effect of an unrelated task.

## Contents

- [The standard toolbox](#the-standard-toolbox)
- [Banned libraries](#banned-libraries)
- [Analyzers](#analyzers)
- [Choosing a dependency](#choosing-a-dependency)

## The standard toolbox

| Concern | Standard | Notes |
|---|---|---|
| Test framework | xUnit — v3 for new projects | See [testing.md](testing.md) |
| Assertions | xUnit's built-in `Assert` | An existing project's assertion library wins; never add FluentAssertions 8+ to a commercial project — its license changed |
| Test doubles | Hand-rolled `Fake*` first; Moq when a configured mock reads clearer | See [testing.md](testing.md) |
| Logging pipeline | Serilog, consumed only through `ILogger<T>` | No class depends on Serilog types; libraries reference only the logging abstractions |
| HTTP APIs | Minimal APIs by default | A project built on controllers keeps controllers — never mix both styles in one service; see [structure.md](structure.md) |
| API versioning | `Asp.Versioning` on public HTTP APIs | Internal service-to-service contracts use replacement, not versioning |
| API reference | Built-in OpenAPI generation + Scalar as the UI | Metadata on the endpoints, never comments |
| Package versions | Central Package Management — mandatory for every new solution | Legacy solutions migrate incrementally, not big-bang |
| Data access | EF Core for writes and straightforward queries; Dapper for complex reads and reporting | Both may coexist in one service; see [../library/database-performance/README.md](../library/database-performance/README.md) |
| Serialization | System.Text.Json with source generators; schema-based formats (Protobuf, MessagePack) across process boundaries | See [../library/serialization/README.md](../library/serialization/README.md) |
| Validation | Parse boundaries and smart constructors for domain input; DataAnnotations only on options POCOs | No parallel validation framework — the type already proves what a validator would re-check |
| Time | `TimeProvider` injected wherever code reads the clock or waits | See [csharp-baseline.md](csharp-baseline.md) |
| Containers | Multi-stage build, chiseled or distroless base image, non-root user | Test projects are never copied into the image |
| Commits | `type(scope): description` — feat, fix, refactor, test, chore, docs | The what in the message; the why in the pull request |

## Banned libraries

| Library | Why | Use instead |
|---|---|---|
| MediatR | An in-process bus that hides the call graph behind reflection-discovered handlers; its newest majors are also commercially licensed | The endpoint handler calls its providers directly |
| AutoMapper, Mapster, any reflection mapper | Compile-time safety traded for runtime failures; newest AutoMapper majors are also commercially licensed | Explicit mapping extension methods |
| OneOf, ErrorOr, FluentResults, LanguageExt | Generic shapes for what must be a domain-specific union; native unions are arriving in the language | Hand-written result unions per operation |
| Ardalis.GuardClauses and similar | The guard IS the smart constructor; a guard library scatters validation away from the type | `TryParse`/`TryFrom` plus door checks |
| FluentValidation | A parallel validation layer that re-checks what parse-don't-validate already proved, and pulls domain rules out of the domain | Smart constructors and parse factories; DataAnnotations for options |
| FluentAssertions 8+ | Commercial license for commercial use | xUnit `Assert`; version 7 or its open forks where a fluent style already exists |
| BinaryFormatter | Insecure, removed | Schema-based serialization |

## Analyzers

- `AnalysisLevel` set to `latest-recommended` in `Directory.Build.props`. Combined with
  warnings-as-errors, the rules actually bite.
- **CA1852 (seal internal types) elevated to error** — sealing is enforced by the build for
  internal types; public types stay sealed by doctrine and review.
- A rule that produces ceremony without value is disabled in `.editorconfig` with
  `severity = none` — a visible, reviewable decision, never a pragma in the code.

## Choosing a dependency

Before adding any package, in order:

1. Is it on the banned list? Stop.
2. Does the standard toolbox already cover the job? Use the standard.
3. Does the project already use something for this job? Use that.
4. Does the language or the BCL cover it? A dependency that saves ten lines is not worth its
   supply chain, its license risk, and its upgrade treadmill.
5. Only then evaluate the package: license (and the license of its next major), maintenance,
   transitive weight — and pin its version through Central Package Management.
