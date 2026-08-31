# Domain Modeling

The house style for turning data into types. Two ideas carry everything else: **make invalid
states unrepresentable** and **parse, don't validate**.

## Contents

- [The two laws](#the-two-laws)
- [One sealed record per valid state](#one-sealed-record-per-valid-state)
- [Polymorphic members, not a central switch](#polymorphic-members-not-a-central-switch)
- [Value objects and smart constructors](#value-objects-and-smart-constructors)
- [Every id is a value object](#every-id-is-a-value-object)
- [Parsers at the boundary](#parsers-at-the-boundary)
- [Parser vs verifier](#parser-vs-verifier)
- [Deleting fields before making them optional](#deleting-fields-before-making-them-optional)
- [Changing a model without changing its shape](#changing-a-model-without-changing-its-shape)
- [Anti-patterns](#anti-patterns)

## The two laws

**1. Make invalid states unrepresentable.** If a combination of values is meaningless, the type
system must refuse to express it. A state that cannot compile can never be tested, logged, or
shipped.

**2. Parse, don't validate.** Convert loose input into a strong type once, at the edge. Downstream
code never re-checks: holding the type *is* the proof. A function that validates and returns
`bool` throws away the knowledge it just produced; a function that parses returns that knowledge
as a type.

Everything below is a consequence of these two.

## One sealed record per valid state

Do not model one wide type with nullable fields and a derived `Mode`. Model each valid state as
its own `sealed record` carrying exactly the data that state requires.

```csharp
// WRONG: one weak type; every consumer must re-derive what it is and re-check nullables.
public sealed record Submission(
    SubmissionKind Kind,          // derived by ternaries somewhere
    Grade? Grade,                 // set only for graded submissions
    Reviewer? Reviewer,           // set only for reviewed submissions
    DateTimeOffset? ReviewedAt);  // "just in case"
```

```csharp
// RIGHT: a hierarchy where each state owns its required data.
public abstract record Submission(SubmissionId Id, AuthorId Author)
{
    public abstract string Kind { get; }
}

public sealed record DraftSubmission(SubmissionId Id, AuthorId Author)
    : Submission(Id, Author)
{
    public override string Kind => "draft";
}

public sealed record GradedSubmission(SubmissionId Id, AuthorId Author, Grade Grade)
    : Submission(Id, Author)
{
    public override string Kind => "graded";
}

public sealed record ReviewedSubmission(
    SubmissionId Id, AuthorId Author, Grade Grade, Reviewer Reviewer, DateTimeOffset ReviewedAt)
    : Submission(Id, Author)
{
    public override string Kind => "reviewed";
}
```

A `GradedSubmission` without a `Grade` does not compile. No consumer checks for null. Adding a
state is adding a record, not editing a switch that lives somewhere else.

**Rules:**

- Every leaf record is `sealed`.
- A state's required data is a **constructor parameter**, never a nullable property.
- The base is `abstract` and carries only what genuinely applies to all states.
- Do not add a state that has no consumer.

## Polymorphic members, not a central switch

The thing that varies per state belongs *on* the state, as an abstract member. A central `switch`
or a chain of ternaries is the weak-modeling smell this replaces.

```csharp
// WRONG: the knowledge lives away from the type; a new case silently falls into the default.
public static string DescribeKind(Submission submission) => submission switch
{
    { Grade: not null, Reviewer: not null } => "reviewed",
    { Grade: not null } => "graded",
    _ => "draft"
};
```

```csharp
// RIGHT: abstract member. A new state does not compile until it answers.
public abstract record Submission
{
    public abstract string Kind { get; }
    public abstract string Describe();
}
```

**Test to apply:** if adding a case to the model can compile without me editing the behavior, the
behavior is in the wrong place. Move it onto the type as an abstract member.

`switch` over a union is correct when the *caller* is choosing what to do next (an endpoint
mapping a result to a response); it is wrong when the *type itself* owns the answer.

## Value objects and smart constructors

A domain concept never travels as a bare `string`, `long`, or `Guid`. It travels as a value object
built by a **smart constructor**: private constructor plus a static `TryParse`/`TryFrom` that
returns the type or `null`.

```csharp
/// <summary>A section identifier: a positive whole number.</summary>
public sealed record SectionId
{
    private SectionId(long value) => Value = value;

    public long Value { get; }

    /// <summary>Parses a section id; returns null when the text is not a positive number.</summary>
    public static SectionId? TryParse(string? text) =>
        long.TryParse(text, out var value) && value > 0 ? new SectionId(value) : null;

    public override string ToString() => Value.ToString();
}
```

**Rules:**

- **Do not throw** from a value object to reject input. Return `null` and let the caller decide the
  response. Exceptions are for unexpected failures, not for input the system receives every day.
- The `T?` returned by `TryParse` is the C# spelling of an option. The **caller converts that null
  into a typed rejection immediately** — a `LaunchResult.Invalid`, a 422, a `ValidationProblem`.
  The null must not travel further than the parse site.
- No implicit conversion operators, in either direction. They erase the type safety the value
  object exists to provide. Construct explicitly, read `.Value` explicitly.
- Normalize inside the constructor (trim, lowercase, strip separators) so every instance is
  canonical.
- Validation lives in exactly one place: the smart constructor.

**`record` or `readonly record struct`?** Both are house-legal. Use `readonly record struct` for
small, frequently created values in hot paths (ids, money, quantities) — it avoids an allocation
and gives value semantics. Use a `sealed record` class when the type is nullable-by-design in the
model, is larger than a couple of fields, or when a struct's parameterless `default` (which
bypasses the smart constructor) would be a trap. Whichever you choose, the smart-constructor rule
above does not change.

```csharp
public readonly record struct Money
{
    private Money(decimal amount, string currency) => (Amount, Currency) = (amount, currency);

    public decimal Amount { get; }
    public string Currency { get; }

    public static Money? TryFrom(decimal amount, string? currency) =>
        amount >= 0 && currency is { Length: 3 }
            ? new Money(amount, currency.ToUpperInvariant())
            : null;
}
```

## Every id is a value object

`MediaId`, `SectionId`, `CustomerId`, `CourseIsbn` — never a raw primitive flowing through layers.
The raw primitive appears in exactly two places:

1. The **wire DTO** at deserialization (the boundary).
2. The **wire DTO** at serialization (the other boundary).

Between them, only the value object exists. This makes argument swaps a compile error instead of a
production incident.

```csharp
// The wire DTO carries the raw value; nothing else does.
public sealed record CreateOrderRequest(string CustomerId, string ProductId);

// The handler parses once, then works with types.
var customerId = CustomerId.TryParse(request.CustomerId);
if (customerId is null)
    return Results.ValidationProblem(/* customerId is not a valid id */);
```

Do not write a `JsonConverter<T>` to bind a value object directly from the wire. Binding must not
be able to fail silently or throw inside the serializer: request DTOs carry the raw text, and the
handler parses it where a failure has an obvious response.

## Parsers at the boundary

A boundary is where untyped data enters: an HTTP request, a token's claims, a queue message, a
config file, a database row. Each boundary gets **one factory** that produces the strong model or a
typed rejection.

```csharp
public static class LaunchFactory
{
    public static LaunchResult Create(ClaimsReader claims)
    {
        var subject = claims.GetString("sub");
        if (subject is null)
            return new LaunchResult.Invalid("launch without a subject");

        var sectionId = SectionId.TryParse(claims.GetString("section_id"));
        if (sectionId is null)
            return new LaunchResult.Invalid("launch without a valid section id");

        return new LaunchResult.Parsed(new StudentLaunch(subject, sectionId));
    }
}
```

**Fail at the door.** An input the flow requires is rejected where it arrives, with the failed rule
named, and logged as a warning. Never default it away (`?? string.Empty`), never carry it as null
so a later step can discover the problem. A late failure is a worse failure: the log points at the
wrong component.

## Parser vs verifier

These are different jobs and only one of them is a smell.

- **Structural validation** — which fields are present, deriving a mode, null checks. This belongs
  in the parser and disappears from the rest of the code.
- **Cryptographic or remote verification** — checking a signature against remote keys, calling an
  authorization service. This is asynchronous, does I/O, and cannot live in a pure constructor. It
  stays as its own thin single-responsibility component whose output is the already-parsed strong
  type (`VerifiedToken` / `RejectedToken`).

Do not force verification into a smart constructor, and do not let a verifier return a weak type.

## Deleting fields before making them optional

Before asking "required or optional?", ask **"does this field have a real consumer?"**

1. No consumer → **delete it**. A field nobody reads is dead code that makes every downstream type
   weaker.
2. A consumer exists → find its real source, take it from there, and make it **required**.

A `string?` added "just in case" turns every consumer downstream into a null check. Never add a
field speculatively, and never send a field nobody reads.

## Changing a model without changing its shape

When a value changes its **type** or its **source**, the diff must be the smallest possible
conceptual change:

- The value object **stays**; only what it wraps changes. Never let a raw primitive start flowing
  where the value object used to flow.
- The property stays **where it lives**, and any claim/field name stays the same. A replacement,
  never two names for one concept.
- A value-object-typed property is named after the value object: `SectionId SectionId`, not
  `SectionId Section`.
- Before proposing new configuration or a new parameter, check what the request/message/token
  **already carries**.
- An input the flow requires fails at the door — admitting a null there is accepting a broken input,
  not modeling optionality.

## Anti-patterns

| Anti-pattern | Why it is banned | Replacement |
|---|---|---|
| `bool IsValid` + `T? Value` | Forces `!` and re-checking; the invalid state is representable | Discriminated union of records |
| Enum + chain of ternaries to derive a mode | Behavior lives away from the data; new case compiles silently | One record per state + abstract member |
| Nullable field set only for some cases | The invalid combination is representable | A record for each case |
| Value object with a public constructor that throws | Expected input becomes an exception | Private ctor + `TryParse` returning null |
| Implicit conversion to/from the primitive | Silently defeats the type | Explicit construction and `.Value` |
| Raw `string`/`long` id in a service signature | Argument swaps compile | Value object |
| Re-validating a value you already parsed | The type is the proof | Trust the type |
| `?? string.Empty` on a required value | Hides a broken input until later | Reject at the parse site |
| Speculative field "the client might need it" | Dead weight, weakens consumers | Delete until a consumer exists |

## Where C# is going

C# 15 / .NET 11 introduce native discriminated unions (a `union` of existing case types with
exhaustive matching). They express exactly what the sealed-record hierarchies above encode by hand.
Nothing in this doctrine changes when they ship: the modeling is identical, the syntax gets shorter,
and exhaustiveness becomes a compiler guarantee instead of a review rule. Write hierarchies today so
the migration is mechanical. See [csharp-baseline.md](csharp-baseline.md).
