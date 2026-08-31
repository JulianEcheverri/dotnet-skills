# Calling Other Services

Rules for outbound HTTP, credentials, caching, resilience, and the security defaults that are not
negotiable.

## Contents

- [Typed clients](#typed-clients)
- [Bounded resilience](#bounded-resilience)
- [Surfacing a failure](#surfacing-a-failure)
- [Token caching](#token-caching)
- [Batching](#batching)
- [Security defaults](#security-defaults)
- [Secrets and configuration](#secrets-and-configuration)
- [Anti-patterns](#anti-patterns)

## Typed clients

One typed `HttpClient` per external service, registered in that service's own registration, with
exactly one resilience handler:

```csharp
public static IServiceCollection AddPaymentsApi(this IServiceCollection services)
{
    services.AddOptions<PaymentsApiSettings>()
        .BindConfiguration("PaymentsApi")
        .ValidateDataAnnotations()
        .ValidateOnStart();

    services.AddHttpClient(HttpClientNames.PaymentsApi)
        .AddStandardResilienceHandler();

    services.AddSingleton<IPaymentsApiTokenProvider, PaymentsApiTokenProvider>();
    services.AddSingleton<IPaymentsChargeProvider, PaymentsChargeProvider>();
    return services;
}
```

- Client names live in one `HttpClientNames` class, keyed by the family name.
- Never `new HttpClient()`, never a static one built by hand.
- The provider returns a **result union**, never a nullable or a thrown exception for an expected
  failure.

## Bounded resilience

Default resilience settings are generous; on a user-facing path they are not acceptable. A dead
dependency must not hold a request open long enough for the edge to time out first.

```csharp
services.AddHttpClient(HttpClientNames.Grading)
    .AddStandardResilienceHandler(options =>
    {
        options.AttemptTimeout.Timeout = TimeSpan.FromSeconds(2);
        options.Retry.MaxRetryAttempts = 1;
        options.Retry.Delay = TimeSpan.FromMilliseconds(500);
        options.TotalRequestTimeout.Timeout = TimeSpan.FromSeconds(5);
    });
```

Choose the numbers from the budget of the caller, not from a default: measure the healthy latency,
leave a comfortable multiple, and make sure `attempts × attempt timeout + delays` stays inside the
total. State the reasoning where the values are chosen — a tuning constant nobody can justify is a
bug waiting to happen.

The timeout exception thrown by a resilience pipeline is **not** the same type as a transport
exception. A `catch` filter that lists only `HttpRequestException` will let it fall through to a
generic handler and lose the step name. Catch both.

```csharp
catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or TimeoutRejectedException)
{
    logger.LogError(ex, "Score endpoint unreachable at {Url}", scoresUrl);
    return new GradeResult.Failed(ErrorCause.Unreachable);
}
```

## Surfacing a failure

A non-success response is reported with **status and body**, so the log says *why* it was rejected,
not merely that it was:

```csharp
var response = await httpClient.GetAsync(url, cancellationToken);
if (!response.IsSuccessStatusCode)
{
    var body = await response.Content.ReadAsStringAsync(cancellationToken);
    logger.LogWarning("Catalog lookup at {Url} returned {Status}: {Body}", url, (int)response.StatusCode, body);
    return new CatalogResult.Unavailable(ErrorCause.UpstreamRejected((int)response.StatusCode));
}
```

Use `GetAsync` plus an explicit body read rather than `GetStringAsync`, which discards the body on
an error status. A transport exception includes `ex.Message`. None of this detail reaches the wire —
see [errors-and-results.md](errors-and-results.md).

## Token caching

A credential fetched from a remote service is cached once, refreshed before it expires, and fetched
by **one caller at a time**. The whole mechanism is written once, in an abstract base behind an
interface; each service family derives a minimal subclass that only builds its own result type.

```csharp
/// <summary>Gives a cached access token, refreshing it before it expires.</summary>
public interface ICachedToken<TResult>
{
    Task<TResult> GetAsync(CancellationToken cancellationToken);
}

/// <summary>Caches one token and lets only one caller refresh it at a time.</summary>
public abstract class CachedToken<TResult>(TimeProvider timeProvider, ILogger logger) : ICachedToken<TResult>
{
    private readonly SemaphoreSlim _gate = new(1, 1);
    private State _state = State.Empty;

    public async Task<TResult> GetAsync(CancellationToken cancellationToken)
    {
        var snapshot = _state;                                  // fast path: no lock needed
        if (snapshot.IsFresh(timeProvider.GetUtcNow()))
            return Available(snapshot.Token);

        await _gate.WaitAsync(cancellationToken);
        try
        {
            snapshot = _state;                                  // another caller may have refreshed
            if (snapshot.IsFresh(timeProvider.GetUtcNow()))
                return Available(snapshot.Token);

            var fetch = await FetchAsync(cancellationToken);
            if (fetch is TokenFetch.Failed(var reason))
            {
                // A failed refresh still serves the current token while it is valid.
                if (snapshot.IsUsable(timeProvider.GetUtcNow()))
                    return Available(snapshot.Token);

                logger.LogError("Token refresh failed: {Reason}", reason);
                return Unavailable();
            }

            var fetched = (TokenFetch.Fetched)fetch;
            _state = State.From(fetched);
            return Available(fetched.Token);
        }
        finally
        {
            _gate.Release();
        }
    }

    protected abstract Task<TokenFetch> FetchAsync(CancellationToken cancellationToken);
    protected abstract TResult Available(string token);
    protected abstract TResult Unavailable();
}
```

Rules embedded above, each learned the hard way:

- The cached state is **one immutable record on a plain field**. The fast read is safe because the
  snapshot validates itself against its own expiry, and a stale read simply falls into the gate.
- **Do not use `volatile`.** Official guidance discourages it in application code; the gate plus an
  immutable snapshot is both correct and readable.
- A **failed refresh serves the still-valid token**. Only when the current token has also expired
  does the caller see the unavailable result. This is the entire reason for refreshing early.
- Consumers and DI use the **interface**, never the abstract class, so it can be substituted in
  tests: `services.AddTransient<ICachedToken<PaymentsTokenResult>, PaymentsCachedToken>()`.
- The single filtered `try/catch` lives inside `FetchAsync`, at the HTTP boundary. Predictable 4xx
  responses are a `Failed` result, not an exception.
- Time comes from an injected `TimeProvider`, so expiry and refresh behavior are testable with a
  fake clock instead of real waiting.

## Batching

When an upstream API caps the number of items per call, chunk to that cap and loop **sequentially**
until the input is exhausted. Do not add parallelism, semaphores, or tuning knobs nobody asked for.

```csharp
foreach (var batch in ids.Chunk(BatchSize))
{
    var result = await SearchAsync(batch, cancellationToken);
    if (result is SearchResult.Unavailable) return result;   // partial data is worse than none
    found.AddRange(((SearchResult.Found)result).Items);
}
```

A partial result that silently hides items is a data bug. Fail the whole operation.

## Security defaults

- **Pin the algorithm on every token validation.** Accept exactly the algorithm the issuer uses
  (`RS256` for a platform's signature, `HS256` for a symmetric token you issue). Leaving the
  algorithm open enables confusion attacks where a token signed with a different scheme is accepted.
- **Validate issuer, audience, expiry, and any deployment/tenant claim** — not just the signature.
- **Pair every absolute-URI parse with a scheme check** (see
  [testing.md](testing.md#cross-platform-behavior) for why).
- **Never log secrets**: tokens, client secrets, authorization headers, OIDC `state` or `nonce`.
- **Never put a private key or secret in the repository.** Keys come from a secret store at runtime;
  rotation is a supported operation with an overlap window where both the current and previous key
  are published or accepted.
- Browser-mediated endpoints must not answer a raw status or an HTML error page: redirect to the
  application's error page. API endpoints answer typed problem details.
- A custom request header on a cross-site call forces a preflight and doubles as a cross-site
  request forgery defense — combine it with a same-site cookie policy chosen deliberately.
- Prefer ephemeral data-protection keys when nothing durable is protected, and revisit that choice
  the moment something durable is added.

## Secrets and configuration

- Configuration is bound to a strongly-typed options POCO, validated, and `ValidateOnStart()`.
- Environment-specific values live in environment-specific configuration, not in `if (environment ==
  "production")` branches in the code.
- Selecting behavior dynamically at runtime from a value that is really deployment configuration is
  banned. If each deployment serves one environment, its identity is static configuration.
- A secret reaches the process through the platform's secret mechanism (secret manager, mounted
  secret, environment injection), never through the source tree.

## Anti-patterns

| Anti-pattern | Replacement |
|---|---|
| `new HttpClient()` per call | Typed client from the factory |
| Two resilience handlers on one client | Exactly one |
| Default timeouts on a user-facing path | Bounded attempt/total timeouts |
| `GetStringAsync` when you need the error body | `GetAsync` + read body |
| Throwing on a predictable 4xx | Result union with a typed cause |
| `volatile` on cached state | Immutable snapshot + gate |
| Parallel fan-out nobody requested | Sequential loop |
| Partial results on a failed batch | Fail the operation |
| Unpinned token algorithm | `ValidAlgorithms` set explicitly |
| Secret or key committed to the repo | Secret store + rotation |
