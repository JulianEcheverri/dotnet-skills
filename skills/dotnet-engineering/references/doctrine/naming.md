# Naming and Method Hygiene

A name must say **what a thing is** or **what it does**, without the reader opening the body.
Short but telling. Vague, abbreviated, or clever names are rejected in review.

## Contents

- [The rule](#the-rule)
- [Interfaces and implementations](#interfaces-and-implementations)
- [Injected dependencies](#injected-dependencies)
- [Result unions and DTOs](#result-unions-and-dtos)
- [Peer types share a role suffix](#peer-types-share-a-role-suffix)
- [Value objects](#value-objects)
- [Methods are verbs](#methods-are-verbs)
- [Method hygiene](#method-hygiene)
- [Readable conditionals](#readable-conditionals)
- [Fields and constants](#fields-and-constants)
- [Family prefixes](#family-prefixes)
- [No abbreviations](#no-abbreviations)

## The rule

| Rejected | Accepted | Why |
|---|---|---|
| `TokenUrl` | `PlatformTokenEndpoint(issuer)` | "Url" of what, built how? |
| `GetToken` | `RequestAccessTokenAsync` | Says which token and that it does I/O |
| `Url(...)` | `ScoresUrl(...)` | Names the resource |
| `ReadGrades` | `ReadGradeEndpoint` | It reads one endpoint, not grades |
| `Media media` | `MediaId mediaId` | The variable is named after its type |
| `data`, `info`, `helper`, `manager` | the actual concept | Says nothing |

## Interfaces and implementations

The implementation is the interface name **minus the `I`**:

```csharp
public interface ICachedToken { }
public sealed class CachedToken : ICachedToken { }

public interface ISectionMediaProvider { }
public sealed class SectionMediaProvider : ISectionMediaProvider { }
```

Inventing a different name for a sole implementation (`IMediaCatalog` → `SectionMediaCatalog`) is
rejected: it breaks the pairing and makes the reader hunt.

Only when **several** implementations exist does each take a descriptive prefix:

```csharp
public interface ICacheStore { }
public sealed class RedisCacheStore : ICacheStore { }
public sealed class InMemoryCacheStore : ICacheStore { }
```

Order of decision: name the class first (what it **is**), then the interface is `I{ClassName}`.

Placement: a one- or two-member interface lives in the same file as its implementation, declared
above the class. A larger interface gets its own file.

## Injected dependencies

A dependency's variable is the interface name minus the `I`, camelCased — in constructors, primary
constructors, and endpoint handler parameters alike:

```csharp
public sealed class MediaCatalogService(
    ISectionMediaProvider sectionMediaProvider,   // never "provider" or "sectionProvider"
    ICacheStore cacheStore,                       // never "cache"
    ILogger<MediaCatalogService> logger)          // idiomatic name kept
```

`ILogger<T> logger` and `IOptions<T> options` / `{name}Options` keep their idiomatic forms.

## Result unions and DTOs

- A result union ends in `Result`: `TokenResult`, `GradeResult`, `MediaSearchResult`.
- A response DTO is named after **its endpoint**: `/api/media/catalog` → `MediaCatalogResponse`
  (not `CatalogMediaResponse`).
- A request DTO is named after the call it makes: `CreateOrderRequest`, `SectionMediaRequest`.
- A DTO carries **only the fields its consumer uses**. Drop a field the consumer never reads, even
  if the upstream sends it.

## Peer types share a role suffix

Two types doing the same job at the same level carry the same suffix. If one is a `Provider`, the
other is a `Provider` — not a `Search`, a `Client`, and a `Service` mixed together. A reader should
be able to tell what a type is from its last word.

## Value objects

A value-object-typed property or variable is named **after the value object**:

```csharp
public sealed record LaunchContext(SectionId SectionId, CourseIsbn CourseIsbn);
//                                           ^^^^^^^^^ not "Section", not "Isbn"
```

## Methods are verbs

`SignAssertion`, `RequestAccessTokenAsync`, `BuildCatalog`, `ReadGradeEndpoint`. A method named as a
noun is either a property in disguise or badly named. Async methods that do I/O end in `Async` and
take a `CancellationToken`.

## Method hygiene

1. **Do not extract a method used once that is one or two lines.** Write it inline. An extracted
   one-liner adds a name, a jump, and nothing else.
2. **Define members in reading order.** Public members first; then private methods in the order the
   public method calls them. The first private method a reader meets going down the public method is
   the first one defined below it.
3. **No local functions inside methods.** Use a private static method or a factory on a record.
4. One responsibility per method — but do not split a linear procedure into a maze of two-line
   helpers.

```csharp
public async Task<GradeResult> SubmitCompletionAsync(...)   // public entry point
{
    var assertion = SignClientAssertion(...);               // first call →
    var token = await RequestAccessTokenAsync(assertion);   // second call →
    return await PostScoreAsync(token, ...);                // third call →
}

private static string SignClientAssertion(...) { }          // defined first
private async Task<TokenResult> RequestAccessTokenAsync(...) { }
private async Task<GradeResult> PostScoreAsync(...) { }
```

## Readable conditionals

Never pack branching into a ternary with compound boolean expressions. Use an early return for the
special case and a plain return for the normal one, naming the intent:

```csharp
// WRONG
return isPreview ? hasRole || isTest : hasRole && !isTest;

// RIGHT
if (isPreview)
    return GradePreviewLaunches;

return isLearner;
```

Pattern matching and switch expressions are encouraged where they read as a table of cases. A
switch expression that needs comments to be understood is a hierarchy waiting to be modeled.

## Fields and constants

| Kind | Convention |
|---|---|
| Instance field | `_camelCase` |
| Static **mutable** field | `s_camelCase` |
| `const` | `PascalCase` |
| `static readonly` | `PascalCase` — it is a logical constant, in tests too |

A `static readonly` named `s_issuerSettings` is wrong; it is `IssuerSettings`. Configure the
analyzer order so the static-readonly rule wins over the `s_` rule.

Inject plain dependencies through the primary constructor with **no field**; add
`_settings = options.Value` only when the value is reused.

## Family prefixes

When several types belong to one external service or one feature family, the family name is a
prefix on **every** type, the config section, and the client name — no exceptions:

```
Providers/PaymentsApi/
    PaymentsApiSettings          // config section "PaymentsApi"
    IPaymentsApiTokenProvider / PaymentsApiTokenProvider
    PaymentsApiTokenResult
    PaymentsApiChargeResponse
```

A wire DTO name says which API, which call, and whether it is a request or a response:
`PaymentsApiChargeResponse`, not `Charge`. The folder name **is** the prefix.

## No abbreviations

Write the full term: `DeepLinking` not `DL`, `configuration` not `cfg`, `request` not `req`,
`repository` not `repo`. Industry-standard acronyms that are longer spelled out (`Http`, `Json`,
`Url`, `Id`) keep their conventional .NET casing.
