# Review Checklist and Definition of Done

Run this before calling any change complete, and when reviewing someone else's. It is ordered so
the cheapest, highest-yield checks come first.

## Contents

- [Before writing code](#before-writing-code)
- [Modeling](#modeling)
- [Nullability](#nullability)
- [Results and errors](#results-and-errors)
- [Naming](#naming)
- [Structure](#structure)
- [Comments](#comments)
- [Integration and security](#integration-and-security)
- [Tests](#tests)
- [Definition of done](#definition-of-done)
- [Review tone](#review-tone)

## Before writing code

- [ ] Read the repository's own conventions file first, then **grep the source** for an existing
      value object, result union, helper, or pattern that already solves this. Reuse over reinvent.
- [ ] Confirm the facts the design depends on against the code or the documentation. If a fact
      cannot be verified, ask — do not invent it and do not hedge with "probably".
- [ ] Check what the incoming request, message, or token **already carries** before proposing a new
      parameter or a new configuration value.
- [ ] Any new dependency passes the tooling policy: not on the banned list, the standard tool for
      its job, and not a second tool for a job the project already covers.
- [ ] Match the surrounding code's idiom, comment density, and naming. New code should be
      indistinguishable in style from the file it lives in.

## Modeling

- [ ] Is any invalid combination representable? Split the type.
- [ ] Is a mode derived by ternaries or a central switch? Move it onto the type.
- [ ] Does a domain concept travel as a raw `string`/`long`/`Guid`? Make it a value object.
- [ ] Is validation repeated after a parse? Delete the repeat; trust the type.
- [ ] Does any field lack a real consumer? Delete it.
- [ ] For a changed value: same value object, same property, same name — the smallest conceptual diff.

## Nullability

- [ ] Every `?` names its bucket: boundary raw input, real domain absence, or bug.
- [ ] No `?? string.Empty` (or equivalent) on a value the flow requires.
- [ ] No nullable collection; absent binds as empty.
- [ ] Every `!` is backed by a real invariant that a guard clause could not express.
- [ ] No nullable property that is in fact always set.

## Results and errors

- [ ] No `bool` + nullable payload anywhere.
- [ ] Failure cases carry a typed cause, not a string.
- [ ] The union's cases are closed (private constructor on the base).
- [ ] No `switch` with `_ => throw` over a vocabulary the code owns.
- [ ] The response body is a typed problem object; no extensions dictionary.
- [ ] The endpoint maps a failure it received; it does not fabricate another module's case.
- [ ] Full downstream detail (status, body, URL) is in the log and **not** on the wire.
- [ ] An expected business outcome is a result, not an exception.

## Naming

- [ ] Does every name say what the thing is or does, without opening the body?
- [ ] Implementation named after its interface minus the `I`.
- [ ] Injected variable named after the interface minus the `I`, camelCased.
- [ ] Result unions end in `Result`; response DTOs named after their endpoint.
- [ ] Peer types share a role suffix.
- [ ] Family prefix applied to every type, config section, and client name in the family.
- [ ] Methods are verbs; async I/O methods end in `Async` and take a `CancellationToken`.
- [ ] No abbreviations.

## Structure

- [ ] One type per file, named after the type.
- [ ] Namespace matches the folder.
- [ ] The feature owns its endpoint, DTOs, settings, model, and registration.
- [ ] Nothing was promoted to shared code before a second consumer existed.
- [ ] Every service with behavior is registered and consumed behind an interface.
- [ ] Options are validated at startup.
- [ ] Members are defined in reading order: public first, then privates in call order.
- [ ] No single-use one-line method extracted for its own sake; no local functions.
- [ ] No clever compound ternary where an early return reads better.

## Comments

- [ ] Every top-level type has a one- or two-line `/// <summary>`.
- [ ] Comments say what, not why; none longer than two lines.
- [ ] No document references, ticket numbers, dates, links, or non-English text.
- [ ] No concrete domain values named in the comments of an abstract type.
- [ ] No emoji.
- [ ] Endpoint documentation is in OpenAPI metadata, not in comments.

## Integration and security

- [ ] Typed client from the factory, exactly one resilience handler, bounded timeouts on
      user-facing paths.
- [ ] A non-success response is logged with status **and** body.
- [ ] Token algorithm pinned; issuer, audience, and expiry validated.
- [ ] Every absolute-URI parse paired with a scheme check.
- [ ] No secret logged, committed, or returned in a response.
- [ ] Cancellation token threaded through every call that accepts one.
- [ ] No blocking on async.

## Tests

- [ ] Every new transformation whose silent failure would cause real damage has a test.
- [ ] No test asserts a framework behavior or a mock's own configuration.
- [ ] Test class maps 1:1 to the class under test and names it in the first words of its summary.
- [ ] Fakes use the `Fake` prefix and self-evident names.
- [ ] No skipped, commented-out, or sleep-padded test.
- [ ] Suite is green.

## Definition of done

- [ ] Build clean: zero errors and zero warnings — warnings are errors, so a warning is fixed in
      the code, never suppressed with a pragma or a `NoWarn` entry.
- [ ] All tests pass. If any were skipped, that is stated explicitly, with the reason.
- [ ] No mock, stub, placeholder, `TODO`, or commented-out "real call" left in the code path.
      Temporary scaffolding is either finished or removed before the change is called complete.
- [ ] Configuration added for **every** environment the code will run in, not just the one used for
      development.
- [ ] Documentation touched in the same pass: search the docs for the terms that changed and fix
      stale statements. A change is not done while a document still describes the old behavior.
- [ ] The report of what was done is accurate: what works, what was verified and how, and what was
      left out and why. Never claim a verification that was not run.

## Review tone

State the defect, the concrete failure it causes, and the fix. Rank by severity. Do not pad a review
with style opinions the doctrine does not hold, and do not soften a real defect into a suggestion.
When a rule here conflicts with something in the library reference, cite
[precedence.md](precedence.md) rather than arguing it fresh each time.
