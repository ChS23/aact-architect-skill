# Целевая архитектура aact

Status: актуализировано для v3 beta на 2026-05-17. Этот документ больше не
описывает "будущее без CLI": CLI, Format API, custom rules и typed Model API уже
есть. Остальные пункты ниже фиксируют текущее состояние и ближайшую целевую
линию: source locations, JSON diagnostics и будущий `sync` режим.

## Контекст

aact — OSS CLI и библиотека для проверки архитектуры, описанной as code. В v3
архитектура загружается из PlantUML C4 или Structurizr в единую Model, после
чего над ней работают правила, анализатор, генераторы и auto-fix.

Основные пользовательские входы:

- `aact.config.ts` — источник архитектуры, правила, custom rules, generate
  options.
- PlantUML C4 (`.puml`) или Structurizr JSON/DSL-derived workspace.
- Project-specific custom rules через `customRules`.

Основные команды:

| Команда | Назначение |
| --- | --- |
| `npx --yes aact@beta init` | Создать `aact.config.ts` и starter `architecture.puml`. |
| `npx --yes aact@beta check` | Проверить правила, exit code 1 при нарушениях. |
| `npx --yes aact@beta check --fix` | Применить conservative auto-fixes, если формат поддерживает fix. |
| `npx --yes aact@beta analyze` | Посчитать architecture metrics: coupling, cohesion, API calls, DB usage. |
| `npx --yes aact@beta generate --format plantuml` | Сгенерировать PlantUML из Model. |
| `npx --yes aact@beta generate --format kubernetes` | Сгенерировать Kubernetes scaffold из Model. |
| `npx --yes aact@beta rule list` | Показать effective rule set: built-in + custom. |
| `npx --yes aact@beta skill` | Установить `aact-architect` skill для агентных workflow. |

## Принципы

1. **Model-first**: правила, анализ и генерация работают с единой Model, а не с
   синтаксисом конкретного формата.
2. **Format API**: каждый формат сам объявляет capabilities (`load`,
   `generate`, `fix`). Добавление формата не должно требовать branching по всему
   CLI.
3. **CLI тонкий**: команды загружают config/model, вызывают core API и
   форматируют результат.
4. **Custom rules first**: проектные политики добавляются через
   `customRules`, а не через fork пакета.
5. **Conservative fixes**: `--fix` применяет только локально понятные правки.
   Рискованные архитектурные решения должны оставаться diagnostics/hints.
6. **Agent-friendly output**: JSON diagnostics и source locations должны быть
   стабильным контрактом для AactLoop/coding-agent harness.
7. **Load/generate/sync are different modes**:
   - `load`: architecture source -> Model;
   - `generate`: Model -> artifacts;
   - future `sync`: Model + observed infra/code facts -> DriftReport/Patch.

## Текущее устройство репозитория

```text
aact/
├── src/
│   ├── model/                    # typed Model, buildModel, validateModel
│   ├── formats/                  # Format API implementations
│   │   ├── plantuml/             # load + generate + fix
│   │   ├── structurizr/          # load + fix via source.writePath
│   │   └── kubernetes/           # generate only
│   ├── rules/                    # built-in rules + fix implementations
│   ├── analyze.ts                # metrics over Model
│   ├── cli/                      # citty commands
│   │   ├── commands/
│   │   │   ├── init.ts
│   │   │   ├── check.ts
│   │   │   ├── analyze.ts
│   │   │   ├── generate.ts
│   │   │   ├── rule.ts
│   │   │   └── skill.ts
│   │   ├── loadConfig.ts
│   │   └── loadModel.ts
│   ├── config.ts                 # AactConfigSchema + defineConfig
│   └── index.ts                  # public library API
├── test/                         # unit + CLI tests
├── test/e2e/                     # built CLI subprocess tests
├── examples/                     # realistic usage examples
├── docs/                         # public docs
├── ADRs/                         # architecture decisions / pattern docs
├── patterns.md
└── package.json
```

## Core API

### Model

Model is the canonical architecture representation.

```ts
export interface Model {
  readonly elements: Readonly<Record<string, Element>>;
  readonly boundaries: Readonly<Record<string, Boundary>>;
  readonly rootBoundaryNames: readonly string[];
  readonly workspace?: WorkspaceMetadata;
}
```

Rules should depend on Model-level fields (`name`, `label`, `kind`,
`external`, `tags`, `relations`, `properties`) instead of loader-specific
syntax. Source-specific data belongs in `sourceLocation` / future source
metadata, not in rule logic.

### Format API

Current contract:

```ts
export interface Format {
  readonly name: string;
  readonly defaultPattern?: string;
  load?(path: string): Promise<LoadResult>;
  generate?(model: Model): FormatOutput;
  fix?: FixCapability;
}
```

Capabilities:

| Format | load | generate | fix |
| --- | --- | --- | --- |
| `plantuml` | yes | yes | yes |
| `structurizr` | yes | no | yes, writes to `source.writePath` |
| `kubernetes` | no | yes | no |

Important boundary: Kubernetes is currently a **generate target**, not an
architecture source. Loading observed infra for drift detection should be a
future `sync` capability/layer, not a normal Model loader.

## Config and custom rules

`aact.config.ts` is the main user-facing contract.

```ts
import { defineConfig } from "aact";
import { bcIsolationRule } from "./rules/bcIsolation";

export default defineConfig({
  source: {
    type: "plantuml",
    path: "./architecture.puml",
  },

  customRules: [bcIsolationRule],

  rules: {
    acl: true,
    crud: { repoTags: ["repo", "relay"] },
    bcIsolation: { bcTagPrefix: "bc:", apiSuffix: "_api" },
  },
});
```

Custom rule policy:

- `customRules` are auto-enabled.
- Disable via `rules: { myRule: false }`.
- Options use the same `rules{}` shape as built-ins.
- Name conflicts with built-ins or another custom rule are rejected.
- Prefer custom rules for project-specific architecture policies instead of
  forking `aact`.

## CLI output direction

Current beta uses one stable JSON envelope for all `--json` commands:

```bash
aact check [--json] [--fix] [--dry-run]
aact analyze [--json]
aact generate --format <plantuml|kubernetes> [--output <path>] [--json]
aact rule list [--json]
aact skill install [--json]
```

Machine-readable envelope:

```ts
interface CliEnvelope<TData> {
  schemaVersion: 1;
  command: string;
  ok: boolean;
  exitCode: 0 | 1 | 2;
  data: TData;
  diagnostics: Diagnostic[];
  meta: {
    aactVersion: string;
    durationMs: number;
    configPath: string | null;
    source: string | null;
  };
}
```

Rule diagnostics include:

- stable diagnostic kind;
- severity;
- message;
- source location;
- affected element/relation;
- fixability;
- optional related locations.

`--fix` remains the switch that applies safe edits. Hints without `--fix` should
be diagnostics, not a separate `suggest` command.

## Future sync mode

`sync` should compare intended architecture with observed implementation or
infra state.

```text
load      -> architecture source -> Model
generate  -> Model -> artifacts
sync      -> runtime/infra source + Model -> DriftReport / Patch
```

Example future command:

```bash
npx --yes aact@beta sync \
  --source ./architecture.puml \
  --infra ./deploy/kubernetes \
  --json
```

Why `sync` is separate from `load`:

- Old Docker Compose can be an architecture source for migration.
- Current Kubernetes can be observed runtime/deployment reality.
- Comparing the two is a drift/conformance task, not just parsing another
  architecture source.

Potential drift diagnostics:

- workload exists in Kubernetes but is missing from AaC;
- Container exists in AaC but has no observed workload;
- DB/resource exists in IaC with no modeled `ContainerDb`;
- env var or service reference implies a missing relation;
- Kafka topic implies missing async relation;
- external endpoint implies missing ACL/external system relation.

Safe `sync --fix` candidates:

- add missing container/resource;
- add missing relation when evidence is unambiguous;
- add role tag (`repo`, `relay`, `acl`) when name and relation shape agree.

Unsafe changes should stay as diagnostics/hints for human or agent review.

## Parser direction

Current limitations come mostly from third-party PlantUML parsing and lack of
source locations. Target v3.x parser direction:

- full Structurizr DSL parser/preserver for sync and source-preserving edits;
- partial C4-PlantUML parser for C4 semantics;
- non-C4 PlantUML syntax (`skinparam`, `note`, legends) handled as opaque or
  silently skipped when it does not affect the Model;
- parser recovery should return partial Model + issues instead of failing the
  whole command when possible.
