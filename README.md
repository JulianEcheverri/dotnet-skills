# dotnet-skills

A personal engineering standard for C# and .NET, packaged as an Agent Skill. It teaches an AI
coding assistant to write, review and structure .NET code the way this codebase is written: strong
domain modeling, parse-don't-validate boundaries, discriminated-union results, typed error
responses, vertical slices, and a strict set of naming, comment and testing rules — with a complete
reference library for the wider .NET ecosystem bundled alongside it.

The skill follows the [Agent Skills](https://agentskills.io) open format, so the same folder works
in Claude Code, GitHub Copilot (VS Code, CLI and cloud agent), Codex, Cursor, OpenCode and any other
skills-compatible agent.

## Contents

- [What is inside](#what-is-inside)
- [Installation](#installation)
- [Usage](#usage)
- [Repository structure](#repository-structure)
- [Customizing the standard](#customizing-the-standard)
- [Design of the skill](#design-of-the-skill)
- [Credits](#credits)
- [License](#license)

## What is inside

One skill, `dotnet-engineering`, organized for progressive disclosure: the agent loads a short
metadata line at startup, reads `SKILL.md` when a .NET task appears, and opens a reference file only
when the task needs it.

| Layer | Purpose |
|---|---|
| `SKILL.md` | The standard in sixteen non-negotiable rules, patterns to copy, and a map to every reference |
| `references/doctrine/` | The standard in depth: modeling, results and errors, nullability, naming, structure, comments, testing, integration, tooling policy, language baseline, precedence, review checklist |
| `references/library/` | Thirty-six technology references: C# language, API design, concurrency, Akka.NET, .NET Aspire, EF Core, database performance, OpenTelemetry, serialization, R3, Testcontainers, Playwright, packaging, quality gates and more |
| `references/specialists/` | Six deep diagnostic playbooks: concurrency, performance, benchmarks, Akka.NET, Roslyn generators, DocFX |

The doctrine takes precedence over the library. Every known disagreement between them is listed and
resolved in `references/doctrine/precedence.md`.

## Installation

Clone the repository first:

```bash
git clone <this-repository-url> dotnet-skills
```

### Claude Code

Install as a plugin from the local checkout:

```
/plugin marketplace add /path/to/dotnet-skills
/plugin install dotnet-engineering
```

This registers the skill and the six specialist subagents. Alternatively, copy the skill folder
directly:

```bash
# Project scope
cp -r dotnet-skills/skills/dotnet-engineering .claude/skills/

# User scope, available in every project
cp -r dotnet-skills/skills/dotnet-engineering ~/.claude/skills/
```

### GitHub Copilot in VS Code

Requires a VS Code version with Agent Skills support (1.108 or later). Three options:

**Point VS Code at the checkout (no copying).** Add to your settings:

```json
{
  "chat.agentSkillsLocations": ["/path/to/dotnet-skills/skills"]
}
```

**Per repository**, so the whole team gets it:

```bash
mkdir -p .github/skills
cp -r /path/to/dotnet-skills/skills/dotnet-engineering .github/skills/
```

**For your user account**, available in every workspace:

```bash
mkdir -p ~/.copilot/skills
cp -r /path/to/dotnet-skills/skills/dotnet-engineering ~/.copilot/skills/
```

Copilot discovers the skill from its `name` and `description` and applies it automatically on .NET
work; you can also invoke it explicitly by typing `/dotnet-engineering` in the chat input.

**One copy for both assistants.** VS Code reads workspace skills from `.github/skills/`,
`.claude/skills/` and `.agents/skills/` alike, and Claude Code reads `.claude/skills/`. Installing
once into `.claude/skills/` therefore serves Claude Code and Copilot in the same repository.

### Other agents

| Agent | Location |
|---|---|
| GitHub Copilot CLI and cloud agent | `.github/skills/` in the repository |
| Codex | `.agents/skills/` in the repository, or the user-level skills directory |
| Cursor, OpenCode, Amp, Gemini CLI and others | The skills directory documented by that agent; the folder is unchanged |

An install helper is provided for convenience:

```powershell
# Windows
./scripts/install.ps1 -Target claude-project -Path C:\path\to\your\repo
./scripts/install.ps1 -Target copilot-project -Path C:\path\to\your\repo
./scripts/install.ps1 -Target claude-user
./scripts/install.ps1 -Target copilot-user
```

```bash
# macOS and Linux
./scripts/install.sh claude-project /path/to/your/repo
./scripts/install.sh copilot-project /path/to/your/repo
./scripts/install.sh claude-user
./scripts/install.sh copilot-user
```

## Usage

Once installed the skill activates on its own whenever the conversation involves C#, .NET, ASP.NET
Core, Minimal APIs, Blazor, NuGet or a .NET project file. To force it, name it:

```
/dotnet-engineering review this pull request
/dotnet-engineering design the model for the payments feature
```

Useful prompts:

- "Model this feature following the standard, then show me the types before the implementation."
- "Review this file against the checklist and rank the findings by severity."
- "This result type uses a success flag — convert it to the house union shape."
- "Which reference covers query splitting in EF Core?"

To make an agent apply the standard to every request in one repository without naming it, copy the
router snippet from `templates/AGENTS.md` into that repository's `AGENTS.md`, or
`templates/copilot-instructions.md` into its `.github/copilot-instructions.md`.

## Repository structure

```
dotnet-skills/
├── .claude-plugin/
│   ├── plugin.json              # Claude Code plugin manifest
│   └── marketplace.json         # Claude Code marketplace entry
├── skills/
│   └── dotnet-engineering/
│       ├── SKILL.md             # The standard and the reference map
│       └── references/
│           ├── doctrine/        # The standard in depth
│           ├── library/         # Technology references
│           └── specialists/     # Diagnostic playbooks
├── scripts/
│   ├── install.ps1
│   ├── install.sh
│   └── validate.ps1             # Frontmatter, size and link checks
├── templates/
│   ├── AGENTS.md                # Router snippet for a consuming repository
│   └── copilot-instructions.md  # Same, for .github/copilot-instructions.md
├── AGENTS.md                    # Guidance for agents working in this repository
├── NOTICE.md                    # Attribution for adapted content
└── README.md
```

## Customizing the standard

The doctrine is meant to be edited — it is a personal standard, not a framework.

1. Change a rule in `SKILL.md` and in the matching file under `references/doctrine/`. Keep both in
   sync: `SKILL.md` states the rule in one or two sentences, the doctrine file explains and shows it.
2. If the change contradicts something in `references/library/`, record the resolution in
   `references/doctrine/precedence.md` rather than editing the library file. The library is kept as
   received so it can be refreshed from upstream.
3. Keep `SKILL.md` under 500 lines and the `description` under 1024 characters; run
   `./scripts/validate.ps1` to check both, along with every internal link.

Adding a technology reference: create `references/library/<topic>/README.md` and add one row to the
reference map in `SKILL.md`. Every reference must be reachable in one hop from `SKILL.md`.

## Design of the skill

The layout follows the Agent Skills specification and Anthropic's authoring guidance:

- **Progressive disclosure in three stages** — name and description at startup, `SKILL.md` on
  activation, reference files on demand. Large references cost nothing until they are read.
- **A description that states what it does and when to use it**, in the third person, carrying the
  keywords that should trigger it.
- **`SKILL.md` under 500 lines**, with detail pushed into references.
- **References one level deep**, all listed in the map, so the agent never has to follow a chain.
- **Tables of contents in long references**, so a partial read still shows the full scope.
- **Forward slashes everywhere**, no Windows-style paths.
- **No time-sensitive statements** in the rules; version facts live in one file
  (`references/doctrine/csharp-baseline.md`) with an "old patterns" section for what they replaced.

## Credits

The standard follows the functional-modeling school of **Zoran Horvat**, the vertical-slice and
Minimal API practice of **Milan Jovanović**, and the testing philosophy of **Vladimir Khorikov**.

`references/library/` and `references/specialists/` are adapted from
[dotnet-skills](https://github.com/Aaronontheweb/dotnet-skills) by **Aaron Stannard**, used under
the MIT License. See `NOTICE.md` for details and for the changes made.

## License

MIT. See `LICENSE`.
