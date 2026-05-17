# aact-architect — Claude Code skill

A companion [Agent Skill](https://agentskills.io) for designing, documenting, and validating microservice architectures using the patterns from [Byndyusoft/aact](https://github.com/Byndyusoft/aact).

The `aact` CLI and its pattern catalog are authored and maintained by **[Ruslan Safin (@razonrus)](https://github.com/razonrus)** at Byndyusoft. This skill packages those patterns and the bundled ADRs for use inside agent harnesses (Claude Code, Codex, Cursor, etc.). It is a derivative work under GPL-3.0.

The skill keeps **all reasoning about patterns and ADRs in markdown** (loaded on demand) and **delegates verification to the deterministic `aact` CLI** (no LLM in the validation loop, no API keys baked in). The agent's job is to translate human intent into C4 + ADRs; aact's job is to check the result.

## What it bundles

- The canonical [aact ADRs](https://github.com/Byndyusoft/aact/tree/main/ADRs) (Anti-corruption Layer, Database per CRUD-service, Common Reuse Principle, Target Architecture) and the [patterns catalog](https://github.com/Byndyusoft/aact/blob/main/patterns.md) in `references/`.
- `references/C4 model.md` — C4 modeling discipline: canonical definitions ([c4model.com](https://c4model.com)), a "what is a Container?" decision procedure, the failure modes that produce plausible-but-wrong models, and a minimum-viable-C4 procedure.
- `references/Writing custom rules.md` — how to author project-specific rules.
- An ADR template ready to fill.
- Starter `architecture.puml` (C4-PlantUML) and `workspace.dsl` (Structurizr) stubs, plus the canonical Internet Banking System example at all three C4 levels (`example-1-system-context.puml` / `example-2-container.puml` / `example-3-component.puml`), in `assets/`.
- `scripts/verify.sh` — thin wrapper around `npx aact@beta check` with friendly errors.
- `scripts/sync-from-aact.sh` — pulls fresh ADRs/patterns from upstream.
- `evals/evals.json` — 20 trigger-rate queries (10 should-trigger / 10 should-not-trigger) for `description` optimization.

## Compatibility

Agent Skills format. Tested-as-loaded in Claude Code. Per [agentskills.io clients](https://agentskills.io/clients), the same format works in OpenAI Codex CLI, Cursor, GitHub Copilot, VS Code, Goose, OpenCode, Junie, and ~30 other agents.

Runtime: requires Node.js ≥ 22 (for `npx aact@beta`).

## Install

Pick one path depending on which agent you use most:

```bash
# Cross-agent (recommended) — discovered by Codex, Cursor, Goose, etc.
git clone https://github.com/ChS23/aact-architect-skill.git ~/.agents/skills/aact-architect

# Claude-Code-specific (if you only use Claude Code)
git clone https://github.com/ChS23/aact-architect-skill.git ~/.claude/skills/aact-architect
```

If you want both — clone into `~/.agents/skills/` and symlink: `ln -s ~/.agents/skills/aact-architect ~/.claude/skills/aact-architect`.

## Quick test

After install, in any project:

```bash
cd /tmp/some-fresh-dir
# Start a session with your agent and ask:
#   "Help me sketch a C4 container diagram for an e-commerce checkout
#   with orders, payments, and an external Stripe integration."
# Or:
#   "I have an architecture.puml — can you review it?"
```

The skill should activate. It'll copy a stub from `assets/`, walk you through the system, and run `scripts/verify.sh` (which forwards to `npx aact@beta check`).

## Validate the skill

Validator from [agentskills/agentskills](https://github.com/agentskills/agentskills):

```bash
git clone --depth 1 https://github.com/agentskills/agentskills.git /tmp/aref
cd /tmp/aref/skills-ref && uv sync && .venv/bin/skills-ref validate ~/.agents/skills/aact-architect
```

## Keeping in sync with upstream

When `aact` adds new ADRs or changes the patterns catalog:

```bash
cd ~/.agents/skills/aact-architect
bash scripts/sync-from-aact.sh             # pull from main
bash scripts/sync-from-aact.sh v2.2.0      # or pin a tag
```

## Credits

- **[Byndyusoft/aact](https://github.com/Byndyusoft/aact)** — the CLI, the rule engine, and the pattern catalog. Authored by [Ruslan Safin (@razonrus)](https://github.com/razonrus), with contributions from the Byndyusoft team and external contributors. The ADRs and `patterns.md` bundled into `references/` are theirs verbatim.
- This skill (the `SKILL.md` workflows, the assets, the scripts, the eval set) was assembled by [Sergei Volchkov (@ChS23)](https://github.com/ChS23) as a companion to aact for agent-driven architectural work.

## License

GPL-3.0. Bundled ADRs and patterns catalog derive from [Byndyusoft/aact](https://github.com/Byndyusoft/aact), which is GPL-3.0; the skill follows the same licence.
