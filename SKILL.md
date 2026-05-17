---
name: aact-architect
description: Design, review, measure, and generate microservice architectures using the aact pattern catalog and CLI. Use this skill when the user is sketching a C4 system in PlantUML or Structurizr, writing or reviewing an ADR, choosing how to tag containers (acl, repo, relay), writing project-specific compliance checks (custom rules in aact.config.ts), explaining why an aact rule fired, asking about microservice patterns (ACL, CRUD-services, Database-per-service, API Gateway, Cohesion vs Coupling, Stable Dependencies, Common Reuse, Acyclic Dependencies, Bounded Context isolation), looking at coupling/cohesion metrics for their services, or asking aact to emit PlantUML or Kubernetes manifests from their architecture — even when the user does not explicitly mention "aact" or "C4". Bundles the canonical ADRs, an ADR template, starter architecture files, a custom-rules authoring guide, and wrappers around `aact check / analyze / generate / rule list`.
license: GPL-3.0 (skill code and bundled ADRs derive from Byndyusoft/aact, GPL-3.0)
compatibility: Requires Node.js >= 22. The skill uses `aact@beta` via `npx` so it tracks the current v3 beta dist-tag instead of pinning a concrete beta version. v3 brings typed Model API, `customRules` extension, `defineConfig` generics with autocomplete for custom rule options, and the `aact rule list` command — all backward-compatible at the PlantUML / Structurizr source level.
metadata:
  author: Sergei Volchkov (https://github.com/ChS23)
  upstream: https://github.com/Byndyusoft/aact
  upstream_author: Ruslan Safin (https://github.com/razonrus)
---

# aact-architect

A working companion for designing, documenting, and validating microservice architectures using the patterns catalogued in [Byndyusoft/aact](https://github.com/Byndyusoft/aact) by [Ruslan Safin (@razonrus)](https://github.com/razonrus).

The skill keeps **all reasoning about patterns and ADRs in markdown** (loaded on demand) and **delegates verification to the deterministic `aact` CLI** (no LLM in the validation loop, no API keys baked in). The agent's job is to translate human intent into C4 + ADRs; aact's job is to check the result.

## When this skill applies

- The user describes a system in microservice terms (services, databases, async/sync calls, external integrations) and wants a C4 sketch.
- The user is writing or reviewing an ADR for an architecture decision.
- The user has a `.puml` or `workspace.json`/`workspace.dsl` and asks "is this OK?", "what's wrong here?", or "fix this".
- The user asks what a specific aact rule means or why it fired.
- The user is choosing tags or names for new containers.
- The user asks about **coupling / cohesion / element counts** for their architecture, or wants to compare two versions quantitatively (this is `aact analyze`, workflow E).
- The user wants **PlantUML emitted from a Structurizr workspace** (or vice versa), or **Kubernetes deployment YAMLs generated from the architectural model** as a starting point (this is `aact generate`, workflow F).

## Workflows

### A. Designing a new system from a description

1. **Default to PlantUML** as the source format — lower entry barrier, single-file. Switch to **Structurizr DSL/JSON** only if the user already has a `workspace.json`/`workspace.dsl` in the project, or explicitly asks for it (e.g. they need multiple views or are using a Structurizr toolchain).
2. Copy the matching stub into the user's working directory:
   - `assets/architecture-stub.puml` for PlantUML, save as `architecture.puml`.
   - `assets/workspace-stub.dsl` for Structurizr, save as `workspace.dsl`.
3. **Before adding elements, get the C4 discipline right.** Read `references/C4 model.md` — it has the canonical definitions, a decision procedure for "is this a Container?", and the failure modes that produce plausible-but-wrong models (layers-as-containers, over-decomposition, one shared DB box, external systems modelled as internal). The worked examples in `assets/example-1-system-context.puml` / `example-2-container.puml` / `example-3-component.puml` show correct granularity at each level.
4. Walk the user through their system, adding containers one by one — follow the minimum-viable-C4 procedure in `references/C4 model.md`. Apply the tagging conventions in the [Tagging cheat sheet](#tagging-cheat-sheet) below.
5. Once the diagram has shape, run `scripts/verify.sh` (or `npx aact@beta check` directly) from the working directory. If `aact.config.ts` is missing, run `npx aact@beta init` first.
6. Walk through any violations using [Interpreting violations](#interpreting-violations).

### B. Writing an ADR

1. Use this minimal skeleton as the starting point. Load `references/adr-template.md` only if you need expanded guidance for any section.

   ```markdown
   # <Decision name — name the decision, not the technology>

   ## Status
   <Proposed | Accepted | Superseded by ADR-N | Deprecated>

   ## Context
   <What problem is this solving? What constraints / forces shape it?>

   ## Decision
   <What is chosen, and which alternatives were considered?>

   ## Consequences
   <Trade-offs the team accepts. Costs, risks, follow-up work.>
   ```

2. Ask the user the three questions if they are not already answered in the conversation:
   - **What problem is this decision solving?** → Context
   - **What are the candidate options, and which is chosen?** → Decision
   - **What does the team accept as cost of this choice?** → Consequences

3. Draft the ADR into the project's `ADRs/` directory (or wherever ADRs live). Name the file after the decision, not the technology — `Anti-corruption Layer.md`, not `Add Kafka.md`.

4. If the ADR introduces a verifiable rule, add a follow-up note: which aact rule (existing or new) enforces it, or whether enforcement is manual for now.

5. **Validate** the draft before considering it done:
   - All four sections present (`## Status`, `## Context`, `## Decision`, `## Consequences`).
   - `Status` has one of the allowed values, not a placeholder.
   - `Context` describes the problem, not the solution.
   - `Decision` names what is chosen explicitly (not "we should consider X").
   - `Consequences` lists at least one trade-off, not just upsides.

   If any check fails, revise and re-validate. Only then propose the ADR to the user.

### C. Reviewing an existing architecture

1. Run `scripts/verify.sh` from the project root. The script forwards to `npx aact@beta check`.
2. For each rule that fired, open the matching reference (see table below) and explain to the user **why** the pattern matters, not just **what** the rule said.
3. If the user wants the auto-fix, run `npx aact@beta check --fix`. Show the diff. Do not blindly apply — confirm with the user that the fix matches their intent.

### D. Explaining a specific rule

User asks "what does crud mean" or "why did acl fire". Open the matching ADR/reference, summarise the *purpose* in one sentence, then quote the specific clause that the violation breaks.

### E. Measuring coupling and cohesion

When the user asks "what's our coupling?", "is this boundary cohesive enough?", or wants numbers to bring to a review:

1. Run `npx aact@beta analyze` from the project root. For machine-readable output (e.g. to diff between two versions), use `--format json`.
2. The report includes:
   - `elementsCount` — total containers in the model.
   - `syncApiCalls`, `asyncApiCalls` — count of REST vs async edges.
   - `databases.count` / `databases.consumes` — DB inventory + how many services touch them.
   - `boundaries[]` — per boundary, its `cohesion` (intra-boundary relations) and `coupling` (cross-boundary outgoing relations), plus `couplingRelations[]` listing which specific edges leak across the boundary.
3. Translate numbers into stakeholder language: rising coupling between two boundaries usually signals a missing seam (an ACL or API Gateway); cohesion below coupling on a boundary signals that the boundary is wrongly drawn — its contents probably belong to two different domains.
4. Anchor every finding in the `Cohesion > Coupling` pattern (`references/patterns-catalog.md`) so the user understands *why* a number matters, not just *that* it's bigger than another.

### F. Generating artifacts from the model

`aact generate` turns the architecture model into downstream artifacts. Default `--format` is `plantuml`. Two formats today:

**Plantuml** — emit a `.puml` from any source (Structurizr → PlantUML is a common need: the team works in Structurizr, but the wiki / handout expects PlantUML). Without `--output` the result is printed to stdout.
```bash
npx aact@beta generate --format plantuml --output ./diagrams/architecture.puml
```
The boundary heading label in the output is configurable via `generate.boundaryLabel` in `aact.config.ts`.

**Kubernetes** — emit one YAML stub per deployable container with environment-variable scaffolding for DB connections, REST `*_BASE_URL`, and Kafka topics (`KAFKA_<TARGET>_TOPIC` for `async`-tagged relations). Output is a directory of `.yml` files.
```bash
npx aact@beta generate --format kubernetes --output ./k8s
```
Default output directory if `--output` is omitted: `resources/kubernetes/microservices` (configurable via `generate.kubernetes.path` in `aact.config.ts`).

Things to tell the user before they run it:
- Only `Container`-typed elements become deployment YAMLs. `System`, `Component`, `Person`, `ContainerDb`, and external systems are deliberately skipped — these are not deployable units.
- The output is a **scaffold**, not production manifests. Image tags, resource requests, replicas, and secrets are not generated — the team fills them in.
- The DB connection template defaults to PostgreSQL (`postgresql://{name}:pass-{name}@postgresql:5432/{name}`) and the service port to 8080. Both are CLI-fixed today — overriding them requires using the `generateKubernetes(model, options)` library API directly, not `aact.config.ts`.

### G. Writing project-specific (custom) rules

When the built-in catalogue does not match a project's conventions — bounded-context isolation by tag prefix, mandatory ownership tags, internal compliance — write the rule alongside `aact.config.ts` instead of forking the package. Custom rules use the **same** `RuleDefinition` contract as built-ins and slot into the same `rules{}` block.

1. **Decide if a built-in covers it first.** A custom rule should close a recurring review comment, not a hypothetical one. If a built-in does what you need with a different default — configure the built-in's options instead.
2. **Write the rule in `./rules/<name>.ts`.** One file per rule. Use `defineRule` so TypeScript preserves the literal `name` for downstream typing:

   ```ts
   import { defineRule, type Model } from "aact";

   export interface BcIsolationOptions {
     readonly bcTagPrefix?: string;
     readonly apiSuffix?: string;
   }

   export const bcIsolationRule = defineRule({
     name: "bcIsolation",
     description: "Cross-bounded-context calls must route through *_api or a broker",

     check(model: Model, options?: BcIsolationOptions) {
       const bcPrefix = options?.bcTagPrefix ?? "bc:";
       const apiSuffix = options?.apiSuffix ?? "_api";
       // ... return Violation[]
       return [];
     },
   });
   ```

3. **Register + configure in `aact.config.ts`.** Switch from the `import type { AactConfig }` template to `defineConfig` so TypeScript autocompletes options for custom rules in `rules{}`:

   ```ts
   import { defineConfig } from "aact";
   import { bcIsolationRule } from "./rules/bcIsolation";

   export default defineConfig({
     source: "./architecture.puml",

     customRules: [bcIsolationRule], // auto-enabled

     rules: {
       acl: true,
       bcIsolation: { bcTagPrefix: "bc:", apiSuffix: "_api" }, // autocompleted
     },
   });
   ```

4. **Conflict policy.** A custom rule whose `name` matches a built-in or another custom rule is rejected at startup. Prefix names per project (`acmeBcIsolation`, `mermaidLegend`).
5. **Optional `fix()`.** `check` is required; `fix` is optional. When provided, `aact check --fix` will offer auto-correction. See the built-in `acl` (`src/rules/acl.ts` in the upstream repo) for a worked example — it injects a new ACL container and rewires violating relations through it.
6. **List the effective set** any time with `npx aact@beta rule list` — built-in + custom together with enabled state. Use `--json` for tooling.

Read `references/Writing custom rules.md` for the full pattern guide (when to write, anatomy, registration, options inference, fix capability, testing).

## Rule → reference map

| Rule | What it checks | Reference |
|------|---------------|-----------|
| `acl` | Only `acl`-tagged containers depend on external systems | `references/Anti-corruption Layer.md` |
| `crud` | Only `repo`/`relay`-tagged containers access databases | `references/Database per CRUD-service.md` |
| `dbPerService` | Each database is owned by exactly one service | `references/Database per CRUD-service.md` |
| `commonReuse` | A context's consumers depend on its full public API or none | `references/Common Reuse Principle.md` |
| `apiGateway` | External REST traffic goes through a gateway | `references/patterns-catalog.md` (see "API-Gateway" row) |
| `acyclic` | Dependency graph has no cycles | `references/patterns-catalog.md` (see "Acyclic Dependencies") |
| `cohesion` | Boundary's intra-cohesion exceeds its outward coupling | `references/patterns-catalog.md` (see "Cohesion > Coupling") |
| `stableDependencies` | Dependencies point toward more stable components | `references/patterns-catalog.md` (see "Stable Dependencies") |
| _(project-specific)_ | Custom rules registered via `customRules` in `aact.config.ts` | `references/Writing custom rules.md` |

## Tagging cheat sheet

These tags are how aact knows what each container is. Get them right and the rules are quiet.

- **`acl`** — service that wraps an external integration. Without this tag, anything connecting to a `System_Ext` will trip the `acl` rule.
- **`repo`** or **`relay`** — service whose only job is to own a database. Without this tag, anything connecting to a `ContainerDb` will trip the `crud` rule. Repos must not have non-DB dependencies.
- **`async`** (on a relation, not a container) — marks an asynchronous edge (Kafka, queue). The Kubernetes generator emits `KAFKA_*_TOPIC` env vars for these instead of `*_BASE_URL`.

If the user is using non-default tags (e.g. they call repos `relay` only, not `repo`), set `crud: { repoTags: ["relay"] }` in `aact.config.ts`.

## Interpreting violations

When `aact check` reports a violation:

1. Read the message — it names the offending container and the rule.
2. Open the rule's reference (table above). Summarise the principle the rule encodes.
3. Explain *to the user* why this principle matters in their domain, before suggesting a fix.
4. Suggest one of three resolutions:
   - **Add a missing tag** if the container actually plays the role (e.g. it really is an ACL, just not tagged).
   - **Insert an intermediary** (e.g. a `_repo` between a service and its DB). `aact check --fix` does this automatically for the `crud` rule.
   - **Question the rule** if the architecture is intentionally violating it. The user may decide to disable the rule in `aact.config.ts` (e.g. `acl: false`). Make sure the user understands the trade-off — link the ADR.

## Gotchas

C4 modeling — the three mistakes that produce plausible-but-wrong models (full list + decision procedure in `references/C4 model.md`):

- **Layers are not Containers.** `controller` / `service` / `repository` run in one process — they are Components, not Containers. A Container is "a runtime boundary around code being executed or data being stored" — something separately runnable, or a data store.
- **One shared "Database" box hides the coupling.** Each data store is its own Container (`ContainerDb`), owned by one service. Modelling a single DB everything points at defeats `dbPerService` and the whole point of the diagram.
- **External systems are not your Containers.** Stripe, Auth0, a partner API — model them as external Software Systems (`System_Ext` / `external: true`), never as Containers inside your boundary.

aact / tooling specifics:

- `Stdlib_C4_Context` element type in PlantUML is `System` — those become `SYSTEM_TYPE` containers in the model. The Kubernetes generator whitelists `Container` only, so `System`, `Component`, `Person` and external systems are deliberately skipped — do not expect them in the YAML output.
- `enrichTags` in the Structurizr loader is a naming heuristic: a container whose name contains "crud" gets a phantom `repo` tag automatically. If the user names a service `crud_processor` for unrelated reasons, override the inferred tag explicitly in their workspace.
- Cohesion calculation includes inner-boundary coupling as parent cohesion. This is intentional but non-obvious — if the user sees an unexpected `parent cohesion ≥ sum of inner cohesions` violation, walk through the structure with them.
- The `--fix` writer applies edits as line-by-line substring replacement, not AST-level. Multi-line block edits (e.g. removing a Structurizr container with nested tags) are not supported and need manual cleanup.

## Verifying

Run `scripts/verify.sh` from the project root. It is a thin wrapper around `npx aact@beta check` that:
- Uses the project's `aact.config.ts` if present.
- Falls back to creating one via `npx aact@beta init` (with confirmation) if missing.
- Relays exit code so it can be used in CI.

```bash
bash scripts/verify.sh           # plain check
bash scripts/verify.sh --fix     # apply auto-fixes after preview
bash scripts/verify.sh --dry-run # preview fixes without writing
```

## Other aact commands at a glance

| Command | Purpose | Common flags |
|---------|---------|--------------|
| `aact init` | Scaffold `aact.config.ts` + starter `architecture.puml`. | (no flags) |
| `aact check` | Run all enabled rules against the source. | `--fix`, `--dry-run`, `--format text\|json\|github`, `--config <path>` |
| `aact analyze` | Print coupling/cohesion metrics (workflow E). | `--format text\|json`, `--config <path>` |
| `aact generate` | Emit PlantUML or Kubernetes from the model (workflow F). | `--format plantuml\|kubernetes`, `--output <path>`, `--config <path>` |
| `aact rule list` | List the effective rule set (built-in + custom, enabled state). | `--json` |

`--format github` for `check` produces GitHub Actions annotations — useful when wiring aact into CI as a status check.

## Maintaining the skill

- **`scripts/sync-from-aact.sh`** — pulls the latest ADRs and patterns catalog from `Byndyusoft/aact` into `references/`. Run after upstream releases that add or change ADRs. Pass a tag (`bash scripts/sync-from-aact.sh v2.1.5`) to pin to a specific release.
- **`evals/evals.json`** — 20 trigger-rate test queries (10 should-trigger / 10 should-not-trigger) for optimizing the `description` field. Run with the `skill-creator` skill from `anthropics/skills`, or any harness that follows the [optimizing-descriptions](https://agentskills.io/skill-creation/optimizing-descriptions) recipe.
