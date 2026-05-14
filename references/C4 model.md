# C4 model — modeling discipline

This is not a C4 tutorial. It is a discipline guide: the canonical
definitions, the decisions that go wrong most often, and a procedure for
turning a plain-language description into a correct C4 model that `aact`
can validate.

Definitions below are quoted from [c4model.com](https://c4model.com).

## The four abstractions

> A software system is made up of one or more containers (applications
> and data stores), each of which contains one or more components, which
> in turn are implemented by one or more code elements.

People use software systems. The nesting is strict:

```
Person → uses → Software System → contains → Container → contains → Component → implemented by → Code
```

| Abstraction | Canonical definition | aact models it? |
| --- | --- | --- |
| **Software System** | "the highest level of abstraction … describes something that delivers value to its users, whether they are human or not" | Yes — as a `System` element or a `System_Boundary` |
| **Container** | "an application or a data store" — "a runtime boundary around some code that is being executed or some data that is being stored" | Yes — the primary element `aact` works with |
| **Component** | "a grouping of related functionality encapsulated behind a well-defined interface" — not separately deployable; all components in a container share one process space | Yes — `Component` kind, `Component_Boundary` |
| **Code** | classes, interfaces, functions — the language's building blocks | No — out of scope, do not model this |

## The decision that goes wrong most: what is a Container?

A Container is **a runtime boundary** — something that runs, or something
that stores data. The test:

> Can it be started/deployed independently, OR is it a data store?
> → Container. Otherwise → Component or Code.

**Counts as a Container:**

- Server-side apps (Node.js, ASP.NET, Rails, Java EE)
- Client-side apps (browser SPA, mobile app, desktop app)
- Serverless functions, console/batch apps, shell scripts
- Data stores: relational DBs, document/graph stores, blob stores, file
  systems, message brokers/queues

**Does NOT count as a Container** — quoting c4model.com: "Java JAR files,
C# assemblies, DLLs, and modules are typically not" containers. They are
code-organisation tools, not runtime constructs. Neither is:

- A class, a function, a namespace, a package, a folder
- A layer (controller / service / repository) — those are **Components**
- A "bounded context", "business capability", or "team" — those are not
  C4 elements at all

And, explicitly: a Container is **"Not Docker!"** The name predates
containerisation; it says nothing about how the thing is deployed.

## Element-mapping questions that come up often

- **Message queues and topics** (Kafka topic, RabbitMQ queue) — these
  *are* Containers. c4model.com: "the queues and topics are C4
  containers, rather than the message bus itself." In aact, use
  `ContainerQueue`. Do not model the broker/bus as one box that
  everything points at.
- **A microservice** — is not a single box. Canonically it is "a group
  of one or more containers" — typically an API container plus its own
  data-store container. When a *separate team* owns the service, it is
  promoted to its own Software System instead. Ownership decides.
- **A serverless function** — a Container (it runs).
- **An external SaaS / partner API** — an external Software System
  (`kind: "System", external: true`), never one of your Containers.

## The four diagram levels

| Level | Shows | Audience |
| --- | --- | --- |
| **System Context** | one software system + its users + the external systems it talks to | everyone, technical and non-technical |
| **Container** | the runnable units and data stores inside one system, and how they talk | architects, developers, ops |
| **Component** | the components inside **one** container | developers of that container |
| **Code** | classes/functions — usually skip, generate if ever | rarely needed |

`aact` lives mostly at the **Container** level. Don't mix levels in one
model — a Container diagram shows Containers, not Components.

## Failure modes (what agents get wrong)

Each of these produces a model that looks plausible but is wrong:

1. **Layer-as-Container.** `controller`, `service`, `repository` modelled
   as separate Containers. They run in one process → they are Components.
2. **Class/module-as-Container.** A box per class or per file. Wrong
   level entirely — that is Code.
3. **Mixing levels.** Containers and Components in the same diagram.
   Pick one level per model.
4. **Over-decomposition.** 80 boxes. A real system has a handful to ~20
   containers. If you have more, you are modelling Components or Code.
5. **Under-decomposition.** The whole app as one box. If it has a
   database, a frontend, and a backend, that is at least 3 containers.
6. **External system as internal Container.** Stripe, Auth0, a partner
   API — these are external software systems, not your containers. Mark
   them external.
7. **One shared "Database" box.** Each data store is its own Container,
   owned by one service. A single box every service points at hides the
   real coupling.
8. **Meaningless relations.** Every relation must say *what* flows and
   *how* — `Rel(web, api, "fetches orders", "JSON/HTTPS")`, not
   `Rel(web, api)`.

## How it maps to the aact model

- **`kind`**: `Person | System | Container | ContainerDb | ContainerQueue
  | Component | ComponentDb | ComponentQueue`. Use the precise kind —
  a database is `ContainerDb`, not `Container`.
- **`external: boolean`**: orthogonal to `kind`. An external software
  system is `kind: "System", external: true`. This is how failure mode 6
  is expressed.
- **Boundaries**: `System_Boundary` wraps the containers of one software
  system. `Container_Boundary` / `Component_Boundary` go one level
  deeper. Boundaries are where the `cohesion` rule and bounded-context
  custom rules apply.
- **`tags`**: drive the rules — `acl`, `repo`/`relay`. See the Tagging
  cheat sheet in `SKILL.md`.

## Minimum-viable-C4 procedure

When building a model from a plain-language description, follow this
order — do not skip ahead:

1. **Name the system.** One software system being built → one
   `System_Boundary`.
2. **Identify users and external systems.** People who use it
   (`Person`), and the systems it depends on (`System`, `external: true`).
3. **List the runnable units and data stores.** Each becomes a
   `Container` / `ContainerDb` / `ContainerQueue`. Apply the
   "can it run independently, or is it a store?" test.
4. **Draw the relations.** Who calls whom, and with what — every
   relation carries a description and a technology.
5. **Group into boundaries** only if there is more than one bounded
   context worth showing.
6. **Stop.** Do not descend to Component level unless the user explicitly
   asks for the internals of one container.

## Modular monolith vs microservices

Both use the **same** Container-level discipline — the difference is only
in how the boundaries are drawn:

- **Modular monolith**: the modules are Containers inside **one**
  `System_Boundary` (or, more precisely, Components inside one Container).
  One deployable, internal boundaries enforced.
- **Microservices**: each service is a container *group* — an API
  Container plus its own data-store Container. Group them with a
  `System_Boundary` per service, or — when a separate team owns the
  service — promote it to its own Software System. Many deployables.

The boundary discipline — a module/service must not reach into another's
internals, only its public surface — is identical in both. That rule is
exactly what `aact`'s `acyclic`, `cohesion`, and custom bounded-context
rules check. The shape of the deployment changes; the modeling discipline
does not.

## Worked examples

`assets/` carries the canonical c4model.com running example (Internet
Banking System) expressed in C4-PlantUML, one file per level — read these
to see correct granularity before building a model:

- `assets/example-1-system-context.puml` — the system, its users, its
  external dependencies
- `assets/example-2-container.puml` — the same system zoomed in: ~5
  containers, technologies, relations
- `assets/example-3-component.puml` — one container (API Application)
  zoomed in to components

All three load cleanly through `aact` — they double as fixtures.
