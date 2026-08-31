# Copilot instruction templates for a consuming repository

Two ways to make GitHub Copilot apply the standard without being asked. Use one or both.

## Option 1: repository-wide instructions

Copy the block below into `.github/copilot-instructions.md`. It applies to every chat request in
that repository. Keep instructions short and self-contained — that is what the format rewards.

---

```markdown
# Copilot instructions

## C# and .NET work

Use the `dotnet-engineering` skill for every C# and .NET task: writing or refactoring code,
designing a model or an API, reviewing changes, writing tests, and diagnosing performance or
configuration problems. Read its references instead of recalling a library's API from memory.

- Model each valid state as its own sealed record; put per-state behavior on the state as an
  abstract member rather than in a central switch.
- Parse untyped input into strong types once, at the boundary; do not re-validate downstream.
- Give every domain concept a value object with a private constructor and a static TryParse that
  returns null for refused input. Do not throw to reject ordinary external input.
- Return discriminated unions for operations with more than one outcome. Never a success flag with
  a nullable payload, and never null for a known failure.
- Make error responses typed problem objects with real properties, not dictionaries of extensions.
- Justify every nullable as boundary input or real domain absence; anything else is a bug. Never
  default a required value away.
- Organize code in vertical slices: one folder per feature owning its endpoint, DTOs, settings,
  model and dependency-injection registration. One type per file. Namespace matches folder.
- Register every type with behavior behind an interface; name the implementation after the
  interface minus the I, and the injected variable after that, camelCased.
- Write one- or two-line comments that say what the code does, a summary on every top-level type,
  in English, with no links, ticket numbers, dates or emoji.
- Treat warnings as errors: fix the code, never add a pragma or a NoWarn entry.
- Use the fixed toolbox: xUnit with plain Assert, hand-rolled fakes then Moq, Serilog behind
  ILogger, Central Package Management, Minimal APIs by default (follow an existing project's
  controllers). Never add MediatR, reflection mappers, result-type or guard-clause libraries, or
  FluentValidation for domain rules.
- Write tests for transformations whose silent failure causes real damage. Never skip a test,
  suppress a warning, or add a sleep to make a test pass.
```

---

## Option 2: instructions scoped to C# files

Create `.github/instructions/dotnet.instructions.md`. The `applyTo` glob limits the instructions to
the files they concern, which keeps them out of unrelated requests.

---

```markdown
---
applyTo: "**/*.cs"
---

Follow the `dotnet-engineering` skill for all C# in this repository.

- Make invalid states unrepresentable: one sealed record per valid state, behavior as an abstract
  member on the state.
- Parse, don't validate: strong types at the boundary, no re-validation downstream.
- Value objects with private constructors and TryParse; raw primitives only in wire DTOs.
- Discriminated-union results with typed causes; typed problem objects on the wire.
- Nullable means boundary input or real domain absence, nothing else.
- Vertical slices, one type per file, namespace matching folder, interfaces for everything with
  behavior.
- Warnings are errors: fix the code, never suppress.
- Short plain-English comments, a summary on every top-level type, no emoji.
```

---

## Notes

- Instructions are additive: personal instructions, repository instructions and the skill all apply
  together, with the more specific ones taking priority when they conflict.
- Instructions are always in context; a skill loads only when relevant. Keep the instruction file
  short and let the skill carry the detail.
