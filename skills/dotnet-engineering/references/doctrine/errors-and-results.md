# Results and Error Responses

How operations report outcomes inside the process, and how failures reach the wire. Both are typed
end to end. Nothing here is optional: these rules exist because every shortcut was tried first and
rejected.

## Contents

- [Result unions](#result-unions)
- [Naming](#naming)
- [Result or exception](#result-or-exception)
- [Typed error responses](#typed-error-responses)
- [The error vocabulary](#the-error-vocabulary)
- [The problem type](#the-problem-type)
- [Endpoints map, they do not invent](#endpoints-map-they-do-not-invent)
- [Smart constructors vs direct construction](#smart-constructors-vs-direct-construction)
- [What never reaches the wire](#what-never-reaches-the-wire)
- [Anti-patterns](#anti-patterns)

## Result unions

An operation with more than one outcome returns a **discriminated union of records**, and the
caller pattern-matches it. Never `bool` + nullable payload, never `null` for a known failure,
never a magic string.

```csharp
/// <summary>The outcome of looking up a section's media ids.</summary>
public abstract record SectionMediaResult
{
    private SectionMediaResult() { }

    public sealed record Found(IReadOnlyList<MediaId> MediaIds) : SectionMediaResult;

    public sealed record Unavailable(ErrorCause Cause) : SectionMediaResult;
}
```

```csharp
var result = await sectionMediaProvider.FindMediaIdsAsync(sectionId, cancellationToken);

if (result is SectionMediaResult.Unavailable(var cause))
    return Results.Problem(new ErrorProblem(UnavailableTitle, ErrorSource.SectionMedia, cause));

var mediaIds = ((SectionMediaResult.Found)result).MediaIds;
```

**Rules:**

- The union is `abstract record` with a **private constructor** so the case set is closed: nobody
  outside the file can add a case.
- Cases are `sealed record` and carry only the data that case has.
- A failure case carries a **typed cause**, not a `string Reason`. A string cannot be mapped,
  matched, or translated.
- Even an internal primitive returns a union when it has two outcomes — a cache read, a token
  fetch. "It is internal" is not a reason to weaken the model.

## Naming

- A result union ends in **`Result`**: `TokenResult`, `GradeResult`, `MediaSearchResult`. A bare
  noun (`MediaSearch`) says nothing about being an outcome.
- The success case is named for what it produced (`Found`, `Fetched`, `Parsed`, `Verified`), not
  `Success`, when a better word exists.
- The failure case is named for the failure shape (`Unavailable`, `Rejected`, `Invalid`,
  `NotFound`), not `Error`.
- Peer types share the same role suffix. Two clients that both fetch data are both `...Provider` —
  never one `Provider` and one `Search`.

## Result or exception

| Situation | Mechanism |
|---|---|
| Expected outcome: validation failed, not found, business rule refused | **Result union** |
| A dependency answered with an error status, or did not answer | **Result union** with a typed cause |
| Programming bug: null argument from our own code, impossible state | **Exception** |
| Infrastructure fault nobody can act on locally | **Exception**, handled by the global handler |

A caller must never learn about an ordinary business outcome by catching. Exceptions are for the
unexpected; the one filtered `try/catch` a component owns lives at its HTTP/IO boundary and
converts a known transport failure into a union case.

## Typed error responses

When a failure reaches the wire, the response body is a **typed object**, built from a closed
vocabulary. Three types, one family, all prefixed `Error`:

| Type | Role |
|---|---|
| `ErrorSource` | Which lookup or step failed. Closed set of named instances. |
| `ErrorCause` | Why it failed, as a polymorphic union that owns its own wire words. |
| `ErrorProblem` | The response body: a `ProblemDetails` subclass with strong properties. |

Prohibited outright:

- `Dictionary<string, object?>` of extensions built inline in an endpoint or a helper. It moves
  failure from compile time to runtime and spreads untyped keys through the codebase.
- A separate "builder" class that assembles the body. The body builds itself; the framework's
  `Results.Problem` is the door.
- The word `Dependency` in any of these names.

## The error vocabulary

`ErrorSource` is a closed set built with a private constructor and static instances:

```csharp
/// <summary>A lookup as error responses name it.</summary>
public sealed record ErrorSource
{
    private ErrorSource(string code, string name) => (Code, Name) = (code, name);

    public static ErrorSource SectionMedia { get; } = new("section-media", "The section media lookup");
    public static ErrorSource MediaSearch { get; } = new("media-search", "The media search");
    public static ErrorSource MediaToken { get; } = new("media-token", "The media playback token");

    /// <summary>The value the response carries.</summary>
    public string Code { get; }

    /// <summary>The wording used inside the response detail.</summary>
    public string Name { get; }
}
```

`ErrorCause` is a union whose **members are polymorphic**. Each case writes its own wire value and
its own sentence. A new case cannot compile without them, so there is never a `switch` with
`_ => throw`:

```csharp
/// <summary>Why a lookup failed, in the words the response uses.</summary>
public abstract record ErrorCause
{
    private ErrorCause() { }

    /// <summary>The step could not obtain its access credential.</summary>
    public static ErrorCause TokenUnavailable { get; } = new TokenUnavailableCause();

    /// <summary>The downstream service answered with an error status.</summary>
    public static ErrorCause UpstreamRejected(int status) => new UpstreamRejectedCause(status);

    /// <summary>The downstream service could not be reached.</summary>
    public static ErrorCause Unreachable { get; } = new UnreachableCause();

    /// <summary>The value the response carries.</summary>
    public abstract string Cause { get; }

    /// <summary>The status the downstream service answered, when there was one.</summary>
    public abstract int? UpstreamStatus { get; }

    /// <summary>Builds the sentence the response shows for this source.</summary>
    public abstract string Describe(string sourceName);

    private sealed record TokenUnavailableCause : ErrorCause
    {
        public override string Cause => "token_unavailable";
        public override int? UpstreamStatus => null;
        public override string Describe(string sourceName) =>
            $"{sourceName} could not obtain its access credential.";
    }

    private sealed record UpstreamRejectedCause(int Status) : ErrorCause
    {
        public override string Cause => "upstream_rejected";
        public override int? UpstreamStatus => Status;
        public override string Describe(string sourceName) =>
            $"{sourceName} was rejected by its downstream service ({Status}).";
    }

    private sealed record UnreachableCause : ErrorCause
    {
        public override string Cause => "unreachable";
        public override int? UpstreamStatus => null;
        public override string Describe(string sourceName) =>
            $"{sourceName} could not reach its downstream service.";
    }
}
```

Note the shape: concrete case records are **private**, and call sites only ever use the named
factories and singletons. There is no `new` outside the type.

## The problem type

`ProblemDetails` is subclassed with real properties. ASP.NET Core Minimal APIs serialize the
**runtime type**, so the extra properties reach the wire — the same mechanism that makes
`ValidationProblemDetails` work. No extensions dictionary is involved.

```csharp
/// <summary>The response body for a failed lookup.</summary>
public sealed class ErrorProblem : ProblemDetails
{
    /// <summary>Builds the body for a step that could not obtain its credential.</summary>
    public static ErrorProblem TokenUnavailable(string title, ErrorSource source) =>
        new(title, source, ErrorCause.TokenUnavailable);

    public ErrorProblem(string title, ErrorSource source, ErrorCause cause)
    {
        Status = StatusCodes.Status502BadGateway;
        Title = title;
        Detail = cause.Describe(source.Name);
        Source = source.Code;
        Cause = cause.Cause;
        UpstreamStatus = cause.UpstreamStatus;
    }

    /// <summary>The lookup that failed.</summary>
    public string Source { get; }

    /// <summary>The failure category.</summary>
    public string Cause { get; }

    /// <summary>The status the downstream service answered, when there was one.</summary>
    public int? UpstreamStatus { get; }
}
```

Static factories go **above** the instance members, and they are named after the situation
(`TokenUnavailable`), the same way domain factories are named (`Score.Completion`).

The serialized body is small, stable, and machine-readable:

```json
{
  "title": "Media catalog unavailable",
  "status": 502,
  "detail": "The section media lookup could not reach its downstream service.",
  "source": "section-media",
  "cause": "unreachable"
}
```

A client can branch on `cause` and show a precise message. Pin that contract with a serialization
test.

## Endpoints map, they do not invent

An endpoint **maps** a result it received; it never fabricates another module's union case.

```csharp
// WRONG: the endpoint invents a provider's failure.
if (token is null)
    return Results.Problem(new ErrorProblem(Title, ErrorSource.MediaToken,
        new ErrorCause.UpstreamRejected(0)));   // a lie, and a case built from outside
```

```csharp
// RIGHT: the failure flows out of the result...
if (tokenResult is TokenResult.Unavailable(var cause))
    return Results.Problem(new ErrorProblem(Title, ErrorSource.MediaToken, cause));

// ...or comes from a named factory when the endpoint genuinely owns the situation.
return Results.Problem(
    ErrorProblem.TokenUnavailable("Could not obtain the media playback token", ErrorSource.MediaToken));
```

If an endpoint needs a failure that only a provider can know, the provider must return it. Reaching
for a provider's case from outside is a coupling smell, not a shortcut.

## Smart constructors vs direct construction

Both idioms are correct, for different kinds of union:

| Union kind | Construction | Why |
|---|---|---|
| **Result union** that callers pattern-match (`Found` / `Unavailable`) | `new SectionMediaResult.Found(ids)` directly, by its owner | The owner builds its own outcome; matching needs the cases public |
| **Vocabulary union** nobody matches (`ErrorCause`) | Private cases + static factories only | Call sites should pick a meaning, not assemble a shape |

The question to ask: *does anyone pattern-match this type?* If yes, cases are public and the owner
constructs them. If no, hide the cases behind named factories.

## What never reaches the wire

The full downstream detail — response body, URLs, upstream host names, credentials, internal
identifiers — stays in **logs only**. The wire gets the bounded vocabulary above.

```csharp
logger.LogWarning("Section media lookup at {Url} returned {Status}: {Body}", url, status, body);
return new SectionMediaResult.Unavailable(ErrorCause.UpstreamRejected(status));
```

The log says exactly why. The response says which step failed and in which category. Both are
useful; neither leaks.

## Anti-patterns

| Anti-pattern | Replacement |
|---|---|
| `bool IsSuccess` + `T? Value` + `string? Error` | Union of records |
| A result-type library (OneOf, ErrorOr, FluentResults) | A hand-written domain union per operation |
| `string Reason` on a failure case | `ErrorCause` |
| `Dictionary<string, object?>` of extensions | `ProblemDetails` subclass with properties |
| `switch (cause) { ... _ => throw }` | Abstract members on the union |
| `new ErrorCause.SomeCase()` at a call site | Named static factory |
| Endpoint building another module's failure case | Let it flow from the result |
| Returning `null` to mean "not found" from a service | `NotFound` case |
| Throwing for an expected business outcome | Result union |
| Returning raw upstream text in the response | Bounded cause + full detail in the log |
| Comments naming concrete status codes in an abstract type | Describe behavior, not one value |
