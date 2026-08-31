# Project Structure and Composition

Code is organized by **feature**, never by technical layer. A feature is a folder; everything the
feature needs lives in it, including its own dependency-injection wiring.

## Contents

- [Vertical slices](#vertical-slices)
- [What a slice owns](#what-a-slice-owns)
- [Promotion rules](#promotion-rules)
- [One type per file](#one-type-per-file)
- [Namespaces match folders](#namespaces-match-folders)
- [External service clients](#external-service-clients)
- [Dependency injection](#dependency-injection)
- [Endpoints](#endpoints)
- [Solution layout](#solution-layout)

## Vertical slices

```
src/MyApp.Api/
├── Program.cs                 # composition root: middleware order + Add{Feature}() calls
├── ConfigureServices.cs       # cross-cutting only (cache, health, rate limiting)
├── Features/
│   ├── Orders/                # one folder per feature
│   │   ├── CreateOrderEndpoint.cs
│   │   ├── CreateOrderRequest.cs
│   │   ├── OrderResponse.cs
│   │   ├── OrdersSettings.cs
│   │   ├── OrdersRegistration.cs        # AddOrders()
│   │   └── Model/                       # concept subfolders inside a slice are encouraged
│   │       ├── Order.cs
│   │       └── OrderResult.cs
│   └── Invoicing/
├── Infrastructure/            # shared plumbing used by two or more slices
└── Shared/                    # value objects used by two or more slices
```

**Banned as top-level folders:** `Services/`, `Models/`, `Repositories/`, `Helpers/`, `Utils/`,
`Common/`, or a folder named after a protocol. These recreate layered architecture and scatter one
feature across the tree.

**Encouraged inside a slice:** concept subfolders — `Model/`, `Claims/`, `Verification/`. The rule
against generic names applies to top-level folders, not to concepts inside a feature.

Deleting a feature should mean deleting one folder and one line in `Program.cs`.

## What a slice owns

- Its endpoint(s) and handler logic.
- Its request and response DTOs.
- Its settings POCO and validation.
- Its domain model and result unions.
- Its DI registration: `{Feature}Registration.cs` exposing `Add{Feature}()`.

`ConfigureServices.cs` holds only genuinely cross-cutting registrations. `Program.cs` reads as a
list of features.

```csharp
builder.Services
    .AddOrders()
    .AddInvoicing()
    .AddPaymentsApi();
```

## Promotion rules

Move a piece out of a slice **only when a second consumer appears**:

| Piece | Where it goes on the second consumer |
|---|---|
| Domain value object | `Shared/` |
| Settings, contracts, plumbing interfaces | `Infrastructure/` |
| A service with behavior | stays in its slice, shared through the container |

A service registered in one slice and injected by another does not need to move — the container is
the sharing mechanism. Do not create a `Common` project for one type.

## One type per file

Every type gets its own file, named after the type — including small records. The only exception is
a set of small, closely related value objects belonging to one concept, which may share a file.

Never a mega-file holding a hierarchy plus its factory plus its helpers.

## Namespaces match folders

The namespace mirrors the folder path exactly (`Features/Orders/Model` →
`MyApp.Api.Features.Orders.Model`). Enforce it:

```ini
# .editorconfig
dotnet_style_namespace_match_folder = true:warning
csharp_style_namespace_declarations = file_scoped:warning
```

Use file-scoped namespaces everywhere.

## External service clients

Every outbound service gets one folder under `Infrastructure/Providers/`, with the folder name as
the family prefix on every type inside, plus its own registration:

```
Infrastructure/Providers/
├── ICachedToken.cs + CachedToken.cs   # shared plumbing, no family prefix
├── TokenFetch.cs                      # shared provider→cache contract
├── PaymentsApi/
│   ├── PaymentsApiSettings.cs
│   ├── PaymentsApiRegistration.cs     # AddPaymentsApi()
│   ├── IPaymentsApiTokenProvider.cs + PaymentsApiTokenProvider.cs
│   ├── PaymentsApiTokenResult.cs
│   └── PaymentsApiChargeResponse.cs
└── CatalogApi/
```

Shared plumbing at the root of `Providers/` carries no family prefix. See
[integration.md](integration.md) for the client and token-cache patterns.

## Dependency injection

- **Every type with behavior is registered behind an interface** and consumers depend on the
  interface: `services.AddSingleton<IFoo, Foo>()`. Depending on a concrete service class is not
  acceptable — it blocks substitution in tests.
- Pure data and options POCOs are exempt; they have no behavior to substitute.
- An abstract base class is always registered behind an interface too, so it can be mocked.
- Group registrations into `Add{Feature}()` extension methods that return `IServiceCollection`.
- Accept configuration explicitly as a parameter; never hide a connection string inside an
  extension method.

Lifetimes:

| Lifetime | Use for |
|---|---|
| Singleton | Stateless, thread-safe, expensive to build: typed clients, caches, key holders |
| Scoped | Per-request state: database contexts, repositories, unit of work |
| Transient | Cheap, short-lived: validators, small helpers |

Never capture a scoped service in a singleton. In background work, create a scope per unit of work
with `IServiceScopeFactory`.

Options are bound with validation that fails at startup:

```csharp
services.AddOptions<PaymentsApiSettings>()
    .BindConfiguration("PaymentsApi")
    .ValidateDataAnnotations()
    .ValidateOnStart();
```

Missing or malformed configuration must crash the process at boot, never surface as a confusing
runtime failure. Deeper patterns: [../library/microsoft-extensions-dependency-injection/README.md](../library/microsoft-extensions-dependency-injection/README.md)
and [../library/microsoft-extensions-configuration/README.md](../library/microsoft-extensions-configuration/README.md).

## Endpoints

- **Minimal APIs are the default** for new services: one endpoint class per route, discovered
  through a small `IEndpoint` abstraction mapped in `Program.cs`. The default bends to the
  project: a codebase built on controllers keeps controllers — consistency inside a service beats
  the preference, the two styles are never mixed in one service, and a style migration is its own
  task, never a side effect of a feature.
- The handler **orchestrates inline**: parse inputs, call providers, match results, return. Do not
  add an orchestrator class whose only job is to call three things in order, and do not route
  calls through an in-process bus — MediatR and its kind are banned (see [tooling.md](tooling.md)).
- Endpoint documentation lives in **OpenAPI metadata**, not in `//` comments:
  `.WithSummary()`, `.WithDescription()`, `.WithTags()`. The API reference is served with the
  built-in OpenAPI generation plus Scalar as the UI.
- **Public HTTP APIs are versioned** with `Asp.Versioning`. Internal contracts the same team owns
  on both sides use replacement instead — one name for one concept, never a parallel v2 field.
- Endpoints return typed results and typed problems; see [errors-and-results.md](errors-and-results.md).

```csharp
public sealed class CreateOrderEndpoint : IEndpoint
{
    public void MapEndpoint(IEndpointRouteBuilder app) =>
        app.MapPost("/api/orders", HandleAsync)
           .RequireAuthorization()
           .WithTags("Orders")
           .WithSummary("Create an order")
           .WithDescription("Creates an order for the authenticated customer.");
}
```

## Solution layout

```
MySolution.slnx                 # .slnx, never .sln alongside it
Directory.Build.props           # shared build properties
Directory.Packages.props        # central package management — mandatory in every new solution
global.json                     # pinned SDK
src/…                           # one project per deployable or library
tests/…                         # test projects mirroring src
```

Baseline `Directory.Build.props`:

```xml
<Project>
  <PropertyGroup>
    <LangVersion>latest</LangVersion>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
    <AnalysisLevel>latest-recommended</AnalysisLevel>
  </PropertyGroup>
</Project>
```

Every project references packages **without versions**; the versions live once in
`Directory.Packages.props`, with shared variables for package families that must move together.
A legacy solution migrates to central package management incrementally, never big-bang.

**Warnings are errors.** `TreatWarningsAsErrors` is on: a warning stops the build, so it is fixed
the moment it appears instead of accumulating. Two rules keep this honest:

1. A warning is fixed **in the code**, never silenced. `#pragma warning disable`, `[SuppressMessage]`,
   and `NoWarn` lists are not fixes; a suppression is acceptable only for a documented external
   constraint, in the narrowest possible scope, with a comment naming the reason.
2. An analyzer rule that produces ceremony without value is disabled explicitly in `.editorconfig`
   (`severity = none`) — an intentional, reviewable decision that removes the diagnostic at the
   source — never worked around with pragmas scattered through the code.

Container images follow one shape: a **multi-stage** Dockerfile that publishes the application
project directly, a **chiseled or distroless** base image, and a **non-root** user. Test projects
are never copied into the image — the image build must not even compile them.

Full build-file, packaging, and versioning detail:
[../library/project-structure/README.md](../library/project-structure/README.md) and
[../library/package-management/README.md](../library/package-management/README.md).
