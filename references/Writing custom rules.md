# Writing project-specific (custom) rules

Built-in `aact` rules cover the common C4 / Solution Architecture surface
(ACL, CRUD per service, database ownership, common reuse, API gateway,
cohesion vs coupling, stable dependencies, acyclic dependencies). Every
project also carries **its own** conventions — bounded-context boundaries,
naming, BFF layout, plugin manifests, ownership tagging — that do not
belong in the upstream catalogue.

Since v3.0.0, `aact` supports custom rules directly in `aact.config.ts`,
running alongside the built-ins through the same `rules{}` block.

## When to write a custom rule

Reach for one when:

- The check is **project-specific** — naming conventions, internal
  compliance, BC discipline, ownership tagging — and would not make sense
  to ship with `aact` itself.
- A built-in covers the right *idea* but enforces it in a way that does
  not match your conventions, and configuring its options is not enough.
- You need a check that closes a real recurring review comment, not a
  hypothetical one.

Avoid one when:

- A built-in already covers it with different options — configure the
  built-in instead.
- The check is one-off and unlikely to recur — a PR template comment is
  cheaper than a rule.

## Anatomy

A rule is a single `RuleDefinition` object. `defineRule` is an identity
helper that preserves the literal `name` so `defineConfig` can wire it
into the typed `rules{}` shape for autocomplete.

```ts
import { defineRule, type Model } from "aact";

export interface MyOptions {
  readonly threshold?: number;
}

export const myRule = defineRule({
  name: "myRule",
  description: "Short, user-facing summary of the check",

  check(model: Model, options?: MyOptions) {
    const threshold = options?.threshold ?? 0;
    return Object.values(model.containers)
      .filter(/* condition */)
      .map((c) => ({
        container: c.name,
        message: "explanation of the violation",
      }));
  },
});
```

Required fields: `name`, `description`, `check`. Optional: `fix`.

### `check(model, options?): Violation[]`

Pure function. Receives the parsed `Model` and (optionally typed) options.
Returns an array of `Violation` objects, each with a `container` name and
a human-readable `message`.

`Model.containers` is a `Record<string, Container>` — iterate with
`Object.values(model.containers)`. `Container.kind` is the typed C4 kind
(`Person | System | Container | ContainerDb | ContainerQueue | Component
| ComponentDb | ComponentQueue`), `external: boolean` is orthogonal.

### `fix(model, violations, syntax, options?): FixResult[]`

Optional. When implemented, `aact check --fix` will offer
auto-correction. Receives the same `model` and the violations the rule
emitted in the current pass, plus a `SourceSyntax` adapter for the
current format (PlantUML / Structurizr).

See the upstream built-in `acl` rule (`src/rules/acl.ts`) for a worked
example: it injects a new ACL container and rewires the violating
relations through it.

Skip `fix()` when the resolution is a human decision the tool cannot
auto-resolve (choosing an owner, choosing a name, choosing where to put a
new boundary). Better no fix than a wrong fix.

## Registration

`aact.config.ts` registers the rules and configures their options:

```ts
import { defineConfig } from "aact";
import { myRule } from "./rules/myRule";

export default defineConfig({
  source: "./architecture.puml",

  customRules: [myRule], // auto-enabled at startup

  rules: {
    // Built-ins:
    acl: true,
    acyclic: true,

    // Custom rule options — TypeScript autocompletes the shape from the
    // rule's check() signature. Configure exactly like a built-in.
    myRule: { threshold: 3 },

    // To disable a custom rule (rare):
    // myRule: false,
  },
});
```

`defineConfig` is generic over its `customRules`. Typing
`rules: { myRule: { ←tab } }` suggests `threshold` from `MyOptions`. A
typo in the rule name (`myRulee: { ... }`) surfaces as a runtime warning
(`Unknown rule "myRulee"`) — not a parse error — so adding rules
incrementally never breaks an existing config.

### Conflict policy

A custom rule whose `name` matches a built-in or another custom rule is
rejected at startup with a clear error. Prefix rule names per project to
keep them globally unique:

- `acmeBcIsolation` (Acme corp, BC isolation)
- `mermaidLegendCheck` (Mermaid plugin, legend block check)
- `adapstoryBffBoundary` (Adapstory, BFF placement rule)

## Worked examples

The upstream repo ships a self-contained `examples/custom-rules/` folder
with two realistic rules, a sample PlantUML source, and tests:

- `bcIsolation` — Cross-bounded-context calls must route through a
  `*_api` container or a broker-tagged container (DDD bounded contexts at
  the C4 level).
- `requireOwnerTag` — Every operational container must carry an
  `owner:<team>` tag (compliance / on-call ownership).

See: `https://github.com/Byndyusoft/aact/tree/main/examples/custom-rules`

## Testing your rule

Custom rules are plain objects — test them like any other module:

```ts
import { describe, it, expect, beforeAll } from "vitest";
import { load } from "aact"; // or use a hand-built fixture
import type { Model } from "aact";

import { myRule } from "../src/rules/myRule";

describe("myRule", () => {
  let model: Model;

  beforeAll(async () => {
    const result = await load("./fixtures/architecture.puml");
    model = result.model;
  });

  it("flags X when Y", () => {
    const violations = myRule.check(model);
    expect(violations).toHaveLength(1);
    expect(violations[0].container).toBe("expected_name");
  });

  it("respects the threshold option", () => {
    const violations = myRule.check(model, { threshold: 100 });
    expect(violations).toHaveLength(0);
  });
});
```

## Listing the effective rule set

`npx aact@beta rule list` prints all enabled rules with source labels
(built-in / custom) and enabled state. Add `--json` for tooling
integration. Useful when:

- Onboarding a new contributor — "what does this project enforce?"
- Debugging a missing rule — "is my custom rule registered?"
- Producing a project-wide compliance report.

## When to upstream instead

If a custom rule starts to look like a candidate for the built-in
catalogue — generic enough to apply to other teams, anchored in a
recognised pattern, with a name that does not need a project prefix —
consider opening an upstream issue or PR. The `RuleDefinition` shape is
identical, so moving the file from your repo into `aact/src/rules/` is
mechanical.
