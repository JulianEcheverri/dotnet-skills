# Router snippet for a consuming repository

Copy the block below into the `AGENTS.md` (or `CLAUDE.md`) of a repository where the
`dotnet-engineering` skill is installed. It tells the agent to apply the standard on every .NET
task instead of waiting to be asked.

Trim it to what the repository actually uses — a repository with no Akka.NET does not need the Akka
routing line.

---

```markdown
## .NET engineering standard

Apply the `dotnet-engineering` skill to every C# and .NET task in this repository: writing code,
refactoring, designing a model or an API, reviewing changes, writing tests, and diagnosing
performance or configuration problems. Prefer its references over recalled knowledge for any
library API.

Workflow: grep the source for an existing type or pattern to reuse, model the types before the
control flow, write the smallest change that matches the surrounding style, then self-review
against the skill's review checklist.

Non-negotiables, in short:
- One sealed record per valid state; behavior as an abstract member, never a central switch.
- Parse at the boundary into a strong type; downstream never re-validates.
- Value objects with a private constructor and TryParse; no throwing to reject external input.
- Outcomes are discriminated unions with typed causes; never a success flag plus a nullable payload.
- Error responses are typed problem objects; endpoints map failures, they never invent them.
- Every nullable is boundary input or real domain absence; anything else is a bug.
- Vertical slices; one type per file; namespace matches folder.
- Interfaces for everything with behavior; implementation named after the interface minus the I.
- Comments: one or two plain lines saying what, a summary on every top-level type.
- Warnings are errors: fix the code, never add a pragma or a NoWarn entry.
- Fixed toolbox: xUnit + plain Assert, fakes then Moq, Serilog via ILogger, Central Package
  Management, Minimal APIs by default (a codebase on controllers keeps controllers). Banned:
  MediatR, reflection mappers, result-type and guard-clause libraries, FluentValidation for
  domain rules.
- Tests prove value, not coverage; never skip or sleep-pad a test.

Routing inside the skill:
- Modeling, results, nullability, naming, structure, comments, testing, integration → references/doctrine/
- C# language, API design, concurrency, performance → references/library/csharp-*
- Data access → references/library/efcore-patterns, references/library/database-performance
- Aspire and web → references/library/aspire-*, references/library/mjml-email-templates
- Akka.NET → references/library/akka-*
- Testing tooling → references/library/testcontainers, snapshot-testing, playwright-*
- Quality gates → references/library/slopwatch, references/library/crap-analysis
- Deep diagnostics → references/specialists/
```
