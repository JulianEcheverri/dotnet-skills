# Notice

## Adapted content

The technology references under `skills/dotnet-engineering/references/library/` and the diagnostic
playbooks under `skills/dotnet-engineering/references/specialists/` are adapted from:

**dotnet-skills** — https://github.com/Aaronontheweb/dotnet-skills
Copyright (c) 2025 Aaron Stannard
Licensed under the MIT License.

The upstream collection is a marketplace of thirty-six .NET skills and six specialist agents. This
repository merges it into a single Agent Skill so that one installation covers both the personal
engineering standard and the wider .NET reference material.

### Changes made

1. **Relocated.** Each upstream skill folder became a reference folder under `references/library/`,
   and each upstream agent file became a playbook under `references/specialists/`. No content was
   dropped: every skill and every agent from the upstream collection is present.
2. **Renamed entry files.** `SKILL.md` inside each upstream skill folder became `README.md`, so the
   merged skill exposes exactly one `SKILL.md` and no client registers phantom skills. The original
   YAML frontmatter is preserved inside each file.
3. **Corrected one folder name.** `opentelementry-dotnet-instrumentation` became
   `opentelemetry-instrumentation`; the file content is unchanged.
4. **Added a provenance banner** at the top of every adapted file, pointing back to this notice and
   recording that the doctrine takes precedence.
5. **Recorded conflicts rather than editing them away.** Where the upstream guidance disagrees with
   the standard in `references/doctrine/`, the upstream text is left intact and the resolution is
   documented in `references/doctrine/precedence.md`.

Nothing else in the adapted files was modified.

## Original content

`skills/dotnet-engineering/SKILL.md`, everything under
`skills/dotnet-engineering/references/doctrine/`, and the repository documentation, templates and
scripts are original work, Copyright (c) 2026 Julian Echeverri, MIT licensed.

## Influences

The standard draws on publicly published work by:

- **Zoran Horvat** — functional modeling in C#: make invalid states unrepresentable, parse don't
  validate, smart constructors, discriminated unions modeled with records.
- **Milan Jovanović** — vertical slice architecture, Minimal API composition, result-based endpoint
  design in modern .NET.
- **Vladimir Khorikov** — unit testing principles: observable behavior over implementation details,
  and the four pillars of a valuable test.

These are influences on the rules, not sources of copied text.

## Trademarks

.NET, ASP.NET Core, Visual Studio Code and GitHub Copilot are trademarks of Microsoft Corporation.
Claude and Claude Code are trademarks of Anthropic. Akka.NET is a trademark of Petabridge. This
project is not affiliated with, endorsed by, or sponsored by any of them.
