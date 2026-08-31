# AGENTS.md

Guidance for AI coding agents working **in this repository**. This is a knowledge repository: there
is no build, no tests, and no compiled output. `CLAUDE.md` mirrors this file.

## What this repository is

A single Agent Skill, `skills/dotnet-engineering`, that carries a personal C# and .NET engineering
standard plus a bundled reference library for the .NET ecosystem. It follows the Agent Skills open
format (agentskills.io) so one folder works across Claude Code, GitHub Copilot, Codex and other
skills-compatible agents.

## Layout

```
skills/dotnet-engineering/
├── SKILL.md                    # the standard + the reference map. Under 500 lines.
└── references/
    ├── doctrine/               # original: the standard in depth. Edit freely.
    ├── library/                # adapted upstream. Do not rewrite; see below.
    └── specialists/            # adapted upstream diagnostic playbooks.
```

## Rules for editing

1. **`SKILL.md` and `references/doctrine/` are the standard.** A rule appears in both: one or two
   sentences in `SKILL.md`, the explanation and examples in the matching doctrine file. Change both
   together or neither.
2. **`references/library/` and `references/specialists/` are adapted from an upstream project and
   are kept as received.** Do not rewrite them to match the doctrine. When they disagree, record the
   resolution in `references/doctrine/precedence.md`. This keeps the library refreshable from
   upstream and keeps the disagreements visible instead of silently edited away.
3. **Exactly one `SKILL.md` exists in the repository.** Files inside `references/library/` are named
   `README.md` so no client registers them as separate skills.
4. **Every reference is reachable in one hop** from the map in `SKILL.md`. Adding a reference means
   adding a row to that map.
5. **Frontmatter limits:** `name` matches the folder name, 64 characters maximum, lowercase letters,
   numbers and hyphens only. `description` is 1024 characters maximum, third person, and states both
   what the skill does and when to use it. No angle brackets in either field.
6. **Forward slashes in every path**, including on Windows.
7. **No time-sensitive statements** in the rules. Version facts belong in
   `references/doctrine/csharp-baseline.md`, with superseded guidance under its "old patterns"
   section.
8. **Prose style:** third person, present tense, no emoji, no internal notes, no dated commentary,
   no meta-narration about how the document was produced.

## After any change

```powershell
./scripts/validate.ps1
```

It checks the frontmatter fields and limits, the folder/name match, the `SKILL.md` line count, and
every internal link in the skill.

## Git

Do not commit, push, or open pull requests. Report the change and stop; the repository owner
performs all git write operations.
