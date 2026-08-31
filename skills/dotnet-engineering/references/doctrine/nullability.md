# Nullability

Nullable reference types are enabled everywhere and treated as part of the design, not as a
compiler setting. Every `?` in the codebase must justify itself against the three buckets below.
Anything that fits none of them is a bug.

## Contents

- [The three buckets](#the-three-buckets)
- [Bucket 1: boundary raw input](#bucket-1-boundary-raw-input)
- [Bucket 2: real domain absence](#bucket-2-real-domain-absence)
- [Bucket 3: post-validation nulls are forbidden](#bucket-3-post-validation-nulls-are-forbidden)
- [Door checks](#door-checks)
- [Nullable collections](#nullable-collections)
- [The null-forgiving operator](#the-null-forgiving-operator)
- [A nullable that can never be null is a lie](#a-nullable-that-can-never-be-null-is-a-lie)
- [Review questions](#review-questions)

## The three buckets

1. **Boundary raw input** — data arriving from outside, before it has been parsed.
2. **Real domain absence** — the absence is a meaningful state and consumers handle it.
3. **Everything else** — a bug. Fix the design; do not add a check.

## Bucket 1: boundary raw input

Allowed, and required, at the exact place untyped data enters:

- Wire DTOs bound from an external service's response (`string? AccessToken`).
- Claim and header readers (`string? GetString(string name)`).
- Query/form parameters on a request DTO.
- Every `TryParse(string? input)` parameter.

A missing external field **must** bind rather than throw — you cannot control what a remote service
sends. The null then **dies at the first parse**:

```csharp
// Boundary DTO: nullable is correct here.
public sealed record TokenResponse(string? AccessToken, int? ExpiresIn);

// The parse site converts absence into a typed outcome. The null goes no further.
if (response.AccessToken is not { Length: > 0 })
    return TokenResult.Unavailable(ErrorCause.UpstreamRejected(status));
```

## Bucket 2: real domain absence

Allowed when "absent" is a genuine state of the domain and every consumer handles it:

- Optional personal data an identity provider may legitimately withhold.
- A field that exists in one mode and not another, where the mode is explicit.
- "No previous value yet" — a previous signing key before the first rotation.
- An optional response field the client is documented to treat as absent.

If you cannot name the consumer that handles the absence, it is not this bucket.

Prefer removing the optionality entirely by splitting the type (see
[domain-modeling.md](domain-modeling.md)). A field that is present in one state and absent in
another is usually two records wearing one name.

## Bucket 3: post-validation nulls are forbidden

A value the flow **requires** is rejected at the door and never travels as null.

```csharp
// WRONG: swallows a broken input and fails much later, in the wrong component.
var subject = claims.GetString("sub") ?? string.Empty;
```

```csharp
// RIGHT: reject where it arrives, naming the rule that failed.
var subject = claims.GetString("sub");
if (subject is null)
{
    logger.LogWarning("Launch rejected: no subject claim");
    return new LaunchResult.Invalid("launch without a subject");
}
```

Banned outright:

- `?? string.Empty`, `?? 0`, `?? Guid.Empty` on a value the flow requires.
- Carrying a required-but-missing value forward "so the endpoint can 422 later".
- A nullable property whose only purpose is to postpone a decision.

## Door checks

Every entry point states its required inputs once, at the top, and fails loudly:

- Parse the strong model in a factory that returns `Parsed` or `Invalid(reason)`.
- Log a warning naming the failed rule and the received value (never a secret).
- Return the boundary's natural rejection: a redirect for a browser-mediated flow, a 422 for an
  API, a dropped message with a log for a queue consumer.

Downstream validations may remain as **defense** (an old session issued before a config change),
but they are the second line, never the first.

## Nullable collections

A collection is **never** nullable in a model or a DTO. An absent list binds as empty:

```csharp
// RIGHT: absent or explicitly null in JSON both bind as empty.
public sealed record SectionMediaResponse
{
    public string[] MediaIds { get; init; } = [];
}
```

For a property that must absorb an explicit `null` from a serializer, back it with a field:

```csharp
private readonly Dictionary<string, JsonElement> _captions = [];

public Dictionary<string, JsonElement> Captions
{
    get => _captions;
    init => _captions = value ?? [];
}
```

`x.Count > 0` is then always safe, and no consumer writes `?.Any() == true`.

## The null-forgiving operator

`!` is a claim that you know something the compiler cannot. It is allowed only when a real external
invariant guarantees it, and never as a way to silence a warning.

Before writing `!`:

1. Narrow with a guard clause or pattern match so the non-null state is proven in scope.
2. Copy a nullable field to a local before checking, so repeated reads cannot change under the
   analysis.
3. If the control flow is genuinely complex, extract a private method with non-nullable parameters —
   but only when that also makes the code simpler, never purely to satisfy the analyzer.

```csharp
public void Process(Order? order)
{
    if (order?.Customer is not { } customer)
        return;

    // The pattern match proved customer is non-null; no ! needed anywhere below.
    Handle(customer);
}
```

## A nullable that can never be null is a lie

If every construction path sets a value, the property is not nullable — tighten it. A `string?` that
is always populated forces every consumer to handle a case that cannot happen, and hides the real
optional fields among the fake ones.

Run this sweep periodically: for each `?` in the model layer, name the bucket. Anything unnamed gets
fixed in the same pass.

## Review questions

- Which bucket is this `?` in? If the answer takes more than one sentence, it is bucket 3.
- Who consumes the absence, and what do they do about it?
- Is this two states pretending to be one type?
- Does this null survive past the parse site? It must not.
- Is there a `!` here that a guard clause would remove?
- Does this collection need to be nullable, or does empty say the same thing?

Deeper mechanics — the full `System.Diagnostics.CodeAnalysis` attribute catalog (`NotNullWhen`,
`MemberNotNull`, `NotNullIfNotNull`, …), incremental adoption of nullable annotations in a legacy
codebase, and the `field` keyword's null-resilience analysis — are in
[../library/csharp-nullable-reference-types/README.md](../library/csharp-nullable-reference-types/README.md).
