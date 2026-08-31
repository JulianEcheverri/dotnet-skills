# Comments and Documentation

Comments are plain, short, and few. They say **what** the code does, in simple English a beginner
reads. The reasoning, the history, and the decisions live in project documentation, never in the
source.

## Contents

- [Summaries on every top-level type](#summaries-on-every-top-level-type)
- [Style](#style)
- [What a comment must never contain](#what-a-comment-must-never-contain)
- [Abstract code says nothing about concrete values](#abstract-code-says-nothing-about-concrete-values)
- [Logging is documentation too](#logging-is-documentation-too)
- [READMEs and public documents](#readmes-and-public-documents)
- [Commits and pull requests](#commits-and-pull-requests)

## Summaries on every top-level type

Every class, record, and interface carries a `/// <summary>` — one or two lines saying what it is.
Members and inline notes use `//`.

```csharp
/// <summary>Sends a completion score to the platform's grade endpoint.</summary>
public sealed class GradeSender : IGradeSender
{
    // Signs the assertion the token endpoint expects.
    private static string SignClientAssertion(...) { }
}
```

When a class implements an already-documented interface, the class summary describes **the
implementation** (how), not the contract (what) — the interface already said that.

## Style

- **Simple words.** "creates", not "mints". "returns", not "yields". "only one call at a time", not
  "single-flight". "temporary", not "interim".
- **One or two lines.** A comment longer than two lines is a document in the wrong place.
- **Say what, not why.** Reasoning belongs in the design document or the pull request.
- **Drop comments on obvious code.** `// increments the counter` above `count++` is noise.
- **Define an acronym the first time it appears** in a file, if it is not universal.
- **English only.** All code, identifiers, comments, and commit messages are in English, regardless
  of the team's spoken language.
- **No emoji, no emoticons, anywhere in code or comments.**

## What a comment must never contain

| Banned in source | Where it belongs |
|---|---|
| A reference to a workspace document or a design doc filename | The document itself |
| A ticket number or issue id | The pull request or the tracker |
| A test plan, or "see step 3 of the manual test" | The test document |
| A dated note ("changed 2026-05-01 because…") | Version control history |
| Industry rationale, links to blog posts, standards citations | The README or the decision record |
| Non-English text | Nowhere — code is English |
| Meta-language about the code's organization ("the family's result", "this slice's pattern") | Say what the member does |

Source must be self-contained: a reader with only the repository, and no access to the team's
documents, understands every comment.

## Abstract code says nothing about concrete values

In a generic, abstract, or shared type, a comment must not mention a specific value from the
domain it happens to serve today.

```csharp
// WRONG: pins one status into an abstract vocabulary.
/// <summary>The 502 body the endpoint returns.</summary>

// RIGHT
/// <summary>The error response body.</summary>
```

The concrete value lives in the code that chooses it, not in the comment of the type that carries
it.

## Logging is documentation too

- The application pipeline is **Serilog**, consumed only through `ILogger<T>`: no class depends on
  a Serilog type, and libraries reference only the logging abstractions, so the pipeline stays an
  application-root decision.
- Plain `logger.Log*()` calls. No source-generated logger message attributes, no `IsEnabled`
  guards; suppress the analyzer that asks for them.
- Structured properties, never string concatenation.
- **Never log a secret**: no tokens, no client secrets, no OIDC `state` or `nonce`, no passwords,
  no full authorization headers.
- Log the non-sensitive context that identifies the operation: issuer, subject, resource id, HTTP
  status, and the rule that failed.
- **Every validation rejection logs a warning** naming the failed rule and the received value.
- A failure that matters to operations (a grade not submitted, a payment not captured) is the one
  log line that must always exist: information on success, error on failure, with structured fields.
- Avoid property names your log pipeline reserves or remaps; check the pipeline's conventions before
  inventing a field name.

## READMEs and public documents

A repository README is a formal product document read by people outside the team. It follows the
standard structure: title and one-paragraph description, features, tech stack, prerequisites,
getting started, available scripts, configuration, repository structure, architecture overview,
testing, CI/CD, deployment, license.

Never in a README: internal notes, ticket numbers, temporary status ("currently a mock", "only dev
exists today"), implementation asides, or conversational phrasing ("we", "just", "not an if
chain"). Write third person, present tense, so a newcomer can clone and run in minutes.

The same discipline applies to design documents: clean narrative, written as if drafted straight to
final. No version notes about the document itself, no description of how the information was
obtained, no correction trails. Spell out every acronym on first use.

## Commits and pull requests

- Commit messages and pull request titles follow `type(scope): description` — `feat`, `fix`,
  `refactor`, `test`, `chore`, `docs`.
- The message says **what** the change does; the reasoning and the context go in the pull request
  description, not in the commit body and never in the code.
- One concern per commit where practical; a commit that mixes a feature with an unrelated cleanup
  hides both in the history.
